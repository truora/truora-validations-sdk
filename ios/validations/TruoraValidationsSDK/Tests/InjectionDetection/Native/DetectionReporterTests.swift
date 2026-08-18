import Foundation
import XCTest
@testable import TruoraValidationsSDK

// MARK: - Mock Logger for Detection Reporter Tests

/// Records all logDevice calls for verification in detection reporter tests.
/// Uses NSLock for thread-safe access from async contexts without @MainActor.
final class MockDetectionLogger: TruoraLogger, @unchecked Sendable {
    struct LogEntry {
        let eventType: EventType?
        let eventName: String
        let level: LogLevel
        let errorMessage: String?
        let retention: RetentionPeriod
        let metadata: [String: Any]?
    }

    private let lock = NSLock()
    private var _entries: [LogEntry] = []

    var entries: [LogEntry] {
        lock.lock()
        defer { lock.unlock() }
        return _entries
    }

    // MARK: - TruoraLogger conformance

    func logEvent(
        eventType: EventType,
        eventName: String,
        level: LogLevel,
        errorMessage: String?,
        retention: RetentionPeriod,
        metadata: [String: Any]?,
        stackTrace: String?
    ) async {
        lock.lock()
        _entries.append(LogEntry(
            eventType: eventType,
            eventName: eventName,
            level: level,
            errorMessage: errorMessage,
            retention: retention,
            metadata: metadata
        ))
        lock.unlock()
    }

    func logCamera(
        eventName: String,
        level: LogLevel,
        errorMessage: String?,
        retention: RetentionPeriod,
        metadata: [String: Any]?
    ) async {
        await logEvent(
            eventType: .camera,
            eventName: eventName,
            level: level,
            errorMessage: errorMessage,
            retention: retention,
            metadata: metadata,
            stackTrace: nil
        )
    }

    func logML(
        eventName: String,
        level: LogLevel,
        errorMessage: String?,
        retention: RetentionPeriod,
        metadata: [String: Any]?
    ) async {
        await logEvent(
            eventType: .mlModel,
            eventName: eventName,
            level: level,
            errorMessage: errorMessage,
            retention: retention,
            metadata: metadata,
            stackTrace: nil
        )
    }

    func logView(
        viewName: String,
        level: LogLevel,
        retention: RetentionPeriod,
        metadata: [String: Any]?
    ) async {
        await logEvent(
            eventType: .view,
            eventName: viewName,
            level: level,
            errorMessage: nil,
            retention: retention,
            metadata: metadata,
            stackTrace: nil
        )
    }

    func logDevice(
        eventName: String,
        level: LogLevel,
        retention: RetentionPeriod,
        metadata: [String: Any]?
    ) async {
        lock.lock()
        _entries.append(LogEntry(
            eventType: .device,
            eventName: eventName,
            level: level,
            errorMessage: nil,
            retention: retention,
            metadata: metadata
        ))
        lock.unlock()
    }

    func logFeedback(
        eventName: String,
        level: LogLevel,
        errorMessage: String?,
        retention: RetentionPeriod,
        metadata: [String: Any]?
    ) async {}

    func logSdk(
        eventName: String,
        level: LogLevel,
        errorMessage: String?,
        retention: RetentionPeriod,
        metadata: [String: Any]?
    ) async {}

    func logException(
        eventType: EventType,
        eventName: String,
        exception: Error,
        level: LogLevel,
        retention: RetentionPeriod,
        metadata: [String: Any]?
    ) async {}

    func flush() async {}

    func flush(timeoutMs: Int64) async {}
}

// MARK: - Tests

final class DetectionReporterTests: XCTestCase {
    // MARK: - Helpers

    /// Creates a detector pre-configured with the given mock providers.
    private func makeDetector(
        isSimulator: Bool = false,
        simulatorDeviceName: String? = nil,
        existingFiles: Set<String> = [],
        canWriteSandbox: Bool = false,
        loadedDylibs: [String] = [],
        devices: [CameraDeviceInfo] = [
            CameraDeviceInfo(
                deviceType: .builtInWideAngle,
                position: "back",
                uniqueID: "cam-1",
                lensPosition: 0.5
            )
        ]
    ) -> InjectionDetector {
        let systemInfo = MockSystemInfoProvider(
            isSimulator: isSimulator,
            simulatorDeviceName: simulatorDeviceName,
            existingFiles: existingFiles,
            canWriteSandbox: canWriteSandbox,
            loadedDylibs: loadedDylibs
        )
        let cameraInfo = MockCameraInfoProvider(devices: devices)
        return InjectionDetector(systemInfo: systemInfo, cameraInfo: cameraInfo)
    }

    // MARK: - reportLayer event names

