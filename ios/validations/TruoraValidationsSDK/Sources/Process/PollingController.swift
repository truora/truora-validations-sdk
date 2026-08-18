//
//  PollingController.swift
//  TruoraValidationsSDK
//

import Foundation

// MARK: - Step Decision

/// What the runner should do with the step it just submitted.
///
/// Mirrors the outcomes of the web runner's `handleValidateResponse`, which
/// collapses them into a single "stop polling" boolean plus a side effect.
enum StepDecision: Equatable {
    /// The backend moved on; render whatever step is now current.
    case advance

    /// The step failed but the user may try again.
    case retry

    /// The process itself resolved; nothing is left to drive.
    case terminal

    /// The step never resolved within `MAX_POLLING_TIME`. Distinct from
    /// ``terminal``: the process is still pending, so the loop must stop on its
    /// own rather than re-read and spin.
    case timedOut

    /// The step has not resolved yet.
    case keepPolling
}

// MARK: - Poll Outcome

/// The decision plus the process read that produced it, so the caller can
/// inspect the resolved step (for a retry reason) without re-reading.
struct PollOutcome {
    let decision: StepDecision
    let process: TruoraProcessResponse
}

// MARK: - Polling Controller

/// Polls `readProcess` until the step the runner just submitted resolves.
///
/// The backend, not the SDK, decides when a step is done: the SDK re-reads the
/// process and compares it against the snapshot taken *before* `verifyStep`.
struct PollingController {
    /// Suspending delay between polls. Injectable so tests can assert the poll
    /// schedule — notably the 300s timeout — without real waiting.
    private let sleep: (TimeInterval) async throws -> Void

    init(
        sleep: @escaping (TimeInterval) async throws -> Void = { seconds in
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        }
    ) {
        self.sleep = sleep
    }

    /// Re-reads the process until the step at `previousStepIndex` resolves.
    ///
    /// - Parameters:
    ///   - previousStepIndex: `current_step` as it was *before* `verifyStep`. The
    ///     submitted step is looked up positionally with this index, against the
    ///     freshly read `steps`.
    ///   - readProcess: performs one `GET /v1/processes/{id}`.
    /// - Throws: `CancellationError` if the surrounding task is cancelled, or
    ///   whatever `readProcess` throws.
    func pollUntilResolved(
        previousStepIndex: Int,
        readProcess: () async throws -> TruoraProcessResponse
    ) async throws -> PollOutcome {
        var pollCount = 0

        while true {
            try Task.checkCancellation()

            let response = try await readProcess()
            let decision = Self.decide(
                response: response,
                previousStepIndex: previousStepIndex,
                pollCount: pollCount
            )

            guard decision == .keepPolling else {
                return PollOutcome(decision: decision, process: response)
            }

            pollCount += 1
            try await sleep(ProcessRunnerConstants.pollDelay)
        }
    }

    /// Classifies a freshly read process against the step that was submitted.
    ///
    /// Ported case-for-case from `handleValidateResponse`. The submitted step is
    /// `response.steps[previousStepIndex]`, and its outcome lives in that step's
    /// `verification_output.status`.
    static func decide(
        response: TruoraProcessResponse,
        previousStepIndex: Int,
        pollCount: Int
    ) -> StepDecision {
        let submitted = response.step(at: previousStepIndex)
        let stepChanged = hasStepChanged(response, previousStepIndex: previousStepIndex)
        let processFinished = response.status != .pending

        // The web runner returns a single "stop" boolean here; `advance` and
        // `terminal` are the two ways it can be true.
        let stop: StepDecision = {
            if processFinished {
                return .terminal
            }

            return stepChanged ? .advance : .keepPolling
        }()

        switch submitted?.output?.status {
        case .success:
            return stop

        case .failure:
            // A failure the user can still recover from never advances the loop.
            if (submitted?.remainingRetries ?? 0) > 0 {
                return .retry
            }

            return stop

        case .pending, .none:
            // An async step whose retries are spent has handed off to the backend;
            // once the process moved on there is nothing left to wait for.
            if isResolvedAsyncStep(submitted, stepChanged: stepChanged) {
                return stop
            }

            return hasTimedOut(pollCount: pollCount) ? .timedOut : .keepPolling
        }
    }

    /// `hasStepChanged` — the backend advanced to a step that actually exists.
    private static func hasStepChanged(_ response: TruoraProcessResponse, previousStepIndex: Int) -> Bool {
        response.currentStepIndex != previousStepIndex
            && response.currentStepIndex < (response.steps?.count ?? 0)
    }

    /// The `async_step` clause of `mustIgnoreCurrentStepPending`. The step types the
    /// web runner also special-cases there (email/phone codes, geolocation,
    /// signature) are outside the SDK's v1 step set.
    private static func isResolvedAsyncStep(_ step: TruoraStep?, stepChanged: Bool) -> Bool {
        step?.asyncStep == true && (step?.remainingRetries ?? 0) == 0 && stepChanged
    }

    /// `pollingCount * DELAY >= MAX_POLLING_TIME`.
    private static func hasTimedOut(pollCount: Int) -> Bool {
        ProcessRunnerConstants.hasExhaustedPollingBudget(pollCount: pollCount)
    }
}
