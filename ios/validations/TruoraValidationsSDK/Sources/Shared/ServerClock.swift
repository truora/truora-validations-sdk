//
//  ServerClock.swift
//  TruoraValidationsSDK
//

import Foundation

/// Server time estimated from the validation `creation_date`, so expiration checks
/// do not depend on the device clock being set correctly. Time elapsed after the
/// sync is measured with the monotonic clock, so later device clock changes do not
/// affect it.
enum ServerClock {
    private struct Anchor {
        let serverTime: TimeInterval
        let monotonicTime: TimeInterval
    }

    private final class State: @unchecked Sendable {
        let lock = NSLock()
        var anchor: Anchor?
    }

    private static let state = State()

    /// Seconds from a clock that is not affected by time adjustments and keeps
    /// counting while the device sleeps.
    static func monotonicNow() -> TimeInterval {
        TimeInterval(clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)) / 1_000_000_000
    }

    /// Whole milliseconds since `start`, a value taken from `monotonicNow()`.
    static func millisecondsSince(_ start: TimeInterval) -> Int {
        max(0, Int((monotonicNow() - start) * 1000))
    }

    /// Anchors the server time from a validation `creation_date` to the monotonic clock.
    static func sync(
        withCreationDate creationDate: String?,
        monotonicNow: TimeInterval = ServerClock.monotonicNow()
    ) {
        guard let serverTime = parseCreationDate(creationDate) else {
            return
        }
        state.lock.withLock {
            state.anchor = Anchor(serverTime: serverTime, monotonicTime: monotonicNow)
        }
    }

    /// Server time when synced, device time otherwise.
    static func now(
        deviceNow: TimeInterval = Date().timeIntervalSince1970,
        monotonicNow: TimeInterval = ServerClock.monotonicNow()
    ) -> TimeInterval {
        guard let anchor = state.lock.withLock({ state.anchor }) else {
            return deviceNow
        }
        return anchor.serverTime + (monotonicNow - anchor.monotonicTime)
    }

    static func reset() {
        state.lock.withLock { state.anchor = nil }
    }

    /// Parses an RFC 3339 date such as `2025-10-07T21:13:45.942001841Z` or
    /// `2025-01-01T00:00:00-05:00`, ignoring the fractional seconds.
    static func parseCreationDate(_ value: String?) -> TimeInterval? {
        guard let value,
              let match = value.range(
                  of: #"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?([Zz]|[+-]([01]\d|2[0-3]):[0-5]\d)$"#,
                  options: .regularExpression
              ) else {
            return nil
        }
        let text = value[match]
        let zone = text.hasSuffix("z") || text.hasSuffix("Z") ? "Z" : String(text.suffix(6))
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: String(text.prefix(19)) + zone)?.timeIntervalSince1970
    }
}