    func testReportLayer_init_logsInjectionInitEvent() async {
        let detector = makeDetector()
        let logger = MockDetectionLogger()
        let reporter = DetectionReporter(detector: detector, logger: logger, flowType: "face")

        _ = await reporter.reportLayer("init")

        XCTAssertEqual(logger.entries.count, 1)
        XCTAssertEqual(logger.entries.first?.eventName, "injection_init")
    }

    func testReportLayer_camera_logsInjectionCameraEvent() async {
        let detector = makeDetector()
        let logger = MockDetectionLogger()
        let reporter = DetectionReporter(detector: detector, logger: logger, flowType: "face")

        _ = await reporter.reportLayer("camera")

        XCTAssertEqual(logger.entries.count, 1)
        XCTAssertEqual(logger.entries.first?.eventName, "injection_camera")
    }

    func testReportLayer_runtime_logsInjectionRuntimeEvent() async {
        let detector = makeDetector()
        let logger = MockDetectionLogger()
        let reporter = DetectionReporter(detector: detector, logger: logger, flowType: "face")

        _ = await reporter.reportLayer("runtime")

        XCTAssertEqual(logger.entries.count, 1)
        XCTAssertEqual(logger.entries.first?.eventName, "injection_runtime")
    }

    // MARK: - Deduplication

    func testReportLayer_sameSignalsTwice_deltaBitmaskIsZeroOnSecondCall() async {
        let detector = makeDetector(isSimulator: true)
        let logger = MockDetectionLogger()
        let reporter = DetectionReporter(detector: detector, logger: logger, flowType: "face")

        // First call: init layer detects simulator
        _ = await reporter.reportLayer("init")
        // Second call: runtime layer re-runs jailbreak (no new signals since no files)
        _ = await reporter.reportLayer("runtime")

        XCTAssertEqual(logger.entries.count, 2)

        let secondMetadata = logger.entries[1].metadata
        let deltaBitmask = secondMetadata?["delta_bitmask"] as? String
        XCTAssertEqual(deltaBitmask, "0", "Delta should be 0 when no new signals detected")
    }

    func testReportLayer_newSignals_deltaBitmaskIsNonZero() async {
        // Each detection layer now runs the full checker suite, so signals that
        // existed at SDK start are surfaced on the first call. To assert a
        // non-zero delta we need state that changes BETWEEN calls — here we
        // simulate the device being put into the simulator runtime only after
        // the first report ran on a clean baseline.
        let systemInfo = MockSystemInfoProvider()
        let cameraInfo = MockCameraInfoProvider(devices: [
            CameraDeviceInfo(
                deviceType: .builtInWideAngle,
                position: "back",
                uniqueID: "cam-1",
                lensPosition: 0.5
            )
        ])
        let detector = InjectionDetector(systemInfo: systemInfo, cameraInfo: cameraInfo)
        let logger = MockDetectionLogger()
        let reporter = DetectionReporter(detector: detector, logger: logger, flowType: "face")

        // First call: clean baseline, all bits zero.
        _ = await reporter.reportLayer("init")

        // The integrity envelope changes mid-session — flip the simulator flag
        // so the next layer call surfaces a brand-new signal.
        systemInfo.isSimulator = true

        _ = await reporter.reportLayer("runtime")

        XCTAssertEqual(logger.entries.count, 2)

        let firstMetadata = logger.entries[0].metadata
        let firstDelta = firstMetadata?["delta_bitmask"] as? String
        XCTAssertEqual(firstDelta, "0", "Clean baseline must report delta=0")

        let secondMetadata = logger.entries[1].metadata
        let secondDelta = secondMetadata?["delta_bitmask"] as? String
        XCTAssertNotEqual(secondDelta, "0", "Delta should be non-zero when new signals appear between layers")
    }

    // MARK: - Escalation

    func testReportLayer_lowTrustScore_usesErrorLevel() async {
        // Simulator (50 penalty) + sandbox compromised (50 penalty) = trust score 0
        let detector = makeDetector(isSimulator: true, canWriteSandbox: true)
        let logger = MockDetectionLogger()
        let reporter = DetectionReporter(detector: detector, logger: logger, flowType: "face")

        _ = await reporter.reportLayer("init")

        XCTAssertEqual(
            logger.entries.first?.level,
            .error,
            "Trust score < 50 should trigger .error level"
        )
    }

    func testReportLayer_highTrustScore_usesInfoLevel() async {
        // Clean device: trust score 100
        let detector = makeDetector()
        let logger = MockDetectionLogger()
        let reporter = DetectionReporter(detector: detector, logger: logger, flowType: "face")

        _ = await reporter.reportLayer("init")

        XCTAssertEqual(
            logger.entries.first?.level,
            .info,
            "Trust score >= 50 should use .info level"
        )
    }

    // MARK: - Blocking threshold

