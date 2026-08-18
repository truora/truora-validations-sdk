//
//  PollingControllerTests.swift
//  TruoraValidationsSDKTests
//

import XCTest
@testable import TruoraValidationsSDK

final class PollingControllerTests: XCTestCase {
    // MARK: - Builders

    /// A step at index `1`, so tests can tell a positional lookup apart from a
    /// "first element" fallback.
    private func step(
        status: TruoraBlockStatus? = nil,
        remainingRetries: Int? = nil,
        asyncStep: Bool? = nil
    ) -> TruoraStep {
        TruoraStep(
            stepId: "STP002",
            type: .takeDocumentPhoto,
            output: status.map { TruoraStepOutput(status: $0) },
            remainingRetries: remainingRetries,
            asyncStep: asyncStep
        )
    }

    /// A process whose submitted step sits at index `1`.
    private func process(
        status: TruoraProcessStatus? = .pending,
        currentStep: Int?,
        submitted: TruoraStep
    ) -> TruoraProcessResponse {
        TruoraProcessResponse(
            processId: "IPR001",
            status: status,
            currentStep: currentStep,
            steps: [
                TruoraStep(stepId: "STP001", type: .enterAuthorization),
                submitted,
                TruoraStep(stepId: "STP003", type: .recordFaceVideoLiveness)
            ]
        )
    }

    private func decide(_ response: TruoraProcessResponse, pollCount: Int = 0) -> StepDecision {
        PollingController.decide(response: response, previousStepIndex: 1, pollCount: pollCount)
    }

    // MARK: - advance

    func testAdvancesWhenCurrentStepChangedAndStepSucceeded() {
        let response = process(currentStep: 2, submitted: step(status: .success))

        XCTAssertEqual(decide(response), .advance)
    }

    /// Success alone is not enough: the web runner keeps polling until the backend
    /// actually moves `current_step` or finishes the process.
    func testKeepsPollingWhenStepSucceededButCurrentStepUnchanged() {
        let response = process(currentStep: 1, submitted: step(status: .success))

        XCTAssertEqual(decide(response), .keepPolling)
    }

    /// `hasStepChanged` also requires the new index to address a real step.
    func testKeepsPollingWhenCurrentStepMovedPastTheEndOfSteps() {
        let response = process(currentStep: 3, submitted: step(status: .success))

        XCTAssertEqual(decide(response), .keepPolling)
    }

    // MARK: - retry

    func testRetriesWhenStepFailedWithRemainingRetries() {
        let response = process(currentStep: 1, submitted: step(status: .failure, remainingRetries: 2))

        XCTAssertEqual(decide(response), .retry)
    }

    /// A retryable failure wins over an advanced `current_step`: the user gets
    /// another attempt at the same step.
    func testRetryTakesPrecedenceOverStepChanged() {
        let response = process(currentStep: 2, submitted: step(status: .failure, remainingRetries: 1))

        XCTAssertEqual(decide(response), .retry)
    }

    func testAdvancesWhenStepFailedWithRetriesExhausted() {
        let response = process(currentStep: 2, submitted: step(status: .failure, remainingRetries: 0))

        XCTAssertEqual(decide(response), .advance)
    }

    // MARK: - terminal

    func testTerminalWhenProcessStatusIsNotPending() {
        let response = process(status: .success, currentStep: 1, submitted: step(status: .success))

        XCTAssertEqual(decide(response), .terminal)
    }

    func testTerminalWhenProcessFailedEvenWithRetriesExhausted() {
        let response = process(
            status: .failure,
            currentStep: 1,
            submitted: step(status: .failure, remainingRetries: 0)
        )

        XCTAssertEqual(decide(response), .terminal)
    }

    // MARK: - async_step

    func testAsyncStepAdvancesOnceRetriesSpentAndStepChanged() {
        let response = process(
            currentStep: 2,
            submitted: step(status: .pending, remainingRetries: 0, asyncStep: true)
        )

        XCTAssertEqual(decide(response), .advance)
    }

    func testAsyncStepKeepsPollingWhileRetriesRemain() {
        let response = process(
            currentStep: 2,
            submitted: step(status: .pending, remainingRetries: 1, asyncStep: true)
        )

        XCTAssertEqual(decide(response), .keepPolling)
    }

    func testAsyncStepKeepsPollingWhileCurrentStepUnchanged() {
        let response = process(
            currentStep: 1,
            submitted: step(status: .pending, remainingRetries: 0, asyncStep: true)
        )

        XCTAssertEqual(decide(response), .keepPolling)
    }

