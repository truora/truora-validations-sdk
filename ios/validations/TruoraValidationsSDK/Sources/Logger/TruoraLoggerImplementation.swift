//
//  TruoraLoggerImplementation.swift
//  TruoraValidationsSDK
//
//  Created by AI Assistant on 2025-02-01.
//

import Foundation
import UIKit

/// Actor-based logger implementation for iOS.
///
/// This implementation follows Sentry's patterns for reliability:
/// - Events are buffered in memory and flushed periodically
/// - Events may be lost if the app is killed before flush completes
/// - Thread-safe via actor isolation
/// - Integrates with app lifecycle for automatic flushing
public actor TruoraLoggerImplementation: TruoraLogger { // swiftlint:disable:this type_body_length
    // MARK: - Singleton Pattern

    private static let lock = NSLock()
    private static var _instance: TruoraLoggerImplementation?
    private static var initializationError: Error?

    /// Initialize the singleton logger instance.
    /// Must be called before using `shared`.
    ///
    /// - Parameter config: Logger configuration
    /// - Throws: TruoraException if initialization fails
    public static func initialize(with config: LoggerConfiguration) async throws {
        try await initialize(with: config, apiOutput: nil)
    }

    /// Initializes the logger with `apiOutput` in place of the configured Truora endpoint.
    static func initialize(with config: LoggerConfiguration, apiOutput: LogBatchOutput?) async throws {
        var shouldInitialize = false
        lock.withLock {
            guard _instance == nil, initializationError == nil else {
                return // Already initialized or failed
            }
            shouldInitialize = true
        }

        // Initialize outside the lock to avoid issues with async/await
        if shouldInitialize {
            let instance = TruoraLoggerImplementation(config: config, apiOutput: apiOutput)
            await instance.initializeAfterActorReady()

            lock.withLock {
                _instance = instance
            }
        }
    }

    /// Get the singleton logger instance.
    ///
    /// - Throws: TruoraException if not initialized
    /// - Returns: The shared logger instance
    public static var shared: TruoraLoggerImplementation {
        get throws {
            try lock.withLock {
                guard let instance = _instance else {
                    let baseMessage = "TruoraLogger not initialized"
                    let message = initializationError.map { "\(baseMessage). Previous initialization failed: \($0)" }
                        ?? baseMessage
                    throw TruoraException.sdk(SDKError(type: .internalError, details: message))
                }
                return instance
            }
        }
    }

    /// Check if the logger has been initialized.
    public static var isInitialized: Bool {
        lock.withLock { _instance != nil }
    }

    // MARK: - Test Support

    /// Returns the current count of events in the regular event buffer.
    /// Internal visibility for testing only.
    var eventBufferCount: Int {
        eventBuffer.count
    }

    /// Internal visibility for testing only.
    var bufferedEvents: [SDKEvent] {
        eventBuffer.map(\.event)
    }

    /// Returns the current count of events in the session buffer.
    /// Internal visibility for testing only.
    var sessionBufferCount: Int {
        sessionBuffer.count
    }

    /// Initialize for testing with minimal configuration.
    /// Safe to call multiple times - only initializes once.
    public static func initializeForTesting() async throws {
        if !isInitialized, initializationError == nil {
            try await initialize(with: LoggerConfiguration.testing())
        }
    }

    /// Reset the singleton for testing.
    /// Cancels any pending operations and clears the instance.
    public static func reset() async {
        var instanceToShutdown: TruoraLoggerImplementation?
        lock.withLock {
            instanceToShutdown = _instance
            _instance = nil
            initializationError = nil
        }
        // Shutdown outside the lock to avoid async/await issues
        if let instance = instanceToShutdown {
            await instance.shutdown()
        }
    }

    // MARK: - Properties

    private let config: LoggerConfiguration
    private let initializationTime = Date()
    /// Lazy device info - computed on MainActor when first accessed
    @MainActor
    private lazy var deviceInfo: DeviceInfo = .init(
        model: UIDevice.current.model,
        osVersion: UIDevice.current.systemVersion
    )

    private var eventBuffer: [PendingEvent] = []
    private var nextEventSequence = 0
    private var flushTask: Task<Void, Never>?

    // MARK: - Sampling

    /// Whether this session was selected for full logging at initialization time.
    /// Set once at init; may be promoted to true on error escalation.
    private var isSampledIn: Bool = true

    /// Holds all events for the current session in sampled-out sessions.
    /// Drained to eventBuffer on escalation (first ERROR/FATAL event).
    /// Capped at maxSessionBufferSize to bound memory usage.
    private var sessionBuffer: [PendingEvent] = []
    private let maxSessionBufferSize = 500
    private var notificationObservers: [NSObjectProtocol] = []
    private let consoleOutput: ConsoleLogOutput
    private let apiOutput: LogBatchOutput?

    // Flush management
    private var flushFailureCount = 0
    private var lastFlushAttemptTime: Date?
    private static let maxConsecutiveFailures = 10

    private struct DeviceInfo {
        let model: String
        let osVersion: String
    }

    // MARK: - Initialization

    private init(config: LoggerConfiguration, apiOutput: LogBatchOutput?) {
        self.config = config
        self.consoleOutput = ConsoleLogOutput()

        if let apiOutput {
            self.apiOutput = apiOutput
        } else if config.enableApiOutput {
            self.apiOutput = APILogOutput(
                apiKey: config.apiKey,
                endpoint: config.loggingEndpoint,
                sdkVersion: config.sdkVersion
            )
        } else {
            self.apiOutput = nil
        }

        self.isSampledIn = config.sampleRate >= 1.0 || Double.random(in: 0 ..< 1) < config.sampleRate
    }

    /// Initialize lifecycle observers after actor is fully initialized
    /// Must be called separately from init to avoid Swift 6 concurrency issues
    private func initializeAfterActorReady() {
        setupLifecycleObservers()
        startFlushTimer()
    }

    // MARK: - Lifecycle Observation

    private func setupLifecycleObservers() {
        let center = NotificationCenter.default

        // App entering background - flush immediately
        let backgroundObserver = center.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { [weak self] in
                await self?.flush()
            }
        }

        // App terminating - final flush attempt
        let terminationObserver = center.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { [weak self] in
                await self?.flush(timeoutMs: 5000)
            }
        }

        notificationObservers = [backgroundObserver, terminationObserver]
    }

    // MARK: - Timer Management

    private func startFlushTimer() {
        flushTask?.cancel()
        // No need to await flushTask value as it's void and we just want to start a new one

        flushTask = Task { [weak self] in
            while !Task.isCancelled {
                // Sleep for the flush interval
                if let interval = self?.config.flushIntervalMs {
                    try? await Task.sleep(nanoseconds: UInt64(interval) * 1_000_000)

                } else {
                    // Fallback or exit if self is nil
                    return
                }

                guard !Task.isCancelled else { break }

                await self?.flush()
            }
        }
    }

    // MARK: - TruoraLogger Protocol Implementation

    public func logEvent(
        eventType: EventType,
        eventName: String,
        level: LogLevel,
        errorMessage: String?,
        retention: RetentionPeriod,
        metadata: [String: Any]?,
        stackTrace: String?
    ) async {
        let durationMs = Int64(Date().timeIntervalSince(initializationTime) * 1000)
        let context = await getValidationContext()
        let mergedMetadata = buildMergedMetadata(context: context, eventMetadata: metadata)

        let event = SDKEvent(
            eventType: eventType,
            eventName: eventName,
            level: level,
            errorMessage: errorMessage,
            durationMs: durationMs,
            stackTrace: stackTrace,
            metadata: mergedMetadata
        )

        let pending = PendingEvent(sequence: nextEventSequence, event: event, context: context)
        nextEventSequence += 1

        if isSampledIn {
            // Sampled-in: normal path — add to event buffer
            eventBuffer.append(pending)

            if config.enableConsoleOutput {
                await consoleOutput.output(event: event)
            }

            if eventBuffer.count >= config.maxBufferSize {
                await flush()
            }
            return
        }

        // Sampled-out: maintain session buffer (ring buffer, bounded at maxSessionBufferSize)
        if sessionBuffer.count >= maxSessionBufferSize {
            sessionBuffer.removeFirst()
        }
        sessionBuffer.append(pending)

        let isEscalationEvent = event.level == .error || event.level == .fatal
        guard isEscalationEvent else { return }

        // Escalation: first error/fatal in a sampled-out session
        isSampledIn = true
        eventBuffer.append(contentsOf: sessionBuffer)
        sessionBuffer.removeAll()

        if config.enableConsoleOutput {
            await consoleOutput.output(event: event)
        }

        await flush()
    }

    public func logCamera(
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

    public func logML(
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

    public func logView(
        viewName: String,
        level: LogLevel,
        retention: RetentionPeriod,
        metadata: [String: Any]?
    ) async {
        var mergedMetadata = metadata ?? [:]
        mergedMetadata["view_name"] = viewName

        await logEvent(
            eventType: .view,
            eventName: "view_\(viewName)",
            level: level,
            errorMessage: nil,
            retention: retention,
            metadata: mergedMetadata,
            stackTrace: nil
        )
    }

    public func logDevice(
        eventName: String,
        level: LogLevel,
        retention: RetentionPeriod,
        metadata: [String: Any]?
    ) async {
        await logEvent(
            eventType: .device,
            eventName: eventName,
            level: level,
            errorMessage: nil,
            retention: retention,
            metadata: metadata,
            stackTrace: nil
        )
    }

    public func logFeedback(
        eventName: String,
        level: LogLevel,
        errorMessage: String?,
        retention: RetentionPeriod,
        metadata: [String: Any]?
    ) async {
        await logEvent(
            eventType: .mlModel, // Map to supported ml_model type
            eventName: eventName,
            level: level,
            errorMessage: errorMessage,
            retention: retention,
            metadata: metadata,
            stackTrace: nil
        )
    }

    public func logSdk(
        eventName: String,
        level: LogLevel,
        errorMessage: String?,
        retention: RetentionPeriod,
        metadata: [String: Any]?
    ) async {
        await logEvent(
            eventType: .device, // Map to supported device type
            eventName: eventName,
            level: level,
            errorMessage: errorMessage,
            retention: retention,
            metadata: metadata,
            stackTrace: nil
        )
    }

    public func logException(
        eventType: EventType,
        eventName: String,
        exception: Error,
        level: LogLevel,
        retention: RetentionPeriod,
        metadata: [String: Any]?
    ) async {
        // Extract stack trace
        let stackTrace = Thread.callStackSymbols.joined(separator: "\n")

        // Get error message
        let errorMessage: String = if let truoraException = exception as? TruoraException {
            truoraException.errorDescription ?? "Unknown error"
        } else {
            exception.localizedDescription
        }

        await logEvent(
            eventType: eventType,
            eventName: eventName,
            level: level,
            errorMessage: errorMessage,
            retention: retention,
            metadata: metadata,
            stackTrace: stackTrace
        )
    }

    // MARK: - Flush

    public func flush() async {
        guard !eventBuffer.isEmpty else { return }

        // Backoff check: if we have failures, wait exponentially before retrying
        if flushFailureCount > 0 {
            let backoffSeconds = pow(2.0, Double(min(flushFailureCount, 6))) // 2s, 4s, 8s, 16s, 32s, 64s
            if let last = lastFlushAttemptTime, Date().timeIntervalSince(last) < backoffSeconds {
                return // Skip flush during backoff period
            }
        }

        // Copy buffer atomically (actor-isolated)
        let pendingEvents = eventBuffer
        let deviceModel = await deviceInfo.model
        let osVersion = await deviceInfo.osVersion

        // Send to API if configured
        if let apiOutput {
            // Removing by sequence keeps events logged while a batch is in flight, even if another flush overlaps.
            var sentSequences = Set<Int>()
            for run in Self.batchesByContext(pendingEvents) {
                let batch = SDKLog(
                    sdkVersion: config.sdkVersion,
                    platform: "ios",
                    timestamp: Int64(Date().timeIntervalSince1970 * 1000),
                    deviceModel: deviceModel,
                    osVersion: osVersion,
                    validationId: run.context.validationId,
                    accountId: run.context.accountId,
                    events: run.pending.map(\.event)
                )

                guard await apiOutput.output(batch: batch) else {
                    eventBuffer.removeAll { sentSequences.contains($0.sequence) }
                    flushFailureCount += 1
                    lastFlushAttemptTime = Date()
                    debugLog("⚠️ [TruoraLogger] Flush failed (consecutive: \(flushFailureCount)). Retaining events.")
                    return
                }
                sentSequences.formUnion(run.pending.map(\.sequence))
            }

            eventBuffer.removeAll { sentSequences.contains($0.sequence) }
            flushFailureCount = 0
            lastFlushAttemptTime = nil
        } else {
            // If no API output (e.g. testing/dev), just clear
            eventBuffer.removeAll()
        }
    }

    public func flush(timeoutMs: Int64) async {
        // Use withTimeoutOrNil for time-bounded flush
        let timeoutSeconds = TimeInterval(timeoutMs) / 1000.0
        await withTimeoutOrNil(timeoutSeconds: timeoutSeconds) {
            await self.flush()
        }
    }

    // MARK: - Shutdown

    /// Shutdown the logger and release resources.
    /// Any pending events may be lost.
    public func shutdown() async {
        flushTask?.cancel()
        flushTask = nil

        // Remove notification observers
        notificationObservers.forEach { NotificationCenter.default.removeObserver($0) }
        notificationObservers.removeAll()

        sessionBuffer.removeAll()

        // Final flush attempt
        await flush(timeoutMs: 5000)
    }

    // MARK: - Helpers

    /// Validation context structure to avoid large tuples
    private struct ValidationContext: Equatable {
        let validationId: String?
        let validationType: String?
        let accountId: String?
        let processId: String?
        let flowId: String?
        let clientId: String?
    }

    /// A buffered event with the context it was logged under, so its batch header matches it.
    private struct PendingEvent {
        let sequence: Int
        let event: SDKEvent
        let context: ValidationContext
    }

    /// Splits buffered events into runs logged under the same context, keeping their order.
    private static func batchesByContext(
        _ pendingEvents: [PendingEvent]
    ) -> [(context: ValidationContext, pending: [PendingEvent])] {
        var batches: [(context: ValidationContext, pending: [PendingEvent])] = []
        for pending in pendingEvents {
            if let last = batches.last, last.context == pending.context {
                batches[batches.count - 1].pending.append(pending)
            } else {
                batches.append((context: pending.context, pending: [pending]))
            }
        }
        return batches
    }

    /// Get validation context from ValidationConfig
    private func getValidationContext() async -> ValidationContext {
        let config = await MainActor.run { ValidationConfig.shared }
        let accountId = await MainActor.run { config.accountId }
        let validationId = await MainActor.run { config.validationId }

        return ValidationContext(
            validationId: validationId,
            validationType: nil,
            accountId: accountId,
            processId: nil,
            flowId: nil,
            clientId: nil
        )
    }

    /// Build context metadata and merge with event-specific metadata.
    /// Context keys use the s_ prefix. Event-specific keys override context.
    private func buildMergedMetadata(
        context: ValidationContext,
        eventMetadata: [String: Any]?
    ) -> [String: AnyCodableValue] {
        let pairs: [(String, String?)] = [
            ("s_account_id", context.accountId),
            ("s_validation_id", context.validationId),
            ("s_process_id", context.processId),
            ("s_flow_id", context.flowId),
            ("s_client_id", context.clientId)
        ]
        var contextMeta: [String: AnyCodableValue] = [:]
        for (key, value) in pairs {
            guard let value else { continue }
            contextMeta[key] = .string(value)
        }
        let converted = convertMetadata(eventMetadata) ?? [:]
        return contextMeta.merging(converted) { _, event in event }
    }

    // GDPR Forbidden keys from backend spec (static to avoid recreating on every call)
    private static let forbiddenKeys: Set<String> = [
        "user_id", "userid", "user", "username", "email", "mail", "e_mail",
        "phone", "phone_number", "phonenumber", "mobile", "name", "first_name",
        "firstname", "last_name", "lastname", "address", "street", "city",
        "postal_code", "postalcode", "imei", "serial_number", "serialnumber",
        "mac_address", "macaddress", "device_id", "deviceid", "advertising_id",
        "advertisingid", "adid", "android_id", "androidid", "ios_idfa", "idfa",
        "idfv", "credit_card", "creditcard", "card_number", "cardnumber",
        "account_number", "accountnumber", "ssn", "social_security",
        "socialsecurity", "fingerprint", "face_data", "facedata", "biometric",
        "retina", "password", "pwd", "token", "auth_token", "authtoken",
        "ip_address", "ipaddress", "ip", "geolocation", "gps", "latitude",
        "longitude", "lat", "lon", "lng"
    ]

    private static let recognizedPrefixes = ["s_", "i_", "f_", "b_", "t_", "as_"]

    private func hasRecognizedPrefix(_ key: String) -> Bool {
        Self.recognizedPrefixes.contains { key.hasPrefix($0) }
    }

    private func applyTypePrefix(key: String, value: AnyCodableValue) -> String {
        guard !hasRecognizedPrefix(key) else { return key }
        switch value {
        case .bool: return "b_\(key)"
        case .int: return "i_\(key)"
        case .double: return "f_\(key)"
        case .string: return "s_\(key)"
        case .stringArray: return "as_\(key)"
        }
    }

    /// Convert Any metadata to AnyCodableValue metadata with type prefixing and GDPR filtering
    private func convertMetadata(_ metadata: [String: Any]?) -> [String: AnyCodableValue]? {
        guard let metadata else { return nil }

        return metadata.reduce(into: [String: AnyCodableValue]()) { result, element in
            let key = element.key.lowercased()
            guard !Self.forbiddenKeys.contains(key) else { return }

            let value: AnyCodableValue = switch element.value {
            case let val as Bool: .bool(val)
            case let val as Int: .int(val)
            case let val as Int64: .int(Int(val))
            case let val as Double: .double(val)
            case let val as Float: .double(Double(val))
            case let val as [String]: .stringArray(val)
            case let val as String: .string(val)
            default: .string("\(element.value)")
            }

            let prefixedKey = applyTypePrefix(key: element.key, value: value)
            result[prefixedKey] = value
        }
    }

    /// Execute with timeout (in seconds)
    private func withTimeoutOrNil<T>(
        timeoutSeconds: TimeInterval,
        operation: @escaping () async throws -> T
    ) async rethrows -> T? {
        do {
            return try await withThrowingTaskGroup(of: T.self) { group in
                group.addTask {
                    try await operation()
                }

                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                    throw CancellationError()
                }

                guard let result = try await group.next() else {
                    group.cancelAll()
                    return nil
                }

                group.cancelAll()
                return result
            }
        } catch {
            return nil
        }
    }
}