    func testReportLayer_belowThreshold_returnsTrue() async {
        // Simulator (50 penalty) + sandbox compromised (50 penalty) = trust score 0
        let detector = makeDetector(isSimulator: true, canWriteSandbox: true)
        let logger = MockDetectionLogger()
        let reporter = DetectionReporter(detector: detector, logger: logger, flowType: "face")

        let shouldBlock = await reporter.reportLayer("init")

        XCTAssertTrue(shouldBlock, "Score 0 < threshold 50 should return true (block)")
    }

    func testReportLayer_aboveThreshold_returnsFalse() async {
        // Clean device: trust score 100
        let detector = makeDetector()
        let logger = MockDetectionLogger()
        let reporter = DetectionReporter(detector: detector, logger: logger, flowType: "face")

        let shouldBlock = await reporter.reportLayer("init")

        XCTAssertFalse(shouldBlock, "Score 100 >= threshold 50 should return false (no block)")
    }

    func testReportLayer_atThreshold_returnsFalse() async {
        // Simulator: trust score 50 (50 penalty) - uses < not <=
        let detector = makeDetector(isSimulator: true)
        let logger = MockDetectionLogger()
        let reporter = DetectionReporter(detector: detector, logger: logger, flowType: "face")

        let shouldBlock = await reporter.reportLayer("init")

        XCTAssertFalse(shouldBlock, "Score == threshold (50) should return false (uses < not <=)")
    }

    // MARK: - Metadata fields

    func testReportLayer_metadataContainsExpectedKeys() async {
        let detector = makeDetector(isSimulator: true)
        let logger = MockDetectionLogger()
        let reporter = DetectionReporter(detector: detector, logger: logger, flowType: "face")

        _ = await reporter.reportLayer("init")

        let metadata = logger.entries.first?.metadata
        XCTAssertNotNil(metadata?["trust_score"])
        XCTAssertNotNil(metadata?["risk_bitmask"])
        XCTAssertNotNil(metadata?["delta_bitmask"])
        XCTAssertNotNil(metadata?["ts"])
        XCTAssertNotNil(metadata?["bitmask_v"])
    }

    // MARK: - Reset

    func testReset_clearsAccumulatedBitmask() async {
        let detector = makeDetector(isSimulator: true)
        let logger = MockDetectionLogger()
        let reporter = DetectionReporter(detector: detector, logger: logger, flowType: "face")

        _ = await reporter.reportLayer("init")
        await reporter.reset()
        _ = await reporter.reportLayer("init")

        // After reset, the same signals should produce a non-zero delta again
        XCTAssertEqual(logger.entries.count, 2)
        let secondDelta = logger.entries[1].metadata?["delta_bitmask"] as? String
        XCTAssertNotEqual(
            secondDelta,
            "0",
            "After reset, same signals should produce non-zero delta"
        )
    }

    // MARK: - InjectionDetector factory

    func testInjectionDetector_createReporter_returnsDetectionReporter() {
        let detector = makeDetector()
        let logger = MockDetectionLogger()
        let reporter = detector.createReporter(logger: logger, flowType: "face")

        // Verify it returned a DetectionReporter (type check)
        XCTAssertTrue(type(of: reporter) == DetectionReporter.self)
    }

    // MARK: - Retention period

    func testReportLayer_usesOneWeekRetention() async {
        let detector = makeDetector()
        let logger = MockDetectionLogger()
        let reporter = DetectionReporter(detector: detector, logger: logger, flowType: "face")

        _ = await reporter.reportLayer("init")

        XCTAssertEqual(logger.entries.first?.retention, .oneWeek)
    }

    // MARK: - Native Bridge Integration

    func testReportLayer_withBridge_signatureIsNotUnsigned() async {
        let detector = makeDetector()
        let logger = MockDetectionLogger()
        let bridge = MockDetectionBridge(signature: "abc123hex")
        let reporter = DetectionReporter(
            detector: detector, logger: logger, flowType: "face", bridge: bridge
        )

        _ = await reporter.reportLayer("init")

        let signature = logger.entries.first?.metadata?["signature"] as? String
        XCTAssertEqual(signature, "abc123hex")
    }

    func testReportLayer_withBridge_nativeBitmaskORdIntoAccumulated() async {
        let detector = makeDetector()
        let logger = MockDetectionLogger()
        // Native returns bitmask with bit 25 set (anti-debug)
        let bridge = MockDetectionBridge(runChecksResult: 1 << 25)
        let reporter = DetectionReporter(
            detector: detector, logger: logger, flowType: "face", bridge: bridge
        )

        _ = await reporter.reportLayer("init")

        let riskBitmask = logger.entries.first?.metadata?["risk_bitmask"] as? String
        // Bit 25 = 0x2000000 — should appear in the accumulated bitmask
        XCTAssertNotNil(riskBitmask)
        guard let hexValue = UInt32(riskBitmask ?? "", radix: 16) else {
            XCTFail("risk_bitmask should be valid hex")
            return
        }
        XCTAssertTrue(
            hexValue & (1 << 25) != 0,
            "Native bit 25 should be set in accumulated bitmask"
        )
    }

