import Foundation
import XCTest
@testable import TruoraValidationsSDK

final class InjectionDetectorTests: XCTestCase {
    // MARK: - Clean Device

    func testCleanDevice_scoreIs100() {
        let systemInfo = MockSystemInfoProvider()
        let cameraInfo = MockCameraInfoProvider(devices: [
            CameraDeviceInfo(deviceType: .builtInWideAngle, position: "back", uniqueID: "cam-1", lensPosition: 0.5)
        ])
        let detector = InjectionDetector(systemInfo: systemInfo, cameraInfo: cameraInfo)

        _ = detector.runInitChecks()
        _ = detector.runCameraChecks()
        let result = detector.computeTrustResult()

        XCTAssertEqual(result.trustScore, 100)
        XCTAssertTrue(result.riskFactors.isEmpty)
    }

    // MARK: - Layer 1: Init Checks

    func testRunInitChecks_delegatesToEnvironmentAndJailbreakCheckers() {
        let systemInfo = MockSystemInfoProvider(
            isSimulator: true,
            existingFiles: ["/Applications/Cydia.app"]
        )
        let cameraInfo = MockCameraInfoProvider()
        let detector = InjectionDetector(systemInfo: systemInfo, cameraInfo: cameraInfo)

        let factors = detector.runInitChecks()

        let simulatorFactors = factors.filter { $0.category == "simulator" }
        let jailbreakFactors = factors.filter { $0.category == "jailbreak" }
        XCTAssertFalse(simulatorFactors.isEmpty)
        XCTAssertFalse(jailbreakFactors.isEmpty)
    }

    // MARK: - Layer 2: Camera Checks

    func testRunCameraChecks_delegatesToCameraChecker() {
        let systemInfo = MockSystemInfoProvider()
        let cameraInfo = MockCameraInfoProvider(devices: [
            CameraDeviceInfo(deviceType: .external, position: "unspecified", uniqueID: "ext-1", lensPosition: nil)
        ])
        let detector = InjectionDetector(systemInfo: systemInfo, cameraInfo: cameraInfo)

        let factors = detector.runCameraChecks()

        XCTAssertFalse(factors.isEmpty)
        XCTAssertTrue(factors.contains { $0.category == "virtual_camera" })
    }

    // MARK: - Layer 3: Runtime Checks

    func testRunRuntimeChecks_rerunsJailbreakChecker() {
        let systemInfo = MockSystemInfoProvider(
            existingFiles: ["/bin/bash"]
        )
        let cameraInfo = MockCameraInfoProvider()
        let detector = InjectionDetector(systemInfo: systemInfo, cameraInfo: cameraInfo)

        let factors = detector.runRuntimeChecks()

        XCTAssertFalse(factors.isEmpty)
        XCTAssertTrue(factors.contains { $0.category == "jailbreak" })
    }

    // MARK: - Simulator Detected (Low Score)

    func testSimulatorDetected_producesLowScore() {
        let systemInfo = MockSystemInfoProvider(
            isSimulator: true,
            simulatorDeviceName: "iPhone 15"
        )
        let cameraInfo = MockCameraInfoProvider(devices: [
            CameraDeviceInfo(deviceType: .builtInWideAngle, position: "back", uniqueID: "cam-1", lensPosition: 0.5)
        ])
        let detector = InjectionDetector(systemInfo: systemInfo, cameraInfo: cameraInfo)

        _ = detector.runInitChecks()
        let result = detector.computeTrustResult()

        // isSimulator=50 + simulatorDeviceName=30 = 80 penalty, score should be 20
        XCTAssertEqual(result.trustScore, 20)
    }

    // MARK: - Jailbroken Device (Very Low Score)

    func testJailbrokenDevice_producesVeryLowScore() {
        let systemInfo = MockSystemInfoProvider(
            existingFiles: [
                "/Applications/Cydia.app",
                "/bin/bash",
                "/usr/sbin/sshd"
            ],
            canWriteSandbox: true
        )
        let cameraInfo = MockCameraInfoProvider(devices: [
            CameraDeviceInfo(deviceType: .builtInWideAngle, position: "back", uniqueID: "cam-1", lensPosition: 0.5)
        ])
        let detector = InjectionDetector(systemInfo: systemInfo, cameraInfo: cameraInfo)

        _ = detector.runInitChecks()
        let result = detector.computeTrustResult()

        // 3 files * 20 = 60, sandbox = 50, total = 110, score clamped to 0
        XCTAssertEqual(result.trustScore, 0)
    }

    // MARK: - Cumulative Layer Accumulation

