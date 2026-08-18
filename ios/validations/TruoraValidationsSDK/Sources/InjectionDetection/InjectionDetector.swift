import Foundation

/// Orchestrates layered injection attack detection using a defense-in-depth approach.
///
/// Each detection layer runs the **full checker suite** (Environment + Camera + Jailbreak)
/// and stores the result in its own slot. This way jailbreak/runtime tooling is detected
/// from the first call (SDK init) instead of waiting for the runtime layer to fire.
///
/// - **Layer 1 (Init):** full checker suite at SDK initialization.
/// - **Layer 2 (Camera Setup):** full checker suite re-run when the camera session starts.
/// - **Layer 3 (Runtime):** full checker suite re-run periodically during capture.
///
/// Layers occupy independent slots, so re-running a layer **replaces** its slot rather than
/// accumulating duplicates. `computeTrustResult()` flattens the latest slots into a single
/// `TrustResult`. Thread-safe via `NSLock`.
final class InjectionDetector: @unchecked Sendable {
    private let systemInfo: SystemInfoProviding
    private let cameraInfo: CameraInfoProviding
    private let lock = NSLock()
    private var layerFactors: [Layer: [RiskFactor]] = [:]

    enum Layer: String {
        case initial = "init"
        case camera
        case runtime
    }

    init(
        systemInfo: SystemInfoProviding = DefaultSystemInfoProvider(),
        cameraInfo: CameraInfoProviding = DefaultCameraInfoProvider()
    ) {
        self.systemInfo = systemInfo
        self.cameraInfo = cameraInfo
    }

    // MARK: - Layer 1: Init Checks

    /// Runs the full checker suite at SDK initialization. Detects simulator, jailbreak
    /// tooling and virtual camera signals before capture starts.
    @discardableResult
    func runInitChecks() -> [RiskFactor] {
        let factors = runAllCheckers()
        store(factors, for: .initial)
        return factors
    }

    // MARK: - Layer 2: Camera Checks

    /// Runs the full checker suite when the camera session starts. Replaces the camera
    /// slot so re-runs do not double-count factors.
    @discardableResult
    func runCameraChecks() -> [RiskFactor] {
        let factors = runAllCheckers()
        store(factors, for: .camera)
        return factors
    }

    // MARK: - Layer 3: Runtime Checks

    /// Runs the full checker suite periodically during capture (e.g., every 30 seconds)
    /// to catch tooling activated mid-session.
    @discardableResult
    func runRuntimeChecks() -> [RiskFactor] {
        let factors = runAllCheckers()
        store(factors, for: .runtime)
        return factors
    }

    // MARK: - Trust Result

    /// Computes the trust result from the latest snapshot of every layer slot.
    func computeTrustResult() -> TrustResult {
        lock.lock()
        let factors = layerFactors.values.flatMap { $0 }
        lock.unlock()
        return TrustResult(riskFactors: factors)
    }

    /// Clears all accumulated risk factors, resetting the trust score to 100.
    func reset() {
        lock.lock()
        layerFactors.removeAll()
        lock.unlock()
    }

    // MARK: - Private

    private func runAllCheckers() -> [RiskFactor] {
        EnvironmentChecker(systemInfo: systemInfo).check() +
            CameraChecker(cameraInfo: cameraInfo).check() +
            JailbreakChecker(systemInfo: systemInfo).check()
    }

    private func store(_ factors: [RiskFactor], for layer: Layer) {
        lock.lock()
        layerFactors[layer] = factors
        lock.unlock()
    }

    // MARK: - Reporter Factory

    /// Creates a `DetectionReporter` that wraps this detector for progressive reporting.
    ///
    /// The returned actor orchestrates detect -> encode -> native bridge -> sign -> log,
    /// sending reports through the provided logger at each lifecycle layer.
    ///
    /// - Parameters:
    ///   - logger: Logger for sending `EventType.device` events to the backend
    ///   - flowType: The flow type for this session ("face" or "document"). Immutable once set.
    ///   - blockingThreshold: Trust score below which the flow is blocked (default 50)
    ///   - bridge: Native detection bridge; defaults to `NativeDetectionBridge.create()`
    ///     which returns nil when the XCFramework binary is absent.
    ///   - attestation: Hardware attestation provider; defaults to a no-op provider.
    ///     Existing call sites compile unchanged because of the default value.
    /// - Returns: A new `DetectionReporter` actor bound to this detector
    func createReporter(
        logger: TruoraLogger,
        flowType: String,
        blockingThreshold: Int = 50,
        bridge: (any DetectionBridging)? = NativeDetectionBridge.create(),
        attestation: any AttestationProviding = NoOpAttestationProvider(reason: .disabled)
    ) -> DetectionReporter {
        DetectionReporter(
            detector: self,
            logger: logger,
            flowType: flowType,
            blockingThreshold: blockingThreshold,
            bridge: bridge,
            attestation: attestation
        )
    }
}