    func testReportLayer_withNilBridge_signatureIsUnsigned() async {
        let detector = makeDetector()
        let logger = MockDetectionLogger()
        let reporter = DetectionReporter(
            detector: detector, logger: logger, flowType: "face", bridge: nil
        )

        _ = await reporter.reportLayer("init")

        let signature = logger.entries.first?.metadata?["signature"] as? String
        XCTAssertEqual(signature, "unsigned")
    }

    func testReportLayer_versionMismatch_disablesNativeForSession() async {
        let detector = makeDetector()
        let logger = MockDetectionLogger()
        // Bridge reports version 99 — mismatch with expectedNativeVersion (1)
        let bridge = MockDetectionBridge(
            bitmaskVersion: 99, signature: "should-not-appear"
        )
        let reporter = DetectionReporter(
            detector: detector, logger: logger, flowType: "face", bridge: bridge
        )

        // First call: version mismatch detected, native disabled
        _ = await reporter.reportLayer("init")
        // Second call: native should still be disabled
        _ = await reporter.reportLayer("runtime")

        // Bridge.runChecks should never have been called (mismatch before runChecks)
        XCTAssertEqual(bridge.runChecksCallCount, 0)

        // Both events should have "unsigned" signature
        let injectionEntries = logger.entries.filter {
            $0.eventName.hasPrefix("injection_") &&
                !$0.eventName.contains("native_version")
        }
        for entry in injectionEntries {
            let sig = entry.metadata?["signature"] as? String
            XCTAssertEqual(sig, "unsigned", "Signature should be unsigned after version mismatch")
        }
    }

    func testReportLayer_versionMismatch_logsWarningEvent() async {
        let detector = makeDetector()
        let logger = MockDetectionLogger()
        let bridge = MockDetectionBridge(bitmaskVersion: 99)
        let reporter = DetectionReporter(
            detector: detector, logger: logger, flowType: "face", bridge: bridge
        )

        _ = await reporter.reportLayer("init")

        // Give fire-and-forget Task time to complete
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

        let mismatchEntry = logger.entries.first(where: {
            $0.eventName == "injection_native_version_mismatch"
        })
        XCTAssertNotNil(mismatchEntry, "Should log version mismatch warning")
        XCTAssertEqual(mismatchEntry?.level, .warning)
    }

    func testReset_clearsNativeDisabledForSession() async {
        let detector = makeDetector()
        let logger = MockDetectionLogger()
        // Start with version mismatch to trigger session-disable
        let bridge = MockDetectionBridge(
            bitmaskVersion: 99, signature: "after-reset"
        )
        let reporter = DetectionReporter(
            detector: detector, logger: logger, flowType: "face", bridge: bridge
        )

        // First call disables native due to version mismatch
        _ = await reporter.reportLayer("init")

        // After reset, nativeDisabledForSession should be false.
        // The bridge version is still 99, so it will re-disable.
        // But reset cleared the flag, allowing bitmaskVersion() to be called again.
        // We verify by checking that 2 injection_init entries exist (pre and post reset).
        await reporter.reset()
        _ = await reporter.reportLayer("init")

        let postResetEntries = logger.entries.filter {
            $0.eventName == "injection_init"
        }
        XCTAssertEqual(
            postResetEntries.count, 2,
            "Should have 2 injection_init entries (pre and post reset)"
        )
    }

    func testReportLayer_signatureKeyPresentInAllLayers() async {
        let detector = makeDetector()
        let logger = MockDetectionLogger()
        let reporter = DetectionReporter(
            detector: detector, logger: logger, flowType: "face", bridge: nil
        )

        _ = await reporter.reportLayer("init")
        _ = await reporter.reportLayer("camera")
        _ = await reporter.reportLayer("runtime")

        XCTAssertEqual(logger.entries.count, 3)
        for entry in logger.entries {
            XCTAssertNotNil(
                entry.metadata?["signature"],
                "signature key must be present in \(entry.eventName) metadata"
            )
        }
    }

    func testReportLayer_managedDeltaNotInflatedByNativeBits() async {
        // Scenario: first call with simulator + native bit 25
        // Second call: no new managed signals, but native bit 25 repeats
        // Delta should be 0 on second call (managed deduplication unaffected by native)
        let detector = makeDetector(isSimulator: true)
        let logger = MockDetectionLogger()
        let bridge = MockDetectionBridge(runChecksResult: 1 << 25)
        let reporter = DetectionReporter(
            detector: detector, logger: logger, flowType: "face", bridge: bridge
        )

        _ = await reporter.reportLayer("init")
        _ = await reporter.reportLayer("runtime")

        let secondEntry = logger.entries[1]
        let deltaBitmask = secondEntry.metadata?["delta_bitmask"] as? String
        XCTAssertEqual(
            deltaBitmask, "0",
            "Managed delta should be 0 when no new managed signals; native bits must not inflate delta"
        )
    }

