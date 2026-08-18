//
//  StepLoop.swift
//  TruoraValidationsSDK
//

import Foundation

// MARK: - Step Input

/// What a screen hands back once the user has completed a step.
struct StepInput {
    /// Values for the step's `expected_inputs`. Matched on type **and** name.
    let values: [TruoraStepInputValue]

    /// Captured media, keyed by the `files_upload_urls` entry it belongs to.
    let media: [String: StepMedia]

    init(values: [TruoraStepInputValue] = [], media: [String: StepMedia] = [:]) {
        self.values = values
        self.media = media
    }
}

/// Supplies the captured input for a routed step.
///
/// The loop does not know how a step is rendered; it asks for the input and
/// waits. Mounting the screens is the capture adaptation (PROC-6974/6975).
protocol StepInputProviding {
    /// Presents `routedStep` and resolves once the user has completed it.
    func input(for routedStep: RoutedStep) async throws -> StepInput
}

// MARK: - Step Loop Outcome

/// How the step loop stopped.
enum StepLoopOutcome {
    /// The process is no longer pending. Hand the snapshot to finalization
    /// (PROC-6973).
    case finished(TruoraProcessResponse)

    /// The loop cannot continue; the caller emits this error and stops.
    case failed(ProcessError)
}

// MARK: - Step Loop

/// Drives a Digital Identity process one step at a time.
///
/// The backend owns the sequence: the loop reads the process, renders whichever
/// step is current, submits what the user captured, then polls until the backend
/// says the step advanced, must be retried, or the process is done. Ported from
/// the web process-runner's `validate` / `performVerifyResponsePolling`.
struct StepLoop {
    private let apiClient: TruoraProcessAPIClient
    private let executor: TruoraProcessRequestExecutor
    private let router: StepTypeRouter
    private let uploader: MediaUploader
    private let inputProvider: StepInputProviding
    private let pollingController: PollingController
    /// Emits step-level telemetry. `nil` falls back to `TruoraLoggerImplementation.shared`,
    /// matching ``TruoraProcessManager``'s best-effort logging.
    private let logger: TruoraLogger?

    init(
        apiClient: TruoraProcessAPIClient,
        executor: TruoraProcessRequestExecutor,
        inputProvider: StepInputProviding,
        router: StepTypeRouter = StepTypeRouter(),
        uploader: MediaUploader? = nil,
        pollingController: PollingController = PollingController(),
        logger: TruoraLogger? = nil
    ) {
        self.apiClient = apiClient
        self.executor = executor
        self.router = router
        self.uploader = uploader ?? MediaUploader(apiClient: apiClient)
        self.inputProvider = inputProvider
        self.pollingController = pollingController
        self.logger = logger
    }

    /// Runs steps until the process resolves or the loop cannot continue.
    ///
    /// - Parameter emit: receives progress events (currently step retries) as the
    ///   loop makes them. Terminal outcomes come back as ``StepLoopOutcome``.
    /// - Throws: `CancellationError`, plus any error thrown by the `inputProvider`
    ///   that is neither ``TruoraProcessApiError`` nor ``MediaUploadError`` — the caller
    ///   (``TruoraProcessManager``) classifies those. Every ``TruoraProcessApiError`` and
    ///   ``MediaUploadError`` is folded into ``StepLoopOutcome/failed(_:)`` here.
    func run(processId: String, emit: (ProcessEvent) -> Void) async throws -> StepLoopOutcome {
        do {
            return try await drive(processId: processId, emit: emit)
        } catch let error as TruoraProcessApiError {
            return .failed(.from(error))
        } catch let error as MediaUploadError {
            return .failed(.from(error))
        }
    }

    // MARK: - Private

