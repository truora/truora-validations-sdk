//
//  TruoraProcessRequestExecutor.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 01/07/26.
//

import Foundation

/// Executes Digital Identity requests, mapping failures to ``TruoraProcessApiError`` and
/// transparently retrying transient (``TruoraProcessApiError/isRetriable``) errors with
/// exponential backoff as configured by a ``TruoraRetryPolicy``.
///
/// Behaviour:
/// - A returned value is wrapped in ``TruoraNetworkResult/success(_:)``.
/// - A thrown error is classified via ``TruoraProcessErrorMapper/from(error:)``.
/// - Retriable errors are retried until the retry budget
///   (``TruoraRetryPolicy/maxRetries``) is spent, waiting
///   ``TruoraRetryPolicy/delay(forAttempt:)`` between attempts. The last mapped error
///   is returned as ``TruoraNetworkResult/failure(_:)``.
///
/// - Non-retriable errors are returned immediately, without consuming the retry
///   budget.
/// - Task cancellation always propagates (via a thrown `CancellationError`) so
///   structured-concurrency cancellation is never swallowed or retried.
public struct TruoraProcessRequestExecutor {
    private let retryPolicy: TruoraRetryPolicy
    private let sleep: (TimeInterval) async throws -> Void

    /// - Parameters:
    ///   - retryPolicy: Backoff configuration. Defaults to ``TruoraRetryPolicy/default``.
    ///   - sleep: Suspending delay used between attempts. Injectable so tests can
    ///     assert the backoff schedule without real waiting.
    public init(
        retryPolicy: TruoraRetryPolicy = .default,
        sleep: @escaping (TimeInterval) async throws -> Void = { seconds in
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        }
    ) {
        self.retryPolicy = retryPolicy
        self.sleep = sleep
    }

    /// Runs `operation`, retrying transient failures with exponential backoff.
    ///
    /// - Parameter operation: Async throwing block that performs a single attempt
    ///   (typically a ``TruoraProcessAPIClient`` call).
    /// - Returns: ``TruoraNetworkResult/success(_:)`` with the produced value, or
    ///   ``TruoraNetworkResult/failure(_:)`` with the mapped error after retries are spent.
    /// - Throws: `CancellationError` if the surrounding task is cancelled.
    public func execute<T>(_ operation: () async throws -> T) async throws -> TruoraNetworkResult<T> {
        var attempt = 0

        while true {
            try Task.checkCancellation()

            let mappedError: TruoraProcessApiError
            do {
                let value = try await operation()
                return .success(value)
            } catch is CancellationError {
                throw CancellationError()
            } catch let urlError as URLError where urlError.code == .cancelled {
                throw CancellationError()
            } catch {
                mappedError = TruoraProcessErrorMapper.from(error: error)
            }

            guard mappedError.isRetriable, attempt < retryPolicy.maxRetries else {
                return .failure(mappedError)
            }

            try await sleep(retryPolicy.delay(forAttempt: attempt))
            attempt += 1
        }
    }
}
