import Foundation

/// Orchestrates injection detection reporting: detect -> encode -> native bridge -> sign -> log.
///
/// Uses `actor` isolation for thread safety (matches `TruoraLogger`'s async API).
/// Each call to `reportLayer(_:)` runs the appropriate detection layer, encodes
/// the results to a bitmask, calls the native bridge for additional signals,
/// signs the report using internally-stored `validationId` and `flowType`, and
/// logs it via `TruoraLogger.logDevice()`.
///
/// **Lifecycle state:** `flowType` is fixed at init and never changes. `validationId`
/// starts as an empty string (correct for the init layer, which fires before a
/// validation session exists) and must be updated via `updateValidationId(_:)` once
/// the server returns the real ID. Camera and runtime layers will then include the
/// real ID in their signed reports.
///
/// **Deduplication:** Tracks an accumulated bitmask across calls. Only new
/// managed signals (delta) are reported, preventing double-counting when
/// runtime re-checks find the same conditions. Native bits have no delta
/// concept — the delta is computed from managed bits only, BEFORE native bits
/// are OR'd into the accumulator.
///
/// **Blocking:** Returns `true` when the trust score falls below
/// `blockingThreshold`, signaling the caller to abort the capture flow.
///
/// **Degraded mode:** When `bridge` is nil or `nativeDisabledForSession` is
/// true, the reporter operates in managed-only mode. The `signature` field
/// is set to `"unsigned"` and native bitmask bits are not included.
actor DetectionReporter {
    private let detector: InjectionDetector
    private let logger: TruoraLogger
    private let flowType: String
    private let blockingThreshold: Int
    private let bridge: (any DetectionBridging)?
    private let attestation: any AttestationProviding
    /// Maps an `AttestationSnapshot` to the metadata fields merged into each
    /// detection report. Production calls `buildAttestationMetadata`; tests can
    /// inject a builder that emits colliding keys (e.g. `trust_score`) to
    /// guarantee the merge closure `{ current, _ in current }` actually defends
    /// against base-metadata overwrites.
    private let attestationMetadataBuilder: @Sendable (AttestationSnapshot) -> [String: Any]
    private var validationId: String = ""
    private var accumulatedBitmask: UInt32 = 0
    private var nativeDisabledForSession: Bool = false

    /// Creates a reporter that wraps an injection detector and logs results.
    ///
    /// - Parameters:
    ///   - detector: The `InjectionDetector` providing layered detection
    ///   - logger: Logger for sending `EventType.device` events to the backend
    ///   - flowType: The flow type for this session ("face" or "document"). Immutable.
    ///   - blockingThreshold: Trust score below which the flow is blocked (default 50)
    ///   - bridge: Native detection bridge; defaults to `NativeDetectionBridge.create()`
    ///     which returns nil when the XCFramework binary is absent.
    ///   - attestation: Hardware attestation provider; defaults to a no-op provider
    ///     that emits `attest_status = "unavailable_unsupported"`. Use
    ///     `NoOpAttestationProvider(reason: .disabled)` when the integrator
    ///     explicitly opts out via config; leave the default when no provider
    ///     was wired at all.
    ///   - attestationMetadataBuilder: Internal injection point for tests that
    ///     need to exercise the merge collision contract. Defaults to the
    ///     production mapper `buildAttestationMetadata`.
    init(
        detector: InjectionDetector,
        logger: TruoraLogger,
        flowType: String,
        blockingThreshold: Int = 50,
        bridge: (any DetectionBridging)? = NativeDetectionBridge.create(),
        attestation: any AttestationProviding = NoOpAttestationProvider(reason: .unsupported),
        attestationMetadataBuilder: @escaping @Sendable (AttestationSnapshot) -> [String: Any] =
            buildAttestationMetadata
    ) {
        self.detector = detector
        self.logger = logger
        self.flowType = flowType
        self.blockingThreshold = blockingThreshold
        self.bridge = bridge
        self.attestation = attestation
        self.attestationMetadataBuilder = attestationMetadataBuilder
    }

    /// Updates the validation ID used in subsequent `reportLayer` calls.
    ///
    /// Call this once the server has returned the real validation ID.
    /// The init layer fires with an empty string, which is correct behaviour —
    /// no validation session exists at SDK entry. Camera and runtime layers
    /// receive the real ID after this method is called.
    func updateValidationId(_ id: String) {
        self.validationId = id
    }

    /// Runs the named detection layer, encodes results, calls native bridge, signs, and logs.
    ///
    /// - Parameter layerName: Layer identifier: "init", "camera", or "runtime"
    /// - Returns: `true` if the trust score is below the blocking threshold
    ///   and the caller should abort the flow.
    ///
    /// Uses internal `validationId` (updated via `updateValidationId(_:)`) and
    /// `flowType` (fixed at init) for report signing.
    func reportLayer(_ layerName: String) async -> Bool {
        // 1. Run appropriate detector method
        guard runDetectorLayer(layerName) else { return false }

        // 2. Get cumulative trust result
        let trustResult = detector.computeTrustResult()

        // 3. Encode bitmask from all accumulated risk factors
        let newBitmask = BitmaskEncoder.encode(trustResult.riskFactors)

        // 4. Compute delta: only new managed signals since last report
        //    CRITICAL: delta must be computed BEFORE native bits are OR'd in,
        //    so native bits do not inflate the managed delta.
        let deltaBitmask = newBitmask & ~accumulatedBitmask

        // 5. Update accumulated state with managed bits
        accumulatedBitmask |= newBitmask

        // 6. Timestamp
        let timestamp = UInt64(Date().timeIntervalSince1970)

        // 7. Call native bridge and OR result into accumulated bitmask
        let nativeBitmask = callNativeBridge()
        if let nb = nativeBitmask {
            accumulatedBitmask |= nb
        }

        // 8. Compute signature using final accumulated bitmask
        let signature = computeSignature(
            trustScore: UInt32(max(0, trustResult.trustScore)),
            timestamp: timestamp
        )

        // 9. Determine log level based on blocking threshold
        let shouldBlock = trustResult.trustScore < blockingThreshold
        let level: LogLevel = shouldBlock ? .error : .info

        // 10. Poll attestation snapshot (non-blocking actor read)
        let attestationSnapshot = await attestation.snapshot()
        let attestationFields = attestationMetadataBuilder(attestationSnapshot)

        // 11. Log the detection report as a device event
        let baseMetadata: [String: Any] = [
            "trust_score": trustResult.trustScore,
            "risk_bitmask": String(accumulatedBitmask, radix: 16),
            "delta_bitmask": String(deltaBitmask, radix: 16),
            "ts": timestamp,
            "bitmask_v": BitmaskEncoder.version,
            "signature": signature
        ]
        // B4-3: Use { current, _ in current } so attestation fields cannot overwrite base detection
        // metadata (trust_score, risk_bitmask, signature, etc.) if key names ever collide.
        let metadata = baseMetadata.merging(attestationFields) { current, _ in current }

        await logger.logDevice(
            eventName: "injection_\(layerName)",
            level: level,
            retention: .oneWeek,
            metadata: metadata
        )

        return shouldBlock
    }

    /// Clears accumulated state, session-disable flag, validation ID, and resets the underlying detector.
    ///
    /// Note: `flowType` is a `let` property and is never cleared.
    func reset() {
        validationId = ""
        accumulatedBitmask = 0
        nativeDisabledForSession = false
        detector.reset()
    }

    // MARK: - Private

    /// Dispatches to the correct detector method based on layer name.
    ///
    /// - Returns: `true` if the layer was recognized and run,
    ///   `false` for unknown layer names.
    private func runDetectorLayer(_ layerName: String) -> Bool {
        switch layerName {
        case "init":
            detector.runInitChecks()
            return true
        case "camera":
            detector.runCameraChecks()
            return true
        case "runtime":
            detector.runRuntimeChecks()
            return true
        default:
            assertionFailure("Unknown detection layer: \(layerName)")
            return false
        }
    }

    /// Calls the native bridge to run C-level detection checks.
    ///
    /// Returns `nil` when:
    /// - Bridge is nil (XCFramework absent)
    /// - `nativeDisabledForSession` is true (previous version mismatch)
    /// - Bridge reports an unexpected bitmask version
    ///
    /// On version mismatch, sets `nativeDisabledForSession = true` and logs a warning.
    private func callNativeBridge() -> UInt32? {
        guard !nativeDisabledForSession, let bridge else { return nil }
        let version = bridge.bitmaskVersion()
        guard version == BitmaskEncoder.expectedNativeVersion else {
            Task { [logger] in
                await logger.logDevice(
                    eventName: "injection_native_version_mismatch",
                    level: .warning,
                    retention: .oneWeek,
                    metadata: [
                        "expected": BitmaskEncoder.expectedNativeVersion,
                        "actual": version
                    ]
                )
            }
            nativeDisabledForSession = true
            return nil
        }
        return bridge.runChecks(checksMask: 0)
    }

    /// Computes the HMAC-SHA256 signature using the native bridge.
    ///
    /// Uses `self.validationId` and `self.flowType` from internal actor state.
    /// Returns `"unsigned"` when the bridge is nil or native is disabled.
    private func computeSignature(
        trustScore: UInt32,
        timestamp: UInt64
    ) -> String {
        guard !nativeDisabledForSession, let bridge else { return "unsigned" }
        return bridge.signReport(
            validationId: self.validationId,
            flowType: self.flowType,
            trustScore: trustScore,
            riskBitmask: accumulatedBitmask,
            timestamp: timestamp
        )
    }
}
