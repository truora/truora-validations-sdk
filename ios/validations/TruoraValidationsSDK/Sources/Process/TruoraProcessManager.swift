//
//  TruoraProcessManager.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 07/07/26.
//

import Foundation

// MARK: - DI Process Manager

/// Owns the lifecycle of a Digital Identity process and exposes it as an event
/// stream. Native Swift mirror of the KMP process runner (PROC-6965); its shape and
/// event semantics are kept 1:1 so the two stay in lockstep. Type *names* follow iOS
/// conventions (see docs/08_coding_standards.md) and deliberately differ from KMP's.
///
/// Scope: state model + lifecycle entry (``start()`` / ``cancel()``) + the public
/// event/error surface + create-or-read + the step loop (PROC-6971) + finalization
/// (PROC-6973): once the loop resolves, the manager waits on the risk evaluation
/// when the flow has get-results, then emits a
/// ``ProcessEvent/blockCompleted(_:)`` per block followed by
/// ``ProcessEvent/processCompleted(_:)``. This type is currently consumed by
/// nothing; existing SDK behavior is unchanged.
///
/// **Lifetime / retention contract:** the caller must retain the manager for the
/// duration of the process — it is the object the host holds (the `process`
/// returned by the builder). The lifecycle task is `[weak self]`, but once a run
/// is in flight `guard let self` keeps the manager alive until the run reaches a
/// terminal outcome; the host stops an in-flight run with ``cancel()``, not by
/// releasing the manager. This is a bounded self-retention (broken when the run
/// finishes or ``cancel()`` clears the task), not a leak. (The KMP equivalent is
/// the injected `CoroutineScope`'s lifetime bounding the runner.)
///
/// Modelled as an `actor` (matching ``SdkLogClient`` / ``TruoraLoggerImplementation``)
/// so the internal process state is race-free across the lifecycle task.
actor TruoraProcessManager {
    // MARK: Dependencies

    private let apiClient: TruoraProcessAPIClient
    private let executor: TruoraProcessRequestExecutor
    /// Classifies thrown transport errors into ``TruoraProcessApiError`` (used on the throw
    /// path of ``createOrRead()``). Injectable as a type so tests can substitute a
    /// mapper without a signature change.
    private let errorMapper: TruoraProcessErrorMapper.Type
    /// Supplies captured input per step. Until the capture screens are adapted
    /// (PROC-6974/6975) nothing provides one, and the manager stops after
    /// create-or-read.
    private let inputProvider: StepInputProviding?
    /// Fetches the `enter_authorization` consent terms from the Account API.
    /// Optional so tests (and hosts that never render the authorization screen)
    /// can skip the prefetch entirely.
    private let consentLoader: AuthorizationConsentLoader?
    /// Suspending delay between risk-evaluation re-reads during finalization.
    /// Injectable so tests can drive the wait — notably its 300s budget — without
    /// real waiting, matching ``PollingController``.
    private let sleep: (TimeInterval) async throws -> Void
    /// Emits DI process lifecycle telemetry. `nil` by default; ``logLifecycle(_:level:errorMessage:extra:)``
    /// falls back to `TruoraLoggerImplementation.shared` and simply skips the log
    /// if that isn't initialized yet, matching how the rest of the SDK treats
    /// logging as best-effort rather than a hard dependency.
    private let logger: TruoraLogger?

    // MARK: Event surface

    /// Stream of lifecycle events. The runner communicates exclusively through
    /// this; callers `for await` it to observe progress. The stream finishes on a
    /// terminal outcome (cancel, or later completion/error).
    ///
    /// Interim behavior (until finalization, PROC-6973): when the process resolves
    /// normally the stream simply **finishes without a preceding terminal event** —
    /// consumers observe completion as the stream ending, not as a
    /// ``ProcessEvent/processCompleted(_:)``. Only cancel and failure emit an event
    /// before finishing.
    nonisolated let events: AsyncStream<ProcessEvent>
    private let continuation: AsyncStream<ProcessEvent>.Continuation

    // MARK: Internal state

    /// The process as last read from / created by the backend.
    private var process: TruoraProcessResponse?
    /// The active process id, once create-or-read has resolved one. Retained for
    /// backend cancellation (PROC-6973).
    private var processId: String?
    /// Blocks that have reached a terminal state, accumulated across the
    /// (future) step loop.
    private var completedBlocks: [TruoraBlock] = []
    /// The in-flight lifecycle task, retained so ``cancel()`` can stop it.
    private var lifecycleTask: Task<Void, Never>?
    /// The in-flight consent-terms prefetch, kicked off the moment create-or-read
    /// resolves a process with an `enter_authorization` step — the copy must be
    /// resolving while earlier UI is still on screen, not from step entry.
    /// `nil` result means the prefetch was cancelled.
    private var consentFetchTask: Task<AuthorizationTermsFetchOutcome?, Never>?
    /// Whether a terminal outcome (completion, error or cancel) has already been
    /// emitted. Guards the terminal event + `finish()` so exactly one outcome
    /// reaches the stream when finalization and ``cancel()`` race.
    private var isTerminated = false

    // MARK: Init

    /// - Parameter executor: defaults to the **process-runner** retry policy (five
    ///   attempts, 0.5s/1s/2s/4s), not ``TruoraRetryPolicy/default``.
    init(
        apiClient: TruoraProcessAPIClient,
        executor: TruoraProcessRequestExecutor = TruoraProcessRequestExecutor(
            retryPolicy: ProcessRunnerConstants.retryPolicy
        ),
        errorMapper: TruoraProcessErrorMapper.Type = TruoraProcessErrorMapper.self,
        inputProvider: StepInputProviding? = nil,
        consentLoader: AuthorizationConsentLoader? = nil,
        sleep: @escaping (TimeInterval) async throws -> Void = { seconds in
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        },
        logger: TruoraLogger? = nil
    ) {
        self.apiClient = apiClient
        self.executor = executor
        self.errorMapper = errorMapper
        self.inputProvider = inputProvider
        self.consentLoader = consentLoader
        self.sleep = sleep
        self.logger = logger

        let (stream, continuation) = AsyncStream<ProcessEvent>.makeStream()
        self.events = stream
        self.continuation = continuation
    }

    // MARK: - Lifecycle

    /// Starts (or resumes) the process: runs create-or-read and populates internal
    /// state.
    ///
    /// Overlapping calls while a run is in flight are ignored. The manager drives a
    /// single process: after a terminal outcome (cancel, or later completion/error)
    /// the ``events`` stream finishes and the manager is single-use — build a new
    /// manager to run again. Outcomes flow through ``events``.
    func start() {
        guard lifecycleTask == nil else { return }

        lifecycleTask = Task { [weak self] in
            guard let self else { return }

            await self.createOrRead()
            // A failed create-or-read leaves `processId` nil and has already emitted
            // its terminal error, so the loop below is a no-op.
            await self.runStepLoop()
        }
    }

    /// Cancels the process: stops the lifecycle task, records the cancellation with
    /// the backend, then finishes the stream (terminal).
    ///
    /// The backend `POST /v1/processes/{id}/status` must land for the cancellation to
    /// be reported as ``ProcessEvent/processCanceled``; if it fails after the
    /// executor's retries, the mapped failure surfaces as
    /// ``ProcessEvent/processError(_:)`` instead — mirroring the web runner, which
    /// surfaces `identityCancel` errors rather than swallowing them. A missing
    /// ``processId`` (create-or-read never resolved) is a purely local cancel and
    /// skips the call. Emitting is guarded by ``claimTermination()`` so a cancel that
    /// races finalization is a no-op rather than a second terminal event.
    func cancel() {
        guard claimTermination() else {
            return // A terminal outcome already won; canceling is a no-op.
        }

        lifecycleTask?.cancel()
        lifecycleTask = nil
        consentFetchTask?.cancel()

        let processIdToCancel = processId
        Task { [weak self] in
            await self?.reportCancellation(processId: processIdToCancel)
        }
    }

    /// `POST`s the canceled status and emits the terminal outcome. Called only after
    /// ``cancel()`` has claimed termination, so it owns the final emission.
    private func reportCancellation(processId: String?) async {
        // No backend process to cancel — the cancel is purely local.
        guard let processId else {
            await logLifecycle("process_canceled")
            continuation.yield(.processCanceled)
            continuation.finish()
            return
        }

        let result: TruoraNetworkResult<TruoraProcessResponse>
        do {
            result = try await executor.execute { [apiClient] in
                try await apiClient.cancelProcess(
                    processId: processId,
                    request: TruoraCancelProcessRequest(failureStatus: .declined, declinedReason: "canceled")
                )
            }
        } catch is CancellationError {
            // The cancel POST was itself torn down; the caller still intended to
            // cancel, so report it as such.
            await logLifecycle("process_canceled")
            continuation.yield(.processCanceled)
            continuation.finish()
            return
        } catch {
            // `executor.execute` only ever throws `CancellationError` — API/transport
            // failures come back as `TruoraNetworkResult.failure` (handled below), never thrown.
            // This arm is therefore unreachable, but classifying any stray throw as an
            // error keeps a non-cancellation failure from masquerading as a cancel.
            continuation.yield(.processError(.from(errorMapper.from(error: error))))
            continuation.finish()
            return
        }

        switch result {
        case .success:
            await logLifecycle("process_canceled")
            continuation.yield(.processCanceled)
        case .failure(let apiError):
            await logLifecycle(
                "process_error",
                level: .error,
                errorMessage: apiError.localizedDescription,
                extra: ["s_error_type": errorType(.from(apiError))]
            )
            continuation.yield(.processError(.from(apiError)))
        }
        continuation.finish()
    }

    // MARK: - Create-or-Read

    /// Resolves the process by creating it (or reading the existing one for this
    /// token) and populates internal state.
    ///
    /// Flow-based create-or-read: the token authenticates the request (it is the DI
    /// flow token ``TruoraProcessAPIClient`` is configured with) and the backend derives the
    /// flow and its blocks from it
    private func createOrRead() async {
        let result: TruoraNetworkResult<CreateOrReadResult>
        do {
            result = try await executor.execute { [apiClient] in
                try await apiClient.createOrRead()
            }
        } catch is CancellationError {
            return // Cancellation is not an error; `cancel()` already emitted + finished.
        } catch {
            emitTerminalError(errorMapper.from(error: error))
            return
        }

        switch result {
        case .success(let outcome):
            // Success populates state only; emitting a result belongs to finalization
            // (PROC-6973). The stream stays open for the step loop.
            process = outcome.process
            processId = outcome.process.processId
            startConsentPrefetch(for: outcome.process)
            await logLifecycle(outcome.created ? "process_created" : "process_read")
        case .failure(let apiError):
            let mapped = ProcessError.from(apiError)
            guard claimTermination() else { return }
            await logLifecycle(
                "process_error",
                level: .error,
                errorMessage: logMessage(mapped),
                extra: ["s_error_type": errorType(mapped)]
            )
            yieldTerminalError(mapped)
        }
    }

    // MARK: - Step Loop

    /// Drives the per-step loop until the process resolves or fails.
    ///
    /// Without an ``inputProvider`` there is no way to capture a step, so the
    /// manager stops after create-or-read and leaves the stream open.
    private func runStepLoop() async {
        guard let inputProvider, let processId else { return }

        let outcome: StepLoopOutcome
        do {
            // The host may have canceled between create-or-read and here; bail before
            // issuing the loop's first API call rather than waiting for its first await.
            try Task.checkCancellation()

            let loop = StepLoop(apiClient: apiClient, executor: executor, inputProvider: inputProvider, logger: logger)
            outcome = try await loop.run(processId: processId) { [continuation] event in
                continuation.yield(event)
            }
        } catch is CancellationError {
            // `cancel()` already emitted `.processCanceled` and finished the stream, so
            // finishing again is a no-op. Doing it unconditionally guarantees the stream
            // still closes if the CancellationError came from somewhere other than
            // `cancel()` (e.g. the inputProvider).
            continuation.finish()
            return
        } catch {
            let mapped = ProcessError.from(errorMapper.from(error: error))
            guard claimTermination() else { return }
            await logLifecycle(
                "process_error",
                level: .error,
                errorMessage: logMessage(mapped),
                extra: ["s_error_type": errorType(mapped)]
            )
            yieldTerminalError(mapped)
            return
        }

        switch outcome {
        case .finished(let resolved):
            process = resolved
            await finalize(resolved)
        case .failed(let error):
            guard claimTermination() else { return }
            await logLifecycle(
                "process_error",
                level: .error,
                errorMessage: logMessage(error),
                extra: ["s_error_type": errorType(error)]
            )
            yieldTerminalError(error)
        }
    }

    // MARK: - Finalization

    /// Resolves the finished process into a ``ProcessResult`` and emits it.
    ///
    /// Waits for the process to resolve first (a no-op unless the flow has
    /// get-results), then emits one ``ProcessEvent/blockCompleted(_:)`` per
    /// block — in the ``ProcessResult/blocks`` order — before the
    /// terminal ``ProcessEvent/processCompleted(_:)``. A failure of the wait is
    /// classified to ``ProcessError`` rather than thrown raw; cancellation is silent
    /// because ``cancel()`` already emitted.
    private func finalize(_ snapshot: TruoraProcessResponse) async {
        let resolved: TruoraProcessResponse
        do {
            resolved = try await waitForResults(snapshot)
        } catch is CancellationError {
            return // `cancel()` already emitted + finished.
        } catch let apiError as TruoraProcessApiError {
            let mapped = ProcessError.from(apiError)
            guard claimTermination() else { return }
            await logLifecycle(
                "process_error",
                level: .error,
                errorMessage: logMessage(mapped),
                extra: ["s_error_type": errorType(mapped)]
            )
            yieldTerminalError(mapped)
            return
        } catch {
            let mapped = ProcessError.from(errorMapper.from(error: error))
            guard claimTermination() else { return }
            await logLifecycle(
                "process_error",
                level: .error,
                errorMessage: logMessage(mapped),
                extra: ["s_error_type": errorType(mapped)]
            )
            yieldTerminalError(mapped)
            return
        }

        process = resolved

        guard claimTermination() else {
            // A `cancel()` that landed between `waitForResults` returning and here has
            // already claimed the single terminal outcome, so it owns emitting
            // `.processCanceled` + `finish()`. Emitting the completion now would be a
            // second terminal event on the stream, so finalization simply yields.
            return
        }

        let result = resolved.toResult()
        var completedExtra: [String: Any] = [
            "i_block_count": result.blocks.count,
            "b_has_risk": result.risk != nil
        ]
        if let status = resolved.status?.rawValue {
            completedExtra["s_status"] = status
        }
        await logLifecycle("process_completed", extra: completedExtra)
        for block in result.blocks {
            continuation.yield(.blockCompleted(block))
        }
        continuation.yield(.processCompleted(result))
        continuation.finish()
    }

    #if DEBUG

    // MARK: - Test hooks (DEBUG only)

    /// Awaits the in-flight lifecycle task, if any, so tests can deterministically
    /// assert post-run state.
    func awaitCurrentRun() async {
        await lifecycleTask?.value
    }

    /// The process id resolved by the last create-or-read, for test assertions.
    var resolvedProcessId: String? {
        processId
    }
    #endif
}