    func testAllLayersAccumulate() {
        let systemInfo = MockSystemInfoProvider(
            isSimulator: true,
            existingFiles: ["/Applications/Cydia.app"]
        )
        let cameraInfo = MockCameraInfoProvider(devices: [
            CameraDeviceInfo(deviceType: .external, position: "unspecified", uniqueID: "ext-1", lensPosition: nil)
        ])
        let detector = InjectionDetector(systemInfo: systemInfo, cameraInfo: cameraInfo)

        _ = detector.runInitChecks()
        _ = detector.runCameraChecks()
        let result = detector.computeTrustResult()

        // Every layer runs the full checker suite. Distinct signals expected:
        // simulator runtime = 50, jailbreak file = 20, external camera = 30 → total 100, score 0.
        // Dedupe collapses the same signals across layers into a single factor each.
        XCTAssertEqual(result.trustScore, 0)
        XCTAssertEqual(result.riskFactors.count, 3)
    }

    // MARK: - Init Detects All Signals (regression: PROC-7033)

    func testInitChecks_detectsJailbreakAndCameraBeforeCaptureStarts() {
        // Reproduces the latency defect that allowed Pichincha sessions to start
        // capture before Frida/jailbreak signals fired. With the multi-layer fix the
        // init layer alone must surface every category.
        let systemInfo = MockSystemInfoProvider(
            existingFiles: ["/Applications/Cydia.app"]
        )
        let cameraInfo = MockCameraInfoProvider(devices: [
            CameraDeviceInfo(deviceType: .external, position: "unspecified", uniqueID: "ext-1", lensPosition: nil)
        ])
        let detector = InjectionDetector(systemInfo: systemInfo, cameraInfo: cameraInfo)

        let factors = detector.runInitChecks()
        let result = detector.computeTrustResult()

        XCTAssertTrue(factors.contains { $0.category == "jailbreak" })
        XCTAssertTrue(factors.contains { $0.category == "virtual_camera" })
        // jailbreak file = 20, external camera = 30 → score 50
        XCTAssertEqual(result.trustScore, 50)
    }

    // MARK: - No Risk Factors

    func testNoRiskFactors_returns100() {
        let systemInfo = MockSystemInfoProvider()
        let cameraInfo = MockCameraInfoProvider(devices: [
            CameraDeviceInfo(deviceType: .builtInWideAngle, position: "back", uniqueID: "cam-1", lensPosition: 0.5)
        ])
        let detector = InjectionDetector(systemInfo: systemInfo, cameraInfo: cameraInfo)

        let result = detector.computeTrustResult()

        XCTAssertEqual(result.trustScore, 100)
        XCTAssertTrue(result.riskFactors.isEmpty)
    }

    // MARK: - Penalties Exceed 100

    func testPenaltiesExceed100_clampedToZero() {
        let systemInfo = MockSystemInfoProvider(
            isSimulator: true,
            simulatorDeviceName: "iPhone 15",
            existingFiles: ["/Applications/Cydia.app", "/bin/bash"],
            canWriteSandbox: true,
            loadedDylibs: ["/Library/MobileSubstrate/MobileSubstrate.dylib"]
        )
        let cameraInfo = MockCameraInfoProvider()
        let detector = InjectionDetector(systemInfo: systemInfo, cameraInfo: cameraInfo)

        _ = detector.runInitChecks()
        let result = detector.computeTrustResult()

        // Total penalty far exceeds 100
        XCTAssertEqual(result.trustScore, 0)
    }

    // MARK: - Reset

    func testReset_clearsAccumulatedFactors() {
        let systemInfo = MockSystemInfoProvider(isSimulator: true)
        let cameraInfo = MockCameraInfoProvider(devices: [
            CameraDeviceInfo(deviceType: .builtInWideAngle, position: "back", uniqueID: "cam-1", lensPosition: 0.5)
        ])
        let detector = InjectionDetector(systemInfo: systemInfo, cameraInfo: cameraInfo)

        _ = detector.runInitChecks()
        let beforeReset = detector.computeTrustResult()
        XCTAssertLessThan(beforeReset.trustScore, 100)

        detector.reset()
        let afterReset = detector.computeTrustResult()

        XCTAssertEqual(afterReset.trustScore, 100)
        XCTAssertTrue(afterReset.riskFactors.isEmpty)
    }

    // MARK: - Protocol Injection (Testability)

    func testAcceptsProtocolTypesViaInit() {
        let systemInfo: SystemInfoProviding = MockSystemInfoProvider()
        let cameraInfo: CameraInfoProviding = MockCameraInfoProvider()
        let detector = InjectionDetector(systemInfo: systemInfo, cameraInfo: cameraInfo)

        let result = detector.computeTrustResult()
        XCTAssertEqual(result.trustScore, 100)
    }
}