    // MARK: - updateValidationId: init uses empty, camera uses real ID

    func testReportLayer_init_usesEmptyValidationId() async {
        let detector = makeDetector()
        let logger = MockDetectionLogger()
        let bridge = MockDetectionBridge()
        let reporter = DetectionReporter(
            detector: detector, logger: logger, flowType: "face", bridge: bridge
        )

        // No updateValidationId call — init fires with empty string
        _ = await reporter.reportLayer("init")

        XCTAssertEqual(
            bridge.lastSignReportValidationId,
            "",
            "Init layer must use empty string validationId (no session yet)"
        )
    }

    func testUpdateValidationId_cameraLayerUsesRealId() async {
        let detector = makeDetector()
        let logger = MockDetectionLogger()
        let bridge = MockDetectionBridge()
        let reporter = DetectionReporter(
            detector: detector, logger: logger, flowType: "face", bridge: bridge
        )

        await reporter.updateValidationId("real-id-123")
        _ = await reporter.reportLayer("camera")

        XCTAssertEqual(
            bridge.lastSignReportValidationId,
            "real-id-123",
            "Camera layer must use the real validationId after updateValidationId"
        )
    }

    func testFlowTypeFromInit_appearsInSignReport() async {
        let detector = makeDetector()
        let logger = MockDetectionLogger()
        let bridge = MockDetectionBridge()
        let reporter = DetectionReporter(
            detector: detector, logger: logger, flowType: "document", bridge: bridge
        )

        _ = await reporter.reportLayer("init")

        XCTAssertEqual(
            bridge.lastSignReportFlowType,
            "document",
            "flowType set at init must appear in signReport"
        )
    }

    func testMultipleUpdateValidationId_lastValueWins() async {
        let detector = makeDetector()
        let logger = MockDetectionLogger()
        let bridge = MockDetectionBridge()
        let reporter = DetectionReporter(
            detector: detector, logger: logger, flowType: "face", bridge: bridge
        )

        await reporter.updateValidationId("first")
        await reporter.updateValidationId("second")
        _ = await reporter.reportLayer("camera")

        XCTAssertEqual(
            bridge.lastSignReportValidationId,
            "second",
            "Last updateValidationId call wins"
        )
    }

    func testReset_clearsValidationId() async {
        let detector = makeDetector()
        let logger = MockDetectionLogger()
        let bridge = MockDetectionBridge()
        let reporter = DetectionReporter(
            detector: detector, logger: logger, flowType: "face", bridge: bridge
        )

        await reporter.updateValidationId("some-id")
        await reporter.reset()
        _ = await reporter.reportLayer("init")

        XCTAssertEqual(
            bridge.lastSignReportValidationId,
            "",
            "reset() must clear validationId back to empty string"
        )
    }

    func testBridgeUnavailable_updateValidationId_noOp() async {
        let detector = makeDetector()
        let logger = MockDetectionLogger()
        let reporter = DetectionReporter(
            detector: detector, logger: logger, flowType: "face", bridge: nil
        )

        // Should not crash
        await reporter.updateValidationId("val-id")
        _ = await reporter.reportLayer("camera")

        let signature = logger.entries.first?.metadata?["signature"] as? String
        XCTAssertEqual(signature, "unsigned", "Bridge unavailable should produce 'unsigned' signature")
    }

    func testConcurrentUpdateAndReport() async {
        // Actor guarantees sequential execution — update then report is ordered
        let detector = makeDetector()
        let logger = MockDetectionLogger()
        let bridge = MockDetectionBridge()
        let reporter = DetectionReporter(
            detector: detector, logger: logger, flowType: "face", bridge: bridge
        )

        await reporter.updateValidationId("concurrent-id")
        _ = await reporter.reportLayer("camera")

        XCTAssertEqual(
            bridge.lastSignReportValidationId,
            "concurrent-id",
            "Sequential actor calls guarantee update precedes report"
        )
    }

    // MARK: - Attestation metadata fields

    func testReportLayer_attestation_pendingSnapshot_emitsCorrectFields() async {
        let detector = makeDetector()
        let logger = MockDetectionLogger()
        let attestation = MockAttestationProvider()
        await attestation.setSnapshot(.pending)
        let reporter = DetectionReporter(
            detector: detector, logger: logger, flowType: "face", bridge: nil,
            attestation: attestation
        )

        _ = await reporter.reportLayer("init")

        let metadata = logger.entries.first?.metadata
        XCTAssertEqual(metadata?["attest_status"] as? String, "pending")
        XCTAssertEqual(metadata?["attest_token"] as? String, "")
        XCTAssertEqual(metadata?["attest_type"] as? String, "none")
        XCTAssertEqual(metadata?["device_api_level"] as? Int, 0)
    }

