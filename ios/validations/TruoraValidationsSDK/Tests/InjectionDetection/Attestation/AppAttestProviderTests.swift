import DeviceCheck
import XCTest
@testable import TruoraValidationsSDK

@available(iOS 14.0, *)
final class AppAttestProviderTests: XCTestCase {
    // MARK: - Helpers

    private func makeProvider(
        service: MockAppAttestService = MockAppAttestService(),
        keychain: InMemoryKeychainStore = InMemoryKeychainStore()
    ) -> AppAttestProvider {
        AppAttestProvider(
            service: service,
            keychain: keychain,
            logger: MockDetectionLogger()
        )
    }

    /// Calls start(), waits for the warm-up Task to complete, then returns snapshot.
    private func startAndSnapshot(_ provider: AppAttestProvider) async -> AttestationSnapshot {
        await provider.start()
        await provider.waitForWarmUp()
        return await provider.snapshot()
    }

    // MARK: - (a) isSupported == false → .unavailable("unsupported")

    func testStart_whenUnsupported_snapshotIsUnavailable() async {
        let service = MockAppAttestService()
        service.isSupportedValue = false
        let provider = makeProvider(service: service)

        let snapshot = await startAndSnapshot(provider)

        if case .unavailable(let reason) = snapshot {
            XCTAssertEqual(reason, "unsupported")
        } else {
            XCTFail("Expected .unavailable(\"unsupported\"), got \(snapshot)")
        }
    }

    // MARK: - (b) Key already cached in keychain → skips generateKey, reaches .ready

    func testStart_withCachedKey_skipsGenerateKey_andBecomesReady() async throws {
        let service = MockAppAttestService()
        let keychain = InMemoryKeychainStore()
        // Pre-load a key ID into the keychain via the async protocol method.
        try await keychain.write(key: "app_attest_key_id", value: Data("cached-key".utf8))

        let provider = AppAttestProvider(
            service: service,
            keychain: keychain,
            logger: MockDetectionLogger()
        )

        let snapshot = await startAndSnapshot(provider)

        // generateKey must NOT have been called since a cached key was available
        XCTAssertEqual(service.generateKeyCallCount, 0, "generateKey must not be called when key is cached")
        if case .ready = snapshot {
            // pass
        } else {
            XCTFail("Expected .ready(...), got \(snapshot)")
        }
    }

    // MARK: - (c) No cached key, generateKey succeeds → .ready

    func testStart_noCache_generateKeySucceeds_becomesReady() async {
        let service = MockAppAttestService()
        let keychain = InMemoryKeychainStore()
        let provider = makeProvider(service: service, keychain: keychain)

        let snapshot = await startAndSnapshot(provider)

        XCTAssertEqual(service.generateKeyCallCount, 1)
        if case .ready(let token, let type) = snapshot {
            XCTAssertFalse(token.isEmpty, "token must be non-empty")
            XCTAssertEqual(type, "app_attest")
        } else {
            XCTFail("Expected .ready(...), got \(snapshot)")
        }
    }

    // MARK: - (d) DCError.serverUnavailable once → .error("timeout")

    // threshold=2: count=1 after first failure, 1 < 2 → timeout (not quota).

    func testStart_generateKeyThrowsServerUnavailable_once_becomesErrorTimeout() async {
        let service = MockAppAttestService()
        service.generateKeyResult = .failure(DCError(.serverUnavailable))
        let provider = AppAttestProvider(
            service: service,
            keychain: InMemoryKeychainStore(),
            logger: MockDetectionLogger(),
            serverUnavailableQuotaThreshold: 2
        )

        let snapshot = await startAndSnapshot(provider)

        XCTAssertEqual(
            service.generateKeyCallCount,
            1,
            "Provider makes exactly one generateKey attempt per start() call"
        )
        if case .error(let reason) = snapshot {
            XCTAssertEqual(reason, "timeout")
        } else {
            XCTFail("Expected .error(\"timeout\"), got \(snapshot)")
        }
    }

    // MARK: - (e) DCError.serverUnavailable three consecutive times → .error("quota")

    // The session-level counter accumulates across start() calls on the same provider.
    // Three calls with threshold=3 → count reaches 3 on the third call → quota.

    func testStart_generateKeyThrowsServerUnavailable_threeTimes_becomesErrorQuota() async {
        let service = MockAppAttestService()
        service.generateKeyResult = .failure(DCError(.serverUnavailable))

        let provider = AppAttestProvider(
            service: service,
            keychain: InMemoryKeychainStore(),
            logger: MockDetectionLogger(),
            serverUnavailableQuotaThreshold: 3
        )

        // Each start() makes one attempt; the session counter accumulates.
        // After 3 calls, count == threshold → quota.
        await provider.start()
        await provider.waitForWarmUp()
        await provider.start()
        await provider.waitForWarmUp()
        await provider.start()
        await provider.waitForWarmUp()

        let snapshot = await provider.snapshot()

        XCTAssertEqual(
            service.generateKeyCallCount,
            3,
            "generateKey must be called exactly once per start() — 3 total"
        )
        if case .error(let reason) = snapshot {
            XCTAssertEqual(reason, "quota")
        } else {
            XCTFail("Expected .error(\"quota\"), got \(snapshot)")
        }
    }

    // MARK: - (f) keychain write fails → .error("keychain")

    func testStart_keychainWriteFails_becomesErrorKeychain() async {
        let service = MockAppAttestService()
        let keychain = InMemoryKeychainStore()
        keychain.setThrowOnWrite(true)
        let provider = makeProvider(service: service, keychain: keychain)

        let snapshot = await startAndSnapshot(provider)

        if case .error(let reason) = snapshot {
            XCTAssertEqual(reason, "keychain")
        } else {
            XCTFail("Expected .error(\"keychain\"), got \(snapshot)")
        }
    }