// MARK: - Authorization Consents

/// Consent-terms prefetch + read-back. Kept in an extension so they don't count
/// toward `type_body_length` on the actor.
extension TruoraProcessManager {
    /// The hydrated consents for the `enter_authorization` screen, in
    /// `languageCode` (`es` / `en` / `pt`, regional variants like `es-MX` fall
    /// back to their base language).
    ///
    /// Awaiting this **is** the loading state: the prefetch started when the
    /// process response landed, and this suspends until it resolves — the host
    /// (PROC-6967) shows its loading UI around the `await`. Returns `nil` when
    /// there is nothing to wait for (no loader configured, no
    /// `enter_authorization` step, or the prefetch was cancelled), and
    /// ``TruoraNetworkResult/failure(_:)`` when a required terms fetch failed after
    /// retries — the copy is legally binding, so there is no local fallback.
    func authorizationConsents(languageCode: String) async -> TruoraNetworkResult<[AuthorizationConsent]>? {
        guard let consentFetchTask, let outcome = await consentFetchTask.value else {
            return nil
        }

        return outcome.consents(languageCode: languageCode)
    }

    /// Kicks off the consent-terms prefetch (PROC-7199) the moment the process
    /// response lands, so the copy resolves in parallel with whatever renders
    /// before the authorization screen. No-op without a loader or when the
    /// process has no `enter_authorization` step.
    private func startConsentPrefetch(for process: TruoraProcessResponse) {
        guard
            consentFetchTask == nil,
            let consentLoader,
            let step = process.steps?.first(where: { $0.type == .enterAuthorization }) else {
            return
        }

        let blockTypes = process.identityBlockTypes
        // The web resolves the consent variant against the geo-IP country, not the
        // process's configured country — `deviceInfo.location.country` is seeded
        // from `geolocation_ip_country`. Fall back to `country` when the backend
        // omits it (no IP match), which is still better than no signal at all.
        let deviceCountry = process.geolocationIpCountry ?? process.country
        consentFetchTask = Task {
            // `load` throws `CancellationError` only; a cancelled prefetch
            // resolves to `nil` and `authorizationConsents` reports nothing.
            try? await consentLoader.load(
                step: step,
                blockTypes: blockTypes,
                deviceCountry: deviceCountry
            )
        }
    }
}

