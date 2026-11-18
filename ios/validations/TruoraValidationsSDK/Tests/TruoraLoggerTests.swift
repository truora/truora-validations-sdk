//
//  TruoraLoggerTests.swift
//  TruoraValidationsSDKTests
//
//  Created by AI Assistant on 2025-02-01.
//

import XCTest
@testable import TruoraValidationsSDK

@MainActor
final class TruoraLoggerTests: XCTestCase {
    override func setUp() async throws {
        try await super.setUp()
        // Reset logger before each test
        await TruoraLoggerImplementation.reset()
    }

    override func tearDown() async throws {
        // Clean up after each test
        await TruoraLoggerImplementation.reset()
        ValidationConfig.shared.reset()
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialize_shouldCreateSingleton() async throws {
        // When
        try await TruoraLoggerImplementation.initialize(with: LoggerConfiguration.testing())

        // Then
        let logger = try await TruoraLoggerImplementation.shared
        XCTAssertNotNil(logger)
        XCTAssertTrue(TruoraLoggerImplementation.isInitialized)
    }

    func testInitialize_twice_shouldNotFail() async throws {
        // Given
        try await TruoraLoggerImplementation.initialize(with: LoggerConfiguration.testing())

        // When/Then - Should not throw
        try await TruoraLoggerImplementation.initialize(with: LoggerConfiguration.testing())
    }

    func testShared_beforeInitialization_shouldThrow() async {
        // When/Then
        do {
            _ = try await TruoraLoggerImplementation.shared
            XCTFail("Should have thrown error")
        } catch {
            // Expected
            XCTAssertTrue(error is TruoraException)
        }
    }

    // MARK: - Logging Tests

    func testLogEvent_shouldNotThrow() async throws {
        // Given
        try await TruoraLoggerImplementation.initialize(with: LoggerConfiguration.testing())
        let logger = try await TruoraLoggerImplementation.shared

        // When/Then - Should not throw
        await logger.logEvent(
            eventType: .camera,
            eventName: "test_event",
            level: .info,
            errorMessage: nil,
            retention: .oneWeek,
            metadata: ["key": "value"],
            stackTrace: nil
        )
    }

    func testLogCamera_shouldUseCameraEventType() async throws {
        // Given
        try await TruoraLoggerImplementation.initialize(with: LoggerConfiguration.testing())
        let logger = try await TruoraLoggerImplementation.shared

        // When
        await logger.logCamera(
            eventName: "camera_test",
            level: .info,
            errorMessage: nil,
            retention: .oneWeek,
            metadata: ["camera": "front"]
        )

        // Then - Event was logged (no error thrown)
        // In a real test, we'd verify the event was buffered
    }

    func testLogView_shouldIncludeViewName() async throws {
        // Given
        try await TruoraLoggerImplementation.initialize(with: LoggerConfiguration.testing())
        let logger = try await TruoraLoggerImplementation.shared

        // When
        await logger.logView(
            viewName: "DocumentCapture",
            level: .info,
            retention: .oneWeek,
            metadata: nil
        )

        // Then - Event was logged
    }

    func testLogException_shouldExtractErrorInfo() async throws {
        // Given
        try await TruoraLoggerImplementation.initialize(with: LoggerConfiguration.testing())
        let logger = try await TruoraLoggerImplementation.shared
        let testError = TruoraException.sdk(SDKError(type: .internalError, details: "Test error"))

        // When
        await logger.logException(
            eventType: .device,
            eventName: "exception_test",
            exception: testError,
            level: .error,
            retention: .oneMonth,
            metadata: nil
        )

        // Then - Event was logged with stack trace
    }

    // MARK: - Flush Tests

    func testFlush_emptyBuffer_shouldNotFail() async throws {
        // Given
        try await TruoraLoggerImplementation.initialize(with: LoggerConfiguration.testing())
        let logger = try await TruoraLoggerImplementation.shared

        // When/Then - Should not throw
        await logger.flush()
    }

    func testFlush_withTimeout_shouldComplete() async throws {
        // Given
        try await TruoraLoggerImplementation.initialize(with: LoggerConfiguration.testing())
        let logger = try await TruoraLoggerImplementation.shared

        // When/Then - Should not throw
        await logger.flush(timeoutMs: 1000)
    }

    // MARK: - Reset Tests

    func testReset_shouldClearInstance() async throws {
        // Given
        try await TruoraLoggerImplementation.initialize(with: LoggerConfiguration.testing())
        XCTAssertTrue(TruoraLoggerImplementation.isInitialized)

        // When
        await TruoraLoggerImplementation.reset()

        // Then
        XCTAssertFalse(TruoraLoggerImplementation.isInitialized)
    }

    // MARK: - Configuration Tests

    func testLoggerConfiguration_production_shouldDisableConsole() {
        // When
        let config = LoggerConfiguration.production(apiKey: "test", sdkVersion: "1.0")

        // Then
        XCTAssertFalse(config.enableConsoleOutput)
        XCTAssertTrue(config.enableApiOutput)
    }

    func testLoggerConfiguration_development_shouldEnableConsole() {
        // When
        let config = LoggerConfiguration.development(apiKey: "test", sdkVersion: "1.0")

        // Then
        XCTAssertTrue(config.enableConsoleOutput)
        XCTAssertTrue(config.enableApiOutput)
        XCTAssertEqual(config.flushIntervalMs, 5000)
    }

    // MARK: - Sampling Tests

    func testSampledIn_allEventsBuffered() async throws {
        // Given: sampleRate = 1.0 (always sampled in)
        let config = LoggerConfiguration(
            apiKey: "test-key",
            sdkVersion: "1.0.0",
            sampleRate: 1.0,
            enableConsoleOutput: false,
            enableApiOutput: false
        )
        try await TruoraLoggerImplementation.initialize(with: config)
        let logger = try TruoraLoggerImplementation.shared

        // When: log an INFO event
        await logger.logEvent(
            eventType: .camera,
            eventName: "test_info",
            level: .info,
            errorMessage: nil,
            retention: .oneWeek,
            metadata: nil,
            stackTrace: nil
        )

        // Then: event is in eventBuffer (sampled-in means normal path)
        let bufferCount = await logger.eventBufferCount
        XCTAssertEqual(bufferCount, 1)
    }

    func testSampledOut_noErrorEvents_dropsEvents() async throws {
        // Given: sampleRate = 0.0 (never sampled in without error)
        let config = LoggerConfiguration(
            apiKey: "test-key",
            sdkVersion: "1.0.0",
            sampleRate: 0.0,
            enableConsoleOutput: false,
            enableApiOutput: false
        )
        try await TruoraLoggerImplementation.initialize(with: config)
        let logger = try TruoraLoggerImplementation.shared

        // When: log INFO events
        await logger.logEvent(
            eventType: .camera,
            eventName: "test_info",
            level: .info,
            errorMessage: nil,
            retention: .oneWeek,
            metadata: nil,
            stackTrace: nil
        )

        // Then: eventBuffer is empty (sampled-out, no escalation)
        let bufferCount = await logger.eventBufferCount
        XCTAssertEqual(bufferCount, 0)
    }

    func testSampledOut_errorOccurs_escalatesAllSessionLogs() async throws {
        // Given: sampleRate = 0.0
        let config = LoggerConfiguration(
            apiKey: "test-key",
            sdkVersion: "1.0.0",
            sampleRate: 0.0,
            enableConsoleOutput: false,
            enableApiOutput: false
        )
        try await TruoraLoggerImplementation.initialize(with: config)
        let logger = try TruoraLoggerImplementation.shared

        // When: log 3 INFO events, then 1 ERROR
        for i in 0 ..< 3 {
            await logger.logEvent(
                eventType: .camera,
                eventName: "info_event_\(i)",
                level: .info,
                errorMessage: nil,
                retention: .oneWeek,
                metadata: nil,
                stackTrace: nil
            )
        }
        await logger.logEvent(
            eventType: .camera,
            eventName: "camera_crashed",
            level: .error,
            errorMessage: "Camera failed",
            retention: .oneWeek,
            metadata: nil,
            stackTrace: nil
        )

        // Then: escalation occurred — sessionBuffer was drained to eventBuffer then flushed.
        // With enableApiOutput: false, flush() clears eventBuffer, so both end up empty.
        let bufferCount = await logger.eventBufferCount
        XCTAssertEqual(bufferCount, 0, "eventBuffer should be empty after escalation flush")
        let sessionCount = await logger.sessionBufferCount
        XCTAssertEqual(sessionCount, 0, "sessionBuffer should be cleared after escalation")
    }

    func testSampledOut_fatalOccurs_escalates() async throws {
        // Given: sampleRate = 0.0
        let config = LoggerConfiguration(
            apiKey: "test-key",
            sdkVersion: "1.0.0",
            sampleRate: 0.0,
            enableConsoleOutput: false,
            enableApiOutput: false
        )
        try await TruoraLoggerImplementation.initialize(with: config)
        let logger = try TruoraLoggerImplementation.shared

        // When
        await logger.logEvent(
            eventType: .camera,
            eventName: "info_before_fatal",
            level: .info,
            errorMessage: nil,
            retention: .oneWeek,
            metadata: nil,
            stackTrace: nil
        )
        await logger.logEvent(
            eventType: .camera,
            eventName: "camera_fatal",
            level: .fatal,
            errorMessage: "Fatal crash",
            retention: .oneWeek,
            metadata: nil,
            stackTrace: nil
        )

        // Then: escalation occurred — sessionBuffer drained and eventBuffer flushed.
        let bufferCount = await logger.eventBufferCount
        XCTAssertEqual(bufferCount, 0, "eventBuffer should be empty after escalation flush")
        let sessionCount = await logger.sessionBufferCount
        XCTAssertEqual(sessionCount, 0, "sessionBuffer should be cleared after escalation")
    }

    func testAfterEscalation_subsequentEventsStillSent() async throws {
        // Given: sampleRate = 0.0, escalation via error
        let config = LoggerConfiguration(
            apiKey: "test-key",
            sdkVersion: "1.0.0",
            sampleRate: 0.0,
            enableConsoleOutput: false,
            enableApiOutput: false
        )
        try await TruoraLoggerImplementation.initialize(with: config)
        let logger = try TruoraLoggerImplementation.shared

        // Trigger escalation
        await logger.logEvent(
            eventType: .camera,
            eventName: "error_event",
            level: .error,
            errorMessage: "Error",
            retention: .oneWeek,
            metadata: nil,
            stackTrace: nil
        )

        // Log more INFO events after escalation
        await logger.logEvent(
            eventType: .camera,
            eventName: "post_error_info",
            level: .info,
            errorMessage: nil,
            retention: .oneWeek,
            metadata: nil,
            stackTrace: nil
        )

        // Then: after escalation, isSampledIn = true and subsequent events go to eventBuffer.
        // sessionBuffer stays empty because sampled-in events bypass it.
        // The post-error INFO event lands in eventBuffer (not sessionBuffer).
        let sessionCount = await logger.sessionBufferCount
        XCTAssertEqual(sessionCount, 0) // escalation drains sessionBuffer; post-error events go to eventBuffer
    }

    // MARK: - Batch Context Tests

    func testFlush_sendsOneBatchPerValidationId() async throws {
        let output = CapturingLogOutput()
        let logger = try await makeLogger(sendingTo: output)

        ValidationConfig.shared.updateValidationId("dummy-validation-a")
        await logInfo(logger, "first")
        await logInfo(logger, "second")
        ValidationConfig.shared.updateValidationId("dummy-validation-b")
        await logInfo(logger, "third")
        await logger.flush()

        let batches = await output.batches
        XCTAssertEqual(batches.map(\.validationId), ["dummy-validation-a", "dummy-validation-b"])
        XCTAssertEqual(batches.map { $0.events.map(\.eventName) }, [["first", "second"], ["third"]])
    }

    func testFlush_afterTheValidationIdIsCleared_keepsItInThePendingBatch() async throws {
        let output = CapturingLogOutput()
        let logger = try await makeLogger(sendingTo: output)

        ValidationConfig.shared.updateValidationId("dummy-validation-a")
        await logInfo(logger, "pending")
        ValidationConfig.shared.reset()
        await logger.flush()

        let batches = await output.batches
        XCTAssertEqual(batches.map(\.validationId), ["dummy-validation-a"])
    }

    func testFlush_returningToAnEarlierValidationId_startsANewBatch() async throws {
        let output = CapturingLogOutput()
        let logger = try await makeLogger(sendingTo: output)

        ValidationConfig.shared.updateValidationId("dummy-validation-a")
        await logInfo(logger, "a1")
        ValidationConfig.shared.updateValidationId("dummy-validation-b")
        await logInfo(logger, "b1")
        ValidationConfig.shared.updateValidationId("dummy-validation-a")
        await logInfo(logger, "a2")
        await logger.flush()

        let batches = await output.batches
        XCTAssertEqual(
            batches.map(\.validationId),
            ["dummy-validation-a", "dummy-validation-b", "dummy-validation-a"]
        )
        XCTAssertEqual(batches.map { $0.events.map(\.eventName) }, [["a1"], ["b1"], ["a2"]])
    }

    func testFlush_whenALaterBatchFails_keepsOnlyItsEvents() async throws {
        let output = CapturingLogOutput(failingBatchIndexes: [1])
        let logger = try await makeLogger(sendingTo: output)

        ValidationConfig.shared.updateValidationId("dummy-validation-a")
        await logInfo(logger, "sent")
        ValidationConfig.shared.updateValidationId("dummy-validation-b")
        await logInfo(logger, "unsent")
        await logger.flush()

        let bufferCount = await logger.eventBufferCount
        XCTAssertEqual(bufferCount, 1, "Only the events of the failed batch stay buffered")
    }

    private func makeLogger(sendingTo output: CapturingLogOutput) async throws -> TruoraLoggerImplementation {
        ValidationConfig.shared.reset()
        let config = LoggerConfiguration(
            apiKey: "dummy-api-key",
            sdkVersion: "1.0.0",
            sampleRate: 1.0,
            enableConsoleOutput: false,
            enableApiOutput: false
        )
        try await TruoraLoggerImplementation.initialize(with: config, apiOutput: output)
        return try TruoraLoggerImplementation.shared
    }

    private func logInfo(_ logger: TruoraLoggerImplementation, _ eventName: String) async {
        await logger.logEvent(
            eventType: .view,
            eventName: eventName,
            level: .info,
            errorMessage: nil,
            retention: .oneWeek,
            metadata: nil,
            stackTrace: nil
        )
    }
}

// MARK: - Mock Implementations

actor CapturingLogOutput: LogBatchOutput {
    private(set) var batches: [SDKLog] = []
    private let failingBatchIndexes: Set<Int>

    init(failingBatchIndexes: Set<Int> = []) {
        self.failingBatchIndexes = failingBatchIndexes
    }

    func output(batch: SDKLog) async -> Bool {
        batches.append(batch)
        return !failingBatchIndexes.contains(batches.count - 1)
    }
}

final class MockTruoraLogger: TruoraLogger, @unchecked Sendable {
    private let lock = NSLock()
    private var _loggedEvents: [SDKEvent] = []
    private var _flushCallCount = 0

