//
//  UploadTimeoutPolicy.swift
//  TruoraValidationsSDK
//

import Foundation

/// Limits for presigned-URL `PUT`s. Shares the per-file budget with KMP `UploadTimeouts`.
enum UploadTimeoutPolicy {
    /// Total time for one file's upload: attempts, backoff and connectivity waits. URLSession's
    /// idle timeout still catches a stalled transfer inside each attempt.
    static let totalBudget: TimeInterval = 300
}

/// Runs `operation`, cancelling it with `URLError(.timedOut)` after `seconds`.
func withUploadDeadline<T: Sendable>(
    _ seconds: TimeInterval,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }

        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(max(0, seconds) * 1_000_000_000))
            throw URLError(.timedOut)
        }

        defer { group.cancelAll() }

        guard let result = try await group.next() else {
            throw URLError(.timedOut)
        }

        return result
    }
}
