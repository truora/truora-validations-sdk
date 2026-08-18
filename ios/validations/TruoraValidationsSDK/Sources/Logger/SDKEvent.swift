//
//  SDKEvent.swift
//  TruoraValidationsSDK
//
//  Created by AI Assistant on 2025-02-01.
//

import Foundation

/// Slim event model for structured SDK logging.
///
/// Individual events carry only event-specific data.
/// Batch-level fields (device model, OS version, SDK version,
/// platform, account/validation IDs) live on SDKLog.
public struct SDKEvent: Codable, Sendable {
    /// Event type category (CAMERA, ML_MODEL, VIEW, etc.)
    public let eventType: EventType

    /// Event name in snake_case (max 35 characters per spec)
    public let eventName: String

    /// Log severity level
    public let level: LogLevel

    /// Whether the event represents a successful operation
    public let success: Bool

    /// Error message if applicable
    public let errorMessage: String?

    /// Duration in milliseconds for timing events
    public let durationMs: Int64?

    /// Stack trace for error events
    public let stackTrace: String?

    /// Flexible metadata dictionary for event-specific context
    public let metadata: [String: AnyCodableValue]

    // MARK: - Initialization

    public init(
        eventType: EventType,
        eventName: String,
        level: LogLevel,
        success: Bool? = nil,
        errorMessage: String? = nil,
        durationMs: Int64? = nil,
        stackTrace: String? = nil,
        metadata: [String: AnyCodableValue] = [:]
    ) {
        self.eventType = eventType
        self.eventName = String(eventName.prefix(35))
        self.level = level
        self.success = success ?? (level != .error && level != .fatal)
        self.errorMessage = errorMessage
        self.durationMs = durationMs
        self.stackTrace = stackTrace
        self.metadata = metadata
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case eventType = "event_type"
        case eventName = "event_name"
        case level
        case success
        case errorMessage = "error_message"
        case durationMs = "duration_ms"
        case stackTrace = "stack_trace"
        case metadata
    }
}

// MARK: - Convenience Methods

public extension SDKEvent {
    /// Returns a JSON string representation of the event
    func toJSON() -> String? {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .useDefaultKeys
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Returns a dictionary representation suitable for API requests
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "event_type": eventType.rawValue,
            "event_name": eventName,
            "level": level.rawValue,
            "success": success
        ]
        if let errorMessage {
            dict["error_message"] = errorMessage
        }
        if let durationMs {
            dict["duration_ms"] = durationMs
        }
        if let stackTrace {
            dict["stack_trace"] = stackTrace
        }
        dict["metadata"] = metadata.mapValues { $0.rawValue }
        return dict
    }
}