// MARK: - Result Polling

/// Get-results re-read helpers backing ``TruoraProcessManager/finalize(_:)``. Kept in
/// an extension so they don't count toward `type_body_length` on the actor.
private extension TruoraProcessManager {
    /// Re-reads the process until it is no longer `pending`, bounded by
    /// ``ProcessRunnerConstants/maxPollingTime``.
    ///
    /// Get-results flows resolve asynchronously: the step loop finishes (there is no
    /// step left to render) while the process itself is still `pending`, so the SDK
    /// must keep reading until the backend settles it. This mirrors the web runner's
    /// `handleValidateResponse`, whose stop signal is `processFinished =
    /// response.status !== 'pending'` — the *process* status, not the risk status.
    /// (Risk being pending is naturally subsumed: while risk is pending the process
    /// is too, but risk may also be absent/not-yet-created, which the process status
    /// still reflects.) When the budget is spent the still-pending snapshot is
    /// resolved as-is rather than failed — the process ran its course.
    ///
    /// Non-get-results flows already come back resolved (or with no step to render),
    /// so the snapshot passes through untouched.
    ///
    /// - Throws: `CancellationError`, or the ``TruoraProcessApiError`` a re-read fails with.
    func waitForResults(_ snapshot: TruoraProcessResponse) async throws -> TruoraProcessResponse {
        guard snapshot.hasGetResults else {
            return snapshot
        }

        var current = snapshot
        var pollCount = 0

        while current.status == .pending {
            guard !ProcessRunnerConstants.hasExhaustedPollingBudget(pollCount: pollCount) else {
                return current // Budget spent; resolve the pending snapshot as-is.
            }

            try Task.checkCancellation()
            try await sleep(ProcessRunnerConstants.pollDelay)
            current = try await readProcess(processId ?? current.processId)
            pollCount += 1
        }

        return current
    }