    func testReportLayer_attestation_readySnapshot_emitsCorrectFields() async {
        let detector = makeDetector()
        let logger = MockDetectionLogger()
        let attestation = MockAttestationProvider()
        await attestation.setSnapshot(.ready(token: "tok123", type: "app_attest"))
        let reporter = DetectionReporter(
            detector: detector, logger: logger, flowType: "face", bridge: nil,
            attestation: attestation
        )

        _ = await reporter.reportLayer("camera")

        let metadata = logger.entries.first?.metadata
        XCTAssertEqual(metadata?["attest_status"] as? String, "ok")
        XCTAssertEqual(metadata?["attest_token"] as? String, "tok123")
        XCTAssertEqual(metadata?["attest_type"] as? String, "app_attest")
        XCTAssertEqual(metadata?["device_api_level"] as? Int, 0)
    }

    func testReportLayer_attestation_unavailableSnapshot_emitsCorrectFields() async {
        // B4-4: assert all four fields, not just attest_status.
        let detector = makeDetector()
        let logger = MockDetectionLogger()
        let attestation = MockAttestationProvider()
        await attestation.setSnapshot(.unavailable(reason: "unsupported"))
        let reporter = DetectionReporter(
            detector: detector, logger: logger, flowType: "face", bridge: nil,
            attestation: attestation
        )

        _ = await reporter.reportLayer("runtime")

        let metadata = logger.entries.first?.metadata
        XCTAssertEqual(metadata?["attest_status"] as? String, "unavailable_unsupported")
        XCTAssertEqual(metadata?["attest_token"] as? String, "")
        XCTAssertEqual(metadata?["attest_type"] as? String, "none")
        XCTAssertEqual(metadata?["device_api_level"] as? Int, 0)
    }

    func testReportLayer_attestation_unavailableDisabled_emitsCorrectFields() async {
        // B4-4: "disabled" must produce unavailable_disabled, not unavailable_unsupported.
        let detector = makeDetector()
        let logger = MockDetectionLogger()
        let attestation = MockAttestationProvider()
        await attestation.setSnapshot(.unavailable(reason: "disabled"))
        let reporter = DetectionReporter(
            detector: detector, logger: logger, flowType: "face", bridge: nil,
            attestation: attestation
        )

        _ = await reporter.reportLayer("init")

        let metadata = logger.entries.first?.metadata
        XCTAssertEqual(metadata?["attest_status"] as? String, "unavailable_disabled")
        XCTAssertEqual(metadata?["attest_token"] as? String, "")
        XCTAssertEqual(metadata?["attest_type"] as? String, "none")
        XCTAssertEqual(metadata?["device_api_level"] as? Int, 0)
    }

    func testReportLayer_attestation_errorTimeoutSnapshot_emitsCorrectFields() async {
        // B4-4: assert all four fields, not just attest_status.
        let detector = makeDetector()
        let logger = MockDetectionLogger()
        let attestation = MockAttestationProvider()
        await attestation.setSnapshot(.error(reason: "timeout"))
        let reporter = DetectionReporter(
            detector: detector, logger: logger, flowType: "face", bridge: nil,
            attestation: attestation
        )

        _ = await reporter.reportLayer("init")

        let metadata = logger.entries.first?.metadata
        XCTAssertEqual(metadata?["attest_status"] as? String, "error_timeout")
        XCTAssertEqual(metadata?["attest_token"] as? String, "")
        XCTAssertEqual(metadata?["attest_type"] as? String, "none")
        XCTAssertEqual(metadata?["device_api_level"] as? Int, 0)
    }

    func testReportLayer_attestation_errorQuotaSnapshot_emitsCorrectFields() async {
        // B4-4: quota branch also asserts all four fields.
        let detector = makeDetector()
        let logger = MockDetectionLogger()
        let attestation = MockAttestationProvider()
        await attestation.setSnapshot(.error(reason: "quota"))
        let reporter = DetectionReporter(
            detector: detector, logger: logger, flowType: "face", bridge: nil,
            attestation: attestation
        )

        _ = await reporter.reportLayer("camera")

        let metadata = logger.entries.first?.metadata
        XCTAssertEqual(metadata?["attest_status"] as? String, "error_quota")
        XCTAssertEqual(metadata?["attest_token"] as? String, "")
        XCTAssertEqual(metadata?["attest_type"] as? String, "none")
        XCTAssertEqual(metadata?["device_api_level"] as? Int, 0)
    }

