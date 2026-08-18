//
//  ProcessRunnerConstants.swift
//  TruoraValidationsSDK
//

import Foundation

/// Timing constants ported from the web process-runner's `src/config/constants.ts`.
///
/// The runner's behavior is timing-sensitive (the backend resolves steps
/// asynchronously), so these must stay numerically identical to the web values.
enum ProcessRunnerConstants {
    /// `DELAY` — wait between two `readProcess` polls.
    static let pollDelay: TimeInterval = 3

    /// `MAX_POLLING_TIME` — wall-clock budget for resolving a single step.
    /// With ``pollDelay`` this allows 100 polls before the step is abandoned.
    static let maxPollingTime: TimeInterval = 300

    /// `MAX_RETRIES` — **total attempts** for a DI API call, not retries after the
    /// first. The web loop is `for (retryCount = 0; retryCount < MAX_RETRIES; ...)`
    /// and backs off on every pass but the last, so five attempts wait four times.
    static let maxAttempts = 5

    /// `EXPONENTIAL_BACKOFF_DELAY` — first backoff, doubled on each later attempt.
    static let backoffBaseDelay: TimeInterval = 0.5

    static let backoffMultiplier: Double = 2

    /// The API retry policy for every call the runner makes.
    ///
    /// ``TruoraRetryPolicy/maxRetries`` counts retries *after* the initial attempt, so
    /// it is one less than ``maxAttempts``. The resulting schedule is
    /// `0.5s, 1s, 2s, 4s` — the same four waits as the web loop.
    static let retryPolicy = TruoraRetryPolicy(
        maxRetries: maxAttempts - 1,
        baseDelay: backoffBaseDelay,
        multiplier: backoffMultiplier
    )

    /// Whether `pollCount` polls have spent the ``maxPollingTime`` budget
    /// (`pollCount * pollDelay >= maxPollingTime`). Shared by the step polling
    /// (``PollingController``) and results finalization (``TruoraProcessManager``) so the
    /// two use identical timeout arithmetic.
    static func hasExhaustedPollingBudget(pollCount: Int) -> Bool {
        Double(pollCount) * pollDelay >= maxPollingTime
    }
}
