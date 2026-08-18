import CryptoKit
import DeviceCheck
import Foundation

/// Actor that orchestrates the App Attest warm-up flow and exposes the result
/// via a non-blocking `snapshot()` poll.
///
/// **Lifecycle:**
/// 1. `create(logger:)` constructs the provider when `#available(iOS 14.0, *)`.
/// 2. The owner calls `start()` once. `start()` spawns a background `Task`
///    and returns immediately (fire-and-forget).
/// 3. The warm-up task:
///    a. Pre-flight: `service.isSupported == false` → `.unavailable("unsupported")`.
///    b. Key retrieval: read cached key ID from Keychain; if absent, generate
///       a new one via `service.generateKey()` and persist it.
///    c. Assertion: call `service.generateAssertion(keyID:clientDataHash:)`.
///    d. On success: `state = .ready(token:, type: "app_attest")`.
/// 4. `snapshot()` returns `state` — a single actor-isolated read, never blocking.
/// 5. `shutdown()` cancels the warm-up Task.
///
/// **Quota heuristic (§4.5 of design):**
/// `DCError.serverUnavailable` increments a session-level counter stored on the
/// actor. When the counter reaches `serverUnavailableQuotaThreshold` (default 3)
/// the state transitions to `.error("quota")` and a diagnostic event is logged.
/// A single `serverUnavailable` below the threshold maps to `.error("timeout")`.
@available(iOS 14.0, *)
actor AppAttestProvider: AttestationProviding {
    // MARK: - Stored properties

    private let service: any AppAttestServicing
    private let keychain: any KeychainStoring
    private let clock: @Sendable () -> Date
    private let logger: TruoraLogger
    private let serverUnavailableQuotaThreshold: Int

    private var state: AttestationSnapshot = .pending
    private var warmUpTask: Task<Void, Never>?
    /// Monotonic generation counter incremented on every `start()`. Each warm-up
    /// run carries its own generation; the `defer`-based handle cleanup only
    /// clears `warmUpTask` when the generations still match. Prevents a stale
    /// task from niling a newer `start()`'s handle after a `shutdown()`-then-`start()`
    /// sequence reordering at an `await` suspension point.
    private var warmUpGeneration: UInt64 = 0
    /// Session-level count of consecutive `DCError.serverUnavailable` responses.
    /// Persists across `start()` calls within the same provider instance.
    private var consecutiveServerUnavailableCount: Int = 0

    // MARK: - Key name used in Keychain

    private static let keychainKeyName = "app_attest_key_id"

    // MARK: - Init

    init(
        service: any AppAttestServicing = SystemAppAttestService(),
        keychain: any KeychainStoring = SecItemKeychainStore(),
        logger: TruoraLogger,
        clock: @escaping @Sendable () -> Date = Date.init,
        serverUnavailableQuotaThreshold: Int = 3
    ) {
        self.service = service
        self.keychain = keychain
        self.logger = logger
        self.clock = clock
        self.serverUnavailableQuotaThreshold = serverUnavailableQuotaThreshold
    }

    // MARK: - AttestationProviding

    func start() async {
        // Block re-entry if a task is already running or if state is terminal-success/unavailable.
        guard warmUpTask == nil else { return }
        switch state {
        case .ready, .unavailable:
            return // terminal — do not restart
        case .pending, .error:
            break // allow (re)start
        }
        // Reset state to .pending so snapshot() returns .pending during re-warm-up
        state = .pending
        // Bump the generation BEFORE spawning so the new task's defer only clears
        // the handle when no subsequent shutdown()/start() cycle has superseded it.
        warmUpGeneration &+= 1
        let myGeneration = warmUpGeneration
        warmUpTask = Task { [weak self] in
            await self?.runWarmUp(generation: myGeneration)
        }
    }

    func snapshot() async -> AttestationSnapshot {
        state
    }

    func shutdown() async {
        warmUpTask?.cancel()
        warmUpTask = nil
    }

    /// Waits for any in-flight warm-up Task to complete.
    ///
    /// Used in tests to synchronise after `start()` without polling.
    /// Not part of `AttestationProviding` — internal test-support only.
    func waitForWarmUp() async {
        await warmUpTask?.value
    }

    // MARK: - Factory

    /// Creates an `AppAttestProvider` when running on iOS 14+.
    ///
    /// Returns `nil` on iOS 13 so callers can fall back to
    /// `NoOpAttestationProvider(reason: .unsupported)`.
    static func create(logger: TruoraLogger) -> AppAttestProvider? {
        AppAttestProvider(logger: logger)
    }

    // MARK: - Warm-up logic

    private func runWarmUp(generation: UInt64) async {
        // Only clear the handle if the generation still matches — protects against
        // a shutdown()/start() cycle that lands while the old task is suspended at
        // an await. Without this guard the old task could nil the NEW task's handle
        // (B-cycle2: defer/restart race).
        defer {
            if warmUpGeneration == generation {
                warmUpTask = nil
            }
        }

        // Pre-flight check
        guard service.isSupported else {
            state = .unavailable(reason: "unsupported")
            return
        }

        // Key retrieval
        let keyID: String
        do {
            keyID = try await resolveKeyID()
        } catch let error as AttestationWarmUpError {
            state = error.snapshot
            return
        } catch {
            state = .error(reason: "other")
            return
        }

        // Assertion
        let clientDataHash = makeClientDataHash()
        do {
            let assertionData = try await service.generateAssertion(
                keyID: keyID,
                clientDataHash: clientDataHash
            )
            // Reset quota counter on success
            consecutiveServerUnavailableCount = 0
            let token = assertionData.base64EncodedString()
            state = .ready(token: token, type: "app_attest")
        } catch let dcError as DCError where dcError.code == .invalidKey {
            await purgeInvalidKeyOrLog()
            state = .pending
        } catch {
            state = mapError(error)
        }
    }

    /// B-cycle2: Removes the cached invalid key from the Keychain.
    ///
    /// If the Keychain delete fails we cannot reach into the iOS-managed store
    /// to retry, but the failure MUST be observable in production — otherwise a
    /// truly broken Keychain (e.g. `errSecAuthFailed`, hardware fault) would
    /// allow the same invalid key ID to be read on the next `start()`, looping
    /// the provider into `.error(reason: "other")` indefinitely. We log via
    /// `TruoraLogger` with the underlying error type so prod issues are
    /// debuggable, and proceed regardless: `state` is reset to `.pending` by
    /// the caller so the next `start()` will at least attempt a fresh
    /// `generateKey()` path.
    private func purgeInvalidKeyOrLog() async {
        do {
            try await keychain.delete(key: Self.keychainKeyName)
        } catch {
            let errorType = String(describing: type(of: error))
            Task { [logger, errorType] in
                await logger.logDevice(
                    eventName: "attestation_invalid_key_purge_failed",
                    level: .warning,
                    retention: .oneWeek,
                    metadata: ["error_type": errorType]
                )
            }
        }
    }

    /// Reads the cached key ID from the Keychain, or generates a new one.
    ///
    /// Maps `DCError.serverUnavailable` to quota/timeout based on the session
    /// counter. A single failure produces `.error("timeout")`; once the
    /// `serverUnavailableQuotaThreshold` is reached, produces `.error("quota")`.
    private func resolveKeyID() async throws -> String {
        // Try cached key first — await so the SecItem IPC runs off the actor's executor.
        if let stored = try? await keychain.read(key: Self.keychainKeyName),
           let keyID = String(data: stored, encoding: .utf8), !keyID.isEmpty {
            return keyID
        }

        // Single attempt to generate key; quota/timeout determined by session counter.
        // generateKey errors and keychain errors are handled separately so that
        // the catch clauses below don't intercept AttestationWarmUpError re-throws.
        let keyID: String
        do {
            keyID = try await service.generateKey()
        } catch let dcError as DCError where dcError.code == .serverUnavailable {
            let isQuota = recordQuotaHit()
            throw isQuota ? AttestationWarmUpError.quota : AttestationWarmUpError.timeout
        } catch {
            throw AttestationWarmUpError.other(error)
        }

        // Persist the new key — separate from the generateKey do/catch so that
        // KeychainError is not accidentally caught by the DCError clause above.
        // await so the SecItem IPC runs off the actor's executor.
        do {
            try await keychain.write(key: Self.keychainKeyName, value: Data(keyID.utf8))
        } catch {
            throw AttestationWarmUpError.keychainFailure
        }
        consecutiveServerUnavailableCount = 0
        return keyID
    }

    /// SHA-256 hash of `"truora_attest_" + ISO-8601 timestamp`, used as clientDataHash.
    private func makeClientDataHash() -> Data {
        let timestamp = ISO8601DateFormatter().string(from: clock())
        let input = Data("truora_attest_\(timestamp)".utf8)
        let digest = SHA256.hash(data: input)
        return Data(digest)
    }

    /// Increments the session-level `serverUnavailable` counter, emits a diagnostic log
    /// when the quota threshold is reached, and returns `true` if the quota is hit.
    ///
    /// Called from both `resolveKeyID()` (during `generateKey`) and `mapError()` (during
    /// `generateAssertion`) so that the quota counter accumulates across both code paths.
    ///
    /// - Returns: `true` when `consecutiveServerUnavailableCount >= serverUnavailableQuotaThreshold`.
    @discardableResult
    private func recordQuotaHit() -> Bool {
        consecutiveServerUnavailableCount += 1
        let count = consecutiveServerUnavailableCount
        let isQuota = count >= serverUnavailableQuotaThreshold
        if isQuota {
            Task { [logger, count] in
                await logger.logDevice(
                    eventName: "attestation_quota_heuristic_triggered",
                    level: .warning,
                    retention: .oneWeek,
                    metadata: ["consecutive_server_unavailable": count]
                )
            }
        }
        return isQuota
    }

    /// Maps any error thrown by the App Attest service to an `AttestationSnapshot`.
    private func mapError(_ error: Error) -> AttestationSnapshot {
        if let dcError = error as? DCError {
            switch dcError.code {
            case .serverUnavailable:
                let isQuota = recordQuotaHit()
                return isQuota ? .error(reason: "quota") : .error(reason: "timeout")
            case .invalidKey, .invalidInput:
                return .error(reason: "other")
            case .featureUnsupported:
                return .unavailable(reason: "unsupported")
            default:
                return .error(reason: "other")
            }
        }
        if error is KeychainError {
            return .error(reason: "keychain")
        }
        return .error(reason: "other")
    }
}

// MARK: - Internal error type used only within the warm-up flow

@available(iOS 14.0, *)
private enum AttestationWarmUpError: Error {
    case keychainFailure
    case quota
    case timeout
    case other(Error)

    var snapshot: AttestationSnapshot {
        switch self {
        case .keychainFailure: .error(reason: "keychain")
        case .quota: .error(reason: "quota")
        case .timeout: .error(reason: "timeout")
        case .other: .error(reason: "other")
        }
    }
}