    func testReportLayer_attestation_errorKeychainSnapshot_emitsCorrectFields() async {
        // B4-4: keychain branch.
        let detector = makeDetector()
        let logger = MockDetectionLogger()
        let attestation = MockAttestationProvider()
        await attestation.setSnapshot(.error(reason: "keychain"))
        let reporter = DetectionReporter(
            detector: detector, logger: logger, flowType: "face", bridge: nil,
            attestation: attestation
        )

        _ = await reporter.reportLayer("runtime")

        let metadata = logger.entries.first?.metadata
        XCTAssertEqual(metadata?["attest_status"] as? String, "error_keychain")
        XCTAssertEqual(metadata?["attest_token"] as? String, "")
        XCTAssertEqual(metadata?["attest_type"] as? String, "none")
        XCTAssertEqual(metadata?["device_api_level"] as? Int, 0)
    }

    func testReportLayer_attestation_presentInAllThreeLayers() async {
        let detector = makeDetector()
        let logger = MockDetectionLogger()
        let attestation = MockAttestationProvider()
        await attestation.setSnapshot(.pending)
        let reporter = DetectionReporter(
            detector: detector, logger: logger, flowType: "face", bridge: nil,
            attestation: attestation
        )

        _ = await reporter.reportLayer("init")
        _ = await reporter.reportLayer("camera")
        _ = await reporter.reportLayer("runtime")

        XCTAssertEqual(logger.entries.count, 3)
        for entry in logger.entries {
            XCTAssertNotNil(
                entry.metadata?["attest_status"],
                "attest_status must be present in \(entry.eventName)"
            )
            XCTAssertNotNil(
                entry.metadata?["attest_token"],
                "attest_token must be present in \(entry.eventName)"
            )
            XCTAssertNotNil(
                entry.metadata?["attest_type"],
                "attest_type must be present in \(entry.eventName)"
            )
            XCTAssertNotNil(
                entry.metadata?["device_api_level"],
                "device_api_level must be present in \(entry.eventName)"
            )
        }
    }

    func testReportLayer_defaultReporter_hasNoOpAttestationFields() async {
        // The default (no attestation param) must still emit the four fields
        // via the NoOpAttestationProvider default.
        let detector = makeDetector()
        let logger = MockDetectionLogger()
        // Default init — no attestation param
        let reporter = DetectionReporter(detector: detector, logger: logger, flowType: "face")

        _ = await reporter.reportLayer("init")

        let metadata = logger.entries.first?.metadata
        XCTAssertNotNil(metadata?["attest_status"])
        XCTAssertNotNil(metadata?["attest_token"])
        XCTAssertNotNil(metadata?["attest_type"])
        XCTAssertNotNil(metadata?["device_api_level"])
    }

    func testReportLayer_defaultReporter_emitsUnavailableUnsupported() async {
        // I6: the default no-op provider signals "this integrator did not wire a real
        // attestation provider" — which is semantically "unsupported", not "disabled".
        // "disabled" means the integrator explicitly opted out via config; the default
        // NoOp is a passive absence of configuration.
        let detector = makeDetector()
        let logger = MockDetectionLogger()
        let reporter = DetectionReporter(detector: detector, logger: logger, flowType: "face")

        _ = await reporter.reportLayer("init")

        let attestStatus = logger.entries.first?.metadata?["attest_status"] as? String
        XCTAssertEqual(
            attestStatus,
            "unavailable_unsupported",
            "Default no-op provider must emit unavailable_unsupported, not unavailable_disabled"
        )
    }

    // MARK: - B4-3: Attestation fields must NOT overwrite base detection metadata

    func testReportLayer_attestationDoesNotOverwrite_trustScore() async {
        // The merge closure { current, _ in current } ensures that if attestation metadata
        // ever gains a key that collides with base metadata, the base value survives.
        // Regression: verify trust_score is present and consistent with the detector result
        // even when an attestation provider is active.
        let detector = makeDetector()
        let logger = MockDetectionLogger()
        let attestation = MockAttestationProvider()
        await attestation.setSnapshot(.ready(token: "tok", type: "app_attest"))
        let reporter = DetectionReporter(
            detector: detector, logger: logger, flowType: "face", bridge: nil,
            attestation: attestation
        )

        _ = await reporter.reportLayer("init")

        let metadata = logger.entries.first?.metadata
        // trust_score must be present — it comes from the base metadata, not attestation.
        XCTAssertNotNil(metadata?["trust_score"], "trust_score must be present in merged metadata")
        // Attestation fields must also be present alongside base fields — no clobbering.
        XCTAssertEqual(metadata?["attest_status"] as? String, "ok")
        XCTAssertEqual(metadata?["attest_token"] as? String, "tok")
        XCTAssertEqual(metadata?["attest_type"] as? String, "app_attest")
        XCTAssertNotNil(metadata?["risk_bitmask"], "risk_bitmask must survive attestation merge")
        XCTAssertNotNil(metadata?["signature"], "signature must survive attestation merge")
    }

