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
}