    // MARK: - (g) DCError.invalidKey from generateAssertion purges keychain + resets to pending

    func testStart_generateAssertionThrowsInvalidKey_purgesKeyAndResetsToPending() async throws {
        let service = MockAppAttestService()
        service.generateAssertionResult = .failure(DCError(.invalidKey))
        let keychain = InMemoryKeychainStore()
        // Seed a stale key — the provider must purge it on .invalidKey.
        // Use `try await` so an unexpected write failure fails the test loudly.
        try await keychain.write(key: "app_attest_key_id", value: Data("stale".utf8))
        let provider = makeProvider(service: service, keychain: keychain)

        let snapshot = await startAndSnapshot(provider)

        // After .invalidKey we reset state so the next start() can re-warm with a fresh key.
        if case .pending = snapshot {
            // expected
        } else {
            XCTFail("Expected .pending after invalidKey purge, got \(snapshot)")
        }

        // The cached key MUST be gone so the next start() generates a fresh one.
        // Use `try await` so an unexpected read error fails the test loudly rather
        // than silently matching the nil-means-missing case.
        let purged = try await keychain.read(key: "app_attest_key_id")
        XCTAssertNil(purged, "Keychain entry must be purged after DCError.invalidKey")
    }

    // MARK: - (h) shutdown() lifecycle: before-start is a no-op, in-flight is cancelled

    /// Calling `shutdown()` BEFORE `start()` must be safe — there is no warm-up task
    /// to cancel, and a subsequent `start()` should still complete normally.
    func testShutdown_beforeStart_isNoOpAndAllowsLaterStart() async {
        // MockAppAttestService defaults to success (generateKey + generateAssertion both
        // succeed), so after a no-op shutdown + start() the provider must reach .ready.
        let service = MockAppAttestService()
        let provider = makeProvider(service: service)

        await provider.shutdown()
        let snapshot = await startAndSnapshot(provider)

        guard case .ready = snapshot else {
            XCTFail(
                "Expected .ready after shutdown() + start() with a succeeding service, got \(snapshot)"
            )
            return
        }
    }

    /// `shutdown()` while the warm-up task is in flight must cancel that task before
    /// it completes the success path. The post-cancellation snapshot is intentionally
    /// not pinned to a single value: if the actor was cancelled mid-`await` inside
    /// `generateKey()`, the warm-up never reached the `.ready` branch, so `.pending`
    /// (cancelled before any state mutation), `.unavailable`, and `.error` are all
    /// valid terminal outcomes. The load-bearing invariants are:
    ///   1. `generateKey` MUST NOT have run to completion.
    ///   2. The snapshot MUST NOT be `.ready`.
    /// Uses a delayable service so the warm-up is observably mid-flight when
    /// shutdown lands.
    func testShutdown_duringWarmUp_cancelsInFlightTask() async {
        let service = DelayableAppAttestService(generateKeyDelayNs: 500_000_000) // 500 ms
        let provider = AppAttestProvider(
            service: service,
            keychain: InMemoryKeychainStore(),
            logger: MockDetectionLogger()
        )

        // Kick off start without awaiting completion — the warm-up Task is now in flight.
        await provider.start()

        // Yield once so the actor has a chance to schedule the warm-up Task before we
        // ask it to shut down.
        await Task.yield()

        await provider.shutdown()

        // After shutdown the actor's warm-up Task must be cancelled — the state may
        // still be .pending (cancelled before generateKey returned) which is the
        // correct cancellation outcome.
        // After shutdown, generateKey must NOT have completed — it was either cancelled
        // mid-sleep, or never reached its return statement. This is the load-bearing
        // assertion: regardless of which final snapshot we end up in, the warm-up was
        // not allowed to finish.
        XCTAssertFalse(
            service.generateKeyCompleted,
            "Warm-up generateKey must NOT have completed after a mid-flight shutdown"
        )
        // Snapshot must NOT be .ready — if generateKey was cancelled, the success path
        // never ran. .pending, .unavailable, and .error are all acceptable terminal
        // outcomes for a cancellation.
        let snapshot = await provider.snapshot()
        if case .ready = snapshot {
            XCTFail("Snapshot must not be .ready after a mid-flight shutdown, got \(snapshot)")
        }
    }

    // MARK: - snapshot() before start() returns .pending

    func testSnapshot_beforeStart_returnsPending() async {
        let provider = makeProvider()
        let snapshot = await provider.snapshot()
        if case .pending = snapshot {
            // pass
        } else {
            XCTFail("Expected .pending before start(), got \(snapshot)")
        }
    }
}

// MARK: - DelayableAppAttestService

/// Test double that sleeps inside `generateKey` so the warm-up Task is observably
/// in flight, allowing tests to validate cancellation behaviour.
@available(iOS 14.0, *)
private final class DelayableAppAttestService: AppAttestServicing, @unchecked Sendable {
    private let lock = NSLock()
    private let generateKeyDelayNs: UInt64
    private var _generateKeyCompleted = false

    var generateKeyCompleted: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _generateKeyCompleted
    }

    init(generateKeyDelayNs: UInt64) {
        self.generateKeyDelayNs = generateKeyDelayNs
    }

    var isSupported: Bool {
        true
    }

    func generateKey() async throws -> String {
        try await Task.sleep(nanoseconds: generateKeyDelayNs)
        lock.lock()
        _generateKeyCompleted = true
        lock.unlock()
        return "delayed-key-id"
    }

    func attestKey(keyID _: String, clientDataHash _: Data) async throws -> Data {
        Data("attest".utf8)
    }

    func generateAssertion(keyID _: String, clientDataHash _: Data) async throws -> Data {
        Data("assertion".utf8)
    }
}