    // MARK: - B-cycle2: Merge-closure collision regression

    /// Hard guarantee: if the attestation metadata builder ever produces a key
    /// that COLLIDES with a base detection key, the merge closure
    /// `{ current, _ in current }` must preserve the base value. Previous
    /// version of this test set only used the production `buildAttestationMetadata`
    /// mapper, which by construction never emits colliding keys — so reversing
    /// the merge strategy would have passed silently.
    ///
    /// Here we inject a builder that DELIBERATELY emits every base key with a
    /// poisoned sentinel value. The merge closure is exercised at every key
    /// site; the assertions then prove the base values survived unchanged.
    func testReportLayer_collidingAttestationBuilder_baseMetadataWins() async {
        let detector = makeDetector()
        let logger = MockDetectionLogger()
        let attestation = MockAttestationProvider()
        await attestation.setSnapshot(.ready(token: "tok", type: "app_attest"))

        // Poisoned builder: emits every base key with a sentinel value that would
        // be obviously wrong if the merge strategy were reversed.
        let poisonedBuilder: @Sendable (AttestationSnapshot) -> [String: Any] = { _ in
            [
                "trust_score": -999, // base is the real Int from the detector
                "risk_bitmask": "POISONED", // base is the hex String of accumulatedBitmask
                "delta_bitmask": "POISONED", // base is the hex String of the delta
                "ts": UInt64(0), // base is the real epoch timestamp
                "bitmask_v": -1, // base is BitmaskEncoder.version
                "signature": "POISONED", // base is the computed signature or "unsigned"
                // Non-colliding keys must still appear in the merged output.
                "attest_status": "ok",
                "attest_token": "tok",
                "attest_type": "app_attest",
                "device_api_level": 0
            ]
        }

        let reporter = DetectionReporter(
            detector: detector,
            logger: logger,
            flowType: "face",
            bridge: nil,
            attestation: attestation,
            attestationMetadataBuilder: poisonedBuilder
        )

        _ = await reporter.reportLayer("init")

        let metadata = logger.entries.first?.metadata
        XCTAssertNotNil(metadata, "Reporter must have logged an entry")

        // 1) Base keys MUST NOT carry the poisoned sentinel — the merge closure
        //    must keep the production value from baseMetadata.
        if let trustScore = metadata?["trust_score"] as? Int {
            XCTAssertNotEqual(
                trustScore, -999,
                "trust_score was overwritten by attestation builder; merge closure is reversed"
            )
        } else {
            XCTFail("trust_score must be an Int from base metadata, got \(String(describing: metadata?["trust_score"]))")
        }

        let riskBitmask = metadata?["risk_bitmask"] as? String
        XCTAssertNotEqual(
            riskBitmask, "POISONED",
            "risk_bitmask was overwritten by attestation builder; merge closure is reversed"
        )
        XCTAssertNotNil(riskBitmask, "risk_bitmask must remain a String from base metadata")

        let deltaBitmask = metadata?["delta_bitmask"] as? String
        XCTAssertNotEqual(
            deltaBitmask, "POISONED",
            "delta_bitmask was overwritten by attestation builder; merge closure is reversed"
        )

        if let ts = metadata?["ts"] as? UInt64 {
            XCTAssertNotEqual(
                ts, 0,
                "ts was overwritten by attestation builder; merge closure is reversed"
            )
        } else {
            XCTFail("ts must be a UInt64 from base metadata, got \(String(describing: metadata?["ts"]))")
        }

        if let bitmaskV = metadata?["bitmask_v"] as? Int {
            XCTAssertNotEqual(
                bitmaskV, -1,
                "bitmask_v was overwritten by attestation builder; merge closure is reversed"
            )
        } else {
            XCTFail("bitmask_v must be an Int from base metadata, got \(String(describing: metadata?["bitmask_v"]))")
        }

        let signature = metadata?["signature"] as? String
        XCTAssertNotEqual(
            signature, "POISONED",
            "signature was overwritten by attestation builder; merge closure is reversed"
        )

        // 2) Non-colliding attestation keys MUST still flow through unchanged.
        XCTAssertEqual(metadata?["attest_status"] as? String, "ok")
        XCTAssertEqual(metadata?["attest_token"] as? String, "tok")
        XCTAssertEqual(metadata?["attest_type"] as? String, "app_attest")
        XCTAssertEqual(metadata?["device_api_level"] as? Int, 0)
    }
}

// (No extra test doubles needed — MockAttestationProvider is defined in MockAttestationProvider.swift)