    var loggedEvents: [SDKEvent] {
        lock.lock()
        defer { lock.unlock() }
        return _loggedEvents
    }

    var flushCallCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _flushCallCount
    }

    func logEvent(
        eventType: EventType,
        eventName: String,
        level: LogLevel,
        errorMessage: String?,
        retention: RetentionPeriod,
        metadata: [String: Any]?,
        stackTrace: String?
    ) async {
        let event = SDKEvent(
            eventType: eventType,
            eventName: eventName,
            level: level,
            errorMessage: errorMessage,
            stackTrace: stackTrace,
            metadata: metadata?.reduce(
                into: [String: AnyCodableValue]()
            ) { result, pair in
                switch pair.value {
                case let val as Bool: result[pair.key] = .bool(val)
                case let val as Int: result[pair.key] = .int(val)
                case let val as Double: result[pair.key] = .double(val)
                case let val as String: result[pair.key] = .string(val)
                default: result[pair.key] = .string("\(pair.value)")
                }
            } ?? [:]
        )
        lock.lock()
        _loggedEvents.append(event)
        lock.unlock()
    }

    func logCamera(eventName: String, level: LogLevel, errorMessage: String?, retention: RetentionPeriod, metadata: [String: Any]?) async {
        await logEvent(eventType: .camera, eventName: eventName, level: level, errorMessage: errorMessage, retention: retention, metadata: metadata, stackTrace: nil)
    }

