//
//  SpyLogger.swift
//  TruoraValidationsSDKTests
//

import Foundation
@testable import TruoraValidationsSDK

/// Records `logSdk` calls for assertions; all other methods are no-ops.
final class SpyLogger: TruoraLogger, @unchecked Sendable {
    struct SdkCall {
        let eventName: String
        let level: LogLevel
        let errorMessage: String?
        let metadata: [String: Any]?
    }

    private let lock = NSLock()
    private var _sdkCalls: [SdkCall] = []
    var sdkCalls: [SdkCall] {
        lock.lock()
        defer { lock.unlock() }
        return _sdkCalls
    }

    func logSdk(eventName: String, level: LogLevel, errorMessage: String?, retention: RetentionPeriod, metadata: [String: Any]?) async {
        lock.lock()
        _sdkCalls.append(SdkCall(eventName: eventName, level: level, errorMessage: errorMessage, metadata: metadata))
        lock.unlock()
    }

    func logEvent(eventType: EventType, eventName: String, level: LogLevel, errorMessage: String?, retention: RetentionPeriod, metadata: [String: Any]?, stackTrace: String?) async {}
    func logCamera(eventName: String, level: LogLevel, errorMessage: String?, retention: RetentionPeriod, metadata: [String: Any]?) async {}
    func logML(eventName: String, level: LogLevel, errorMessage: String?, retention: RetentionPeriod, metadata: [String: Any]?) async {}
    func logView(viewName: String, level: LogLevel, retention: RetentionPeriod, metadata: [String: Any]?) async {}
    func logDevice(eventName: String, level: LogLevel, retention: RetentionPeriod, metadata: [String: Any]?) async {}
    func logFeedback(eventName: String, level: LogLevel, errorMessage: String?, retention: RetentionPeriod, metadata: [String: Any]?) async {}
    func logException(eventType: EventType, eventName: String, exception: Error, level: LogLevel, retention: RetentionPeriod, metadata: [String: Any]?) async {}
    func flush() async {}
    func flush(timeoutMs: Int64) async {}
}
