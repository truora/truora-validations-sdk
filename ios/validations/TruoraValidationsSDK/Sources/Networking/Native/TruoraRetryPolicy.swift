//
//  TruoraRetryPolicy.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 01/07/26.
//

import Foundation

/// Configuration for retrying transient (``TruoraProcessApiError/isRetriable``) failures with
/// exponential backoff
///
/// ```
/// delay = min(baseDelay * multiplier^attempt, maxDelay)
/// ```
///
/// Delays are expressed in seconds (`TimeInterval`) to match
/// ``TruoraSessionConfiguration``.
public struct TruoraRetryPolicy {
    /// Maximum number of retries after the initial attempt. `3` means up to 4
    /// total attempts.
    public let maxRetries: Int

    /// Delay before the first retry (attempt `0`), in seconds.
    public let baseDelay: TimeInterval

    /// Upper bound applied to every computed delay, in seconds.
    public let maxDelay: TimeInterval

    /// Growth factor applied per attempt. `2.0` doubles the delay each time.
    public let multiplier: Double

    public init(
        maxRetries: Int = 3,
        baseDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 30.0,
        multiplier: Double = 2.0
    ) {
        precondition(maxRetries >= 0, "maxRetries must be >= 0")
        precondition(baseDelay >= 0, "baseDelay must be >= 0")
        precondition(maxDelay >= 0, "maxDelay must be >= 0")
        precondition(multiplier >= 1.0, "multiplier must be >= 1.0")

        self.maxRetries = maxRetries
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.multiplier = multiplier
    }

    /// Default policy tuned for mobile networks.
    public static let `default` = TruoraRetryPolicy()

    /// A policy that performs no retries; the request is attempted exactly once.
    public static let none = TruoraRetryPolicy(maxRetries: 0)

    /// Computes the backoff delay (in seconds) to wait before the retry that
    /// follows the given zero-based `attempt`. Always within `0...maxDelay`.
    public func delay(forAttempt attempt: Int) -> TimeInterval {
        precondition(attempt >= 0, "attempt must be >= 0")

        let exponential = baseDelay * pow(multiplier, Double(attempt))
        let delay = min(exponential, maxDelay)

        return min(max(0, delay), maxDelay)
    }
}