    private func drive(processId: String, emit: (ProcessEvent) -> Void) async throws -> StepLoopOutcome {
        while true {
            try Task.checkCancellation()

            let process = try await readProcess(processId)

            // A process that is no longer pending, or that has no step to render,
            // is done — finalization decides what its result is.
            guard process.status == .pending, let step = process.activeStep() else {
                return .finished(process)
            }

            let routed = router.route(step)
            guard routed.screen != .unsupported else {
                return .failed(.unsupportedFlow(stepType: step.type.rawValue))
            }

            var renderMeta = stepMetadata(process, step: step)
            renderMeta["s_screen"] = routed.screen.stableName
            await logStep("step_rendered", metadata: renderMeta)

            let input = try await inputProvider.input(for: routed)
            try await uploader.uploadAll(for: step, media: input.media)

            // Captured *before* verifying: polling compares the fresh reads against
            // the step index as it stood when the step was submitted.
            let submittedIndex = process.currentStepIndex

            await logStep("verify_submitted", metadata: stepMetadata(process, step: step))
            try await verifyStep(step.settingInputValues(input.values))

            let outcome = try await pollingController.pollUntilResolved(previousStepIndex: submittedIndex) {
                try await readProcess(processId)
            }

            switch outcome.decision {
            case .advance:
                await logStep("step_advanced", metadata: stepMetadata(outcome.process, step: step))
                continue

            case .retry:
                let retry = Self.retry(for: outcome.process, at: submittedIndex, step: step)
                await logStep("step_retry", metadata: retryMetadata(retry, process: outcome.process, step: step))
                emit(.stepRetry(retry))
                continue

            case .terminal:
                return .finished(outcome.process)

            case .timedOut:
                await logStep("process_timed_out", level: .error, metadata: stepMetadata(outcome.process, step: step))
                return .failed(.stepTimedOut(stepType: step.type.rawValue))

            case .keepPolling:
                // `pollUntilResolved` never returns this; it loops instead.
                return .failed(.unknown(message: "Polling ended without a decision"))
            }
        }
    }

    /// Builds the retry event from the step as the backend last reported it, so the
    /// screen shows the current decline reason and the decremented attempt count.
    private static func retry(for process: TruoraProcessResponse, at index: Int, step: TruoraStep) -> StepRetry {
        let resolved = process.step(at: index)

        return StepRetry(
            stepType: resolved?.type ?? step.type,
            declinedReason: resolved?.output?.declinedReason,
            remainingRetries: resolved?.remainingRetries ?? 0
        )
    }

    /// `GET /v1/processes/{id}`, with the runner's retry policy.
    private func readProcess(_ processId: String) async throws -> TruoraProcessResponse {
        let result = try await executor.execute { try await apiClient.readProcess(processId: processId) }

        return try Self.value(of: result)
    }

    /// `POST /v1/processes/steps/{step_id}`, submitting the filled step.
    private func verifyStep(_ step: TruoraStep) async throws {
        let result = try await executor.execute {
            try await apiClient.verifyStep(stepId: step.stepId, request: TruoraVerifyStepRequest(step: step))
        }

        // The verify response's `TruoraStep` is intentionally discarded: the loop treats
        // the re-read process (polled below) as the single source of truth for the
        // step's outcome. `value(of:)` is still called so an API failure throws here.
        _ = try Self.value(of: result)
    }

    /// Turns a ``TruoraNetworkResult`` failure into a thrown ``TruoraProcessApiError`` so `drive` can use
    /// `try` throughout and classify once, at the top.
    private static func value<T>(of result: TruoraNetworkResult<T>) throws -> T {
        switch result {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }
}

// MARK: - Logging

/// Step-level logging helpers. Kept in an extension so they don't count toward
/// `type_body_length` on the struct.
private extension StepLoop {
    /// Type-prefixed context shared by every step-level log.
    func stepMetadata(_ process: TruoraProcessResponse, step: TruoraStep?) -> [String: Any] {
        var metadata: [String: Any] = ["s_process_id": process.processId]
        if let step {
            metadata["s_step_id"] = step.stepId
            metadata["s_step_type"] = step.type.rawValue
        }
        metadata["i_current_step"] = process.currentStepIndex
        return metadata
    }

    /// Adds the retry-specific fields to ``stepMetadata(_:step:)``: the type and
    /// remaining attempts as the backend last reported them, plus the decline
    /// reason when it gave one.
    func retryMetadata(_ retry: StepRetry, process: TruoraProcessResponse, step: TruoraStep) -> [String: Any] {
        var metadata = stepMetadata(process, step: step)
        metadata["s_step_type"] = retry.stepType.rawValue
        metadata["i_remaining_retries"] = retry.remainingRetries
        if let reason = retry.declinedReason {
            metadata["s_declined_reason"] = reason
        }
        return metadata
    }

    /// Emits a step-level log through the injected logger, falling back to the
    /// shared instance when none was injected. A no-op if neither is available,
    /// since logging must never fail the step loop.
    func logStep(_ eventName: String, level: LogLevel = .info, metadata: [String: Any]) async {
        guard let logger = logger ?? (try? TruoraLoggerImplementation.shared) else {
            return
        }

        await logger.logSdk(
            eventName: eventName,
            level: level,
            errorMessage: nil,
            retention: .oneMonth,
            metadata: metadata
        )
    }
}