    /// `GET /v1/processes/{id}` through the executor, unwrapping a failed
    /// ``TruoraNetworkResult`` into a thrown ``TruoraProcessApiError`` so ``finalize(_:)`` classifies once.
    func readProcess(_ processId: String) async throws -> TruoraProcessResponse {
        let result = try await executor.execute { [apiClient] in
            try await apiClient.readProcess(processId: processId)
        }

        switch result {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }
}

// MARK: - Logging

/// Lifecycle logging helpers. Kept in an extension so they don't count toward
/// `type_body_length` on the actor.
private extension TruoraProcessManager {
    /// Type-prefixed context for a process log. `account_id` / `validation_id`
    /// are injected by the logger from `ValidationConfig`, so only process-scoped
    /// keys are added here.
    func processMetadata() -> [String: Any] {
        var metadata: [String: Any] = [:]
        if let processId {
            metadata["s_process_id"] = processId
        }
        if let process {
            if let stepId = process.currentStepId {
                metadata["s_current_step_id"] = stepId
            }
            if let stepType = process.currentStepType {
                metadata["s_current_step_type"] = stepType.rawValue
            }
            metadata["i_current_step"] = process.currentStepIndex
            if let flowId = process.flowId {
                metadata["s_flow_id"] = flowId
            }
            if let clientId = process.clientId {
                metadata["s_client_id"] = clientId
            }
            if let status = process.status {
                metadata["s_status"] = status.rawValue
            }
        }
        return metadata
    }