    /// A *sync* step that is still pending keeps polling even once the backend has
    /// moved on — only `async_step` short-circuits the wait.
    func testSyncPendingStepKeepsPollingEvenWhenStepChanged() {
        let response = process(
            currentStep: 2,
            submitted: step(status: .pending, remainingRetries: 0, asyncStep: false)
        )

        XCTAssertEqual(decide(response), .keepPolling)
    }

    // MARK: - unverified step

    /// Before the backend evaluates a step there is no `verification_output`, which
    /// reads the same as `pending`.
    func testKeepsPollingWhenStepHasNoOutput() {
        let response = process(currentStep: 1, submitted: step())

        XCTAssertEqual(decide(response), .keepPolling)
    }

    // MARK: - timeout

    func testKeepsPollingJustBeforeTheBudgetIsSpent() {
        let response = process(currentStep: 1, submitted: step(status: .pending))

        XCTAssertEqual(decide(response, pollCount: 99), .keepPolling)
    }

    /// `pollingCount * DELAY >= MAX_POLLING_TIME` — 100 polls at 3s each. This is
    /// `timedOut`, not `terminal`: the process is still pending.
    func testTimedOutOnceThePollingBudgetIsSpent() {
        let response = process(currentStep: 1, submitted: step(status: .pending))

        XCTAssertEqual(decide(response, pollCount: 100), .timedOut)
    }

    /// A finished process still reads as `terminal` even past the budget, so the
    /// loop finalizes rather than reporting a timeout.
    func testTerminalBeatsTimeoutWhenProcessFinished() {
        let response = process(status: .success, currentStep: 1, submitted: step(status: .success))

        XCTAssertEqual(decide(response, pollCount: 100), .terminal)
    }

    // MARK: - pollUntilResolved

    func testPollUntilResolvedStopsAtTheFirstNonPollingDecision() async throws {
        let pending = process(currentStep: 1, submitted: step(status: .pending))
        let advanced = process(currentStep: 2, submitted: step(status: .success))
        let responses = ResponseScript([pending, pending, advanced])
        let delays = DelayRecorder()

        let controller = PollingController(sleep: { await delays.record($0) })
        let outcome = try await controller.pollUntilResolved(previousStepIndex: 1) {
            await responses.next()
        }

        XCTAssertEqual(outcome.decision, .advance)
        XCTAssertEqual(outcome.process.currentStepIndex, 2, "Carries the read that resolved the step")
        let recorded = await delays.values
        XCTAssertEqual(recorded, [3, 3], "One delay after each of the two pending reads")
        let reads = await responses.reads
        XCTAssertEqual(reads, 3)
    }

    /// The step is abandoned after 100 delays, without waiting 300s of real time.
    func testPollUntilResolvedTimesOutAfterTheFullBudget() async throws {
        let pending = process(currentStep: 1, submitted: step(status: .pending))
        let delays = DelayRecorder()

        let controller = PollingController(sleep: { await delays.record($0) })
        let outcome = try await controller.pollUntilResolved(previousStepIndex: 1) { pending }

        XCTAssertEqual(outcome.decision, .timedOut)
        let recorded = await delays.values
        XCTAssertEqual(recorded.count, 100)
        XCTAssertEqual(recorded.reduce(0, +), ProcessRunnerConstants.maxPollingTime)
    }

    func testPollUntilResolvedPropagatesReadFailures() async {
        struct ReadFailure: Error {}
        let controller = PollingController(sleep: { _ in })

        do {
            _ = try await controller.pollUntilResolved(previousStepIndex: 1) {
                throw ReadFailure()
            }
            XCTFail("Expected the read failure to propagate")
        } catch is ReadFailure {
            // Expected.
        } catch {
            XCTFail("Expected ReadFailure, got \(error)")
        }
    }
}

// MARK: - Helpers

/// Serves a scripted sequence of process reads, repeating the last one.
private actor ResponseScript {
    private let responses: [TruoraProcessResponse]
    private(set) var reads = 0

    init(_ responses: [TruoraProcessResponse]) {
        self.responses = responses
    }

    func next() -> TruoraProcessResponse {
        defer { reads += 1 }
        return responses[min(reads, responses.count - 1)]
    }
}

/// Records the poll schedule instead of waiting it out.
private actor DelayRecorder {
    private(set) var values: [TimeInterval] = []

    func record(_ delay: TimeInterval) {
        values.append(delay)
    }
}