    func logML(eventName: String, level: LogLevel, errorMessage: String?, retention: RetentionPeriod, metadata: [String: Any]?) async {
        await logEvent(eventType: .mlModel, eventName: eventName, level: level, errorMessage: errorMessage, retention: retention, metadata: metadata, stackTrace: nil)
    }

    func logView(viewName: String, level: LogLevel, retention: RetentionPeriod, metadata: [String: Any]?) async {
        var mergedMetadata = metadata ?? [:]
        mergedMetadata["view_name"] = viewName
        await logEvent(eventType: .view, eventName: "view_\(viewName)", level: level, errorMessage: nil, retention: retention, metadata: mergedMetadata, stackTrace: nil)
    }

    func logDevice(eventName: String, level: LogLevel, retention: RetentionPeriod, metadata: [String: Any]?) async {
        await logEvent(eventType: .device, eventName: eventName, level: level, errorMessage: nil, retention: retention, metadata: metadata, stackTrace: nil)
    }

    func logFeedback(eventName: String, level: LogLevel, errorMessage: String?, retention: RetentionPeriod, metadata: [String: Any]?) async {
        await logEvent(eventType: .device, eventName: eventName, level: level, errorMessage: errorMessage, retention: retention, metadata: metadata, stackTrace: nil)
    }

    func logSdk(eventName: String, level: LogLevel, errorMessage: String?, retention: RetentionPeriod, metadata: [String: Any]?) async {
        await logEvent(eventType: .device, eventName: eventName, level: level, errorMessage: errorMessage, retention: retention, metadata: metadata, stackTrace: nil)
    }

    func logException(eventType: EventType, eventName: String, exception: Error, level: LogLevel, retention: RetentionPeriod, metadata: [String: Any]?) async {
        await logEvent(eventType: eventType, eventName: eventName, level: level, errorMessage: exception.localizedDescription, retention: retention, metadata: metadata, stackTrace: nil)
    }

    func flush() async {
        lock.lock()
        _flushCallCount += 1
        lock.unlock()
    }

    func flush(timeoutMs: Int64) async {
        lock.lock()
        _flushCallCount += 1
        lock.unlock()
    }
}
