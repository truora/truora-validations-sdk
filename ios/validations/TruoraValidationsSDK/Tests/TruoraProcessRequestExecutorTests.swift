//
//  TruoraProcessRequestExecutorTests.swift
//  TruoraValidationsSDKTests
//
//  Created by Truora on 01/07/26.
//

import XCTest
@testable import TruoraValidationsSDK

final class TruoraProcessRequestExecutorTests: XCTestCase {
    /// Records the delays passed to the injected sleep so tests can assert the
    /// backoff schedule without waiting.
    private actor DelayRecorder {
        private(set) var delays: [TimeInterval] = []
        func record(_ delay: TimeInterval) {
            delays.append(delay)
        }
    }

    private func retriesPolicy(maxRetries: Int = 3) -> TruoraRetryPolicy {
        TruoraRetryPolicy(
            maxRetries: maxRetries,
            baseDelay: 0.01,
            maxDelay: 1.0,
            multiplier: 2.0
        )
    }

    private func makeExecutor(
        maxRetries: Int = 3,
        recorder: DelayRecorder
    ) -> TruoraProcessRequestExecutor {
        TruoraProcessRequestExecutor(
            retryPolicy: retriesPolicy(maxRetries: maxRetries),
            sleep: { await recorder.record($0) }
        )
    }

    // MARK: - Success

    func testReturnsSuccessOnFirstAttempt() async throws {
        let recorder = DelayRecorder()
        let executor = makeExecutor(recorder: recorder)
        var calls = 0

        let result = try await executor.execute { () -> Int in
            calls += 1
            return 42
        }

        XCTAssertTrue(result.isSuccess)
        XCTAssertEqual(result.value, 42)
        XCTAssertEqual(calls, 1)
        let delays = await recorder.delays
        XCTAssertTrue(delays.isEmpty)
    }

    // MARK: - Retry then succeed

    func testRetriesServerErrorThenSucceeds() async throws {
        let recorder = DelayRecorder()
        let executor = makeExecutor(recorder: recorder)
        var calls = 0

        let result = try await executor.execute { () -> String in
            calls += 1
            if calls < 3 {
                throw TruoraProcessAPIError.serverError(statusCode: 500, body: nil)
            }
            return "ok"
        }

        XCTAssertEqual(result.value, "ok")
        XCTAssertEqual(calls, 3)
        let delays = await recorder.delays
        XCTAssertEqual(delays.count, 2)
        XCTAssertEqual(delays[0], 0.01, accuracy: 0.0001)
        XCTAssertEqual(delays[1], 0.02, accuracy: 0.0001)
    }

    func testRetriesRateLimit() async throws {
        let recorder = DelayRecorder()
        let executor = makeExecutor(recorder: recorder)
        var calls = 0

        let result = try await executor.execute { () -> Int in
            calls += 1
            if calls == 1 {
                throw TruoraProcessAPIError.serverError(statusCode: 429, body: nil)
            }
            return 1
        }

        XCTAssertTrue(result.isSuccess)
        XCTAssertEqual(calls, 2)
    }

    // MARK: - Give up

    func testGivesUpAfterExhaustingRetries() async throws {
        let recorder = DelayRecorder()
        let executor = makeExecutor(maxRetries: 3, recorder: recorder)
        var calls = 0

        let result = try await executor.execute { () -> Int in
            calls += 1
            throw TruoraProcessAPIError.serverError(statusCode: 500, body: nil)
        }

        XCTAssertTrue(result.isFailure)
        XCTAssertEqual(result.error?.kind, .server)
        XCTAssertEqual(calls, 4) // initial + 3 retries
        let delays = await recorder.delays
        XCTAssertEqual(delays.count, 3)
    }

    // MARK: - Non-retriable

    func testDoesNotRetryNonRetriableError() async throws {
        let recorder = DelayRecorder()
        let executor = makeExecutor(recorder: recorder)
        var calls = 0

        let result = try await executor.execute { () -> Int in
            calls += 1
            throw TruoraProcessAPIError.serverError(statusCode: 400, body: nil)
        }

        XCTAssertTrue(result.isFailure)
        XCTAssertEqual(result.error?.kind, .invalidRequest)
        XCTAssertEqual(calls, 1)
        let delays = await recorder.delays
        XCTAssertTrue(delays.isEmpty)
    }

    func testDoesNotRetryConflict() async throws {
        let recorder = DelayRecorder()
        let executor = makeExecutor(recorder: recorder)
        var calls = 0

        let result = try await executor.execute { () -> Int in
            calls += 1
            throw TruoraProcessAPIError.serverError(statusCode: 409, body: nil)
        }

        XCTAssertEqual(result.error?.kind, .conflict)
        XCTAssertEqual(calls, 1)
    }

    // MARK: - Transport failures

    func testRetriesTransportNetworkErrors() async throws {
        let recorder = DelayRecorder()
        let executor = makeExecutor(recorder: recorder)
        var calls = 0

        let result = try await executor.execute { () -> Int in
            calls += 1
            if calls < 3 {
                throw TruoraProcessAPIError.networkError(URLError(.timedOut))
            }
            return 7
        }

        XCTAssertEqual(result.value, 7)
        XCTAssertEqual(calls, 3)
    }

    func testReturnsNetworkFailureWhenTransportKeepsFailing() async throws {
        let recorder = DelayRecorder()
        let executor = makeExecutor(maxRetries: 2, recorder: recorder)

        let result = try await executor.execute { () -> Int in
            throw URLError(.notConnectedToInternet)
        }

        XCTAssertEqual(result.error?.kind, .network)
    }

    // MARK: - Cancellation

    func testCancellationIsNotSwallowed() async {
        let recorder = DelayRecorder()
        let executor = makeExecutor(recorder: recorder)

        do {
            _ = try await executor.execute { () -> Int in
                throw CancellationError()
            }
            XCTFail("Expected CancellationError to propagate")
        } catch is CancellationError {
            // expected
        } catch {
            XCTFail("Expected CancellationError, got \(error)")
        }
    }

    // MARK: - No-retry policy

    func testNonePolicyAttemptsOperationOnce() async throws {
        let recorder = DelayRecorder()
        let executor = TruoraProcessRequestExecutor(retryPolicy: .none, sleep: { await recorder.record($0) })
        var calls = 0

        let result = try await executor.execute { () -> Int in
            calls += 1
            throw TruoraProcessAPIError.serverError(statusCode: 500, body: nil)
        }

        XCTAssertTrue(result.isFailure)
        XCTAssertEqual(calls, 1)
    }
}