    /// Emits a lifecycle log through the injected logger, falling back to the
    /// shared instance when none was injected. A no-op if neither is available
    /// (e.g. SDK logging hasn't been initialized), since logging must never fail
    /// the process.
    func logLifecycle(
        _ eventName: String,
        level: LogLevel = .info,
        errorMessage: String? = nil,
        extra: [String: Any] = [:]
    ) async {
        guard let logger = logger ?? (try? TruoraLoggerImplementation.shared) else {
            return
        }

        var metadata = processMetadata()
        for (key, value) in extra {
            metadata[key] = value
        }
        await logger.logSdk(
            eventName: eventName,
            level: level,
            errorMessage: errorMessage,
            retention: .oneMonth,
            metadata: metadata
        )
    }

    /// Short, stable identifier for a `ProcessError`, used as `s_error_type`.
    func errorType(_ error: ProcessError) -> String {
        switch error {
        case .unsupportedFlow: "unsupported_flow"
        case .tokenExpired: "token_expired"
        case .processExpired: "process_expired"
        case .network: "network"
        case .mediaUploadFailed: "media_upload_failed"
        case .stepTimedOut: "step_timed_out"
        case .unknown: "unknown"
        }
    }

    /// Best-effort human-readable detail for an error log — mirrors KMP's
    /// `ProcessError.logMessage()` for consistent Kibana debugging across platforms.
    func logMessage(_ error: ProcessError) -> String? {
        switch error {
        case .unsupportedFlow(let stepType): stepType
        case .mediaUploadFailed(let reason): reason
        case .stepTimedOut(let stepType): stepType
        case .unknown(let message): message
        case .network(let message): message
        case .tokenExpired, .processExpired: nil
        }
    }
}

// MARK: - Terminal Emission

private extension TruoraProcessManager {
    /// Emits the mapped error as a terminal ``ProcessEvent/processError(_:)``.
    func emitTerminalError(_ apiError: TruoraProcessApiError) {
        emitTerminal(.from(apiError))
    }

    /// Emits `error` and finishes the stream (an error is terminal), so `for await`
    /// consumers observe the failure and then complete. Guarded so it never races a
    /// second terminal outcome onto the stream.
    func emitTerminal(_ error: ProcessError) {
        guard claimTermination() else {
            return
        }
        yieldTerminalError(error)
    }

    /// Yields `error` as terminal and finishes the stream. The caller MUST have
    /// already claimed the terminal outcome via ``claimTermination()`` — used by
    /// error sites that claim first so their `process_error` log is never written
    /// for an outcome a racing `cancel()` already owns.
    func yieldTerminalError(_ error: ProcessError) {
        continuation.yield(.processError(error))
        continuation.finish()
    }

    /// Claims the single terminal outcome. Returns `true` for the first caller
    /// (which then owns emitting the terminal event + `finish()`), `false` for every
    /// later one.
    func claimTermination() -> Bool {
        guard !isTerminated else {
            return false
        }

        isTerminated = true
        return true
    }
}
