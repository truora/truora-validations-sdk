//
//  ResultPresenter.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 21/12/25.
//

import Foundation

final class ResultPresenter {
    weak var view: ResultPresenterToView?
    var interactor: ResultPresenterToInteractor?
    weak var router: ValidationRouter?

    private let validationId: String
    private let waitForResults: Bool
    private let finishViewConfig: FinishViewConfiguration?
    private let loadingType: ResultLoadingType
    private let timeProvider: TimeProvider
    private let isCanceled: Bool

    private var finalResult: ValidationResult?

    private var delegateCalled = false

    init(
        view: ResultPresenterToView,
        interactor: ResultPresenterToInteractor?,
        router: ValidationRouter,
        loadingType: ResultLoadingType,
        isCanceled: Bool = false,
        timeProvider: TimeProvider = RealTimeProvider()
    ) {
        self.view = view
        self.interactor = interactor
        self.router = router
        self.validationId = interactor?.validationId ?? ""
        self.loadingType = loadingType
        self.isCanceled = isCanceled
        self.timeProvider = timeProvider

        let configWaitForResults = switch loadingType {
        case .face: ValidationConfig.shared.faceConfig.waitForResults
        case .document: ValidationConfig.shared.documentConfig.waitForResults
        case .invoice: ValidationConfig.shared.invoiceConfig.waitForResults
        }

        self.finishViewConfig = switch loadingType {
        case .face: ValidationConfig.shared.faceConfig.finishViewConfig
        case .document: ValidationConfig.shared.documentConfig.finishViewConfig
        case .invoice: ValidationConfig.shared.invoiceConfig.finishViewConfig
        }

        self.waitForResults = configWaitForResults
    }

    deinit {
        interactor?.cancelPolling()
    }
}

// MARK: - ResultViewToPresenter

extension ResultPresenter: ResultViewToPresenter {
    func viewDidLoad() async {
        // Log view rendered
        await interactor?.logViewRendered()

        // Handle cancellation case - show failure immediately, skip polling.
        // Design decision: Show failure screen instead of immediate dismissal to provide
        // visual feedback that the validation was canceled. This matches the user expectation
        // that confirming cancellation leads to a definitive end state, not an abrupt dismissal.
        if isCanceled {
            let canceledResult = ValidationResult(
                validationId: validationId,
                status: .failure,
                confidence: nil,
                metadata: nil
            )
            finalResult = canceledResult
            await view?.showResult(canceledResult)
            return
        }

        if waitForResults {
            // Show loading and wait for result
            await view?.showLoading()
            interactor?.startPolling()
        } else {
            // Show completed immediately, poll in background
            await view?.showCompleted()
            interactor?.startPolling()
        }
    }

    func doneTapped() async {
        guard let router else {
            debugLog("⚠️ ResultPresenter: Router is nil, cannot dismiss flow")
            return
        }

        // Handle cancellation case - always return cancellation error
        if isCanceled {
            await router.dismissFlow()
            await notifyDelegateCancellation()
            return
        }

        if waitForResults {
            guard let result = finalResult else {
                debugLog("⚠️ ResultPresenter: Done tapped but no result yet")
                return
            }

            await router.dismissFlow()
            await notifyDelegate(with: result)
        } else {
            await router.dismissFlow()
            // If we have a result, use it (could be success/failure if polling finished)
            // If not, return a pending result
            let result = finalResult ?? ValidationResult(
                validationId: validationId,
                status: .pending,
                confidence: nil,
                metadata: nil
            )
            await notifyDelegate(with: result)
        }
    }
}

// MARK: - ResultInteractorToPresenter

extension ResultPresenter: ResultInteractorToPresenter {
    func pollingCompleted(result: ValidationResult) async {
        finalResult = result
        debugLog("🟢 ResultPresenter: Polling completed with status: \(result.status)")
        debugLog(
            "🟢 ResultPresenter: loadingType=\(loadingType) "
                + "validationStatus=\(result.detail?.validationStatus ?? "nil") "
                + "failureStatus=\(result.detail?.failureStatus ?? "nil")"
        )

        // Log SDK execution finished
        await interactor?.logSdkExecutionFinished()

        // Invoice feedback: show the retry screen only when the backend reports retries
        // remaining. When retries are exhausted the user drops to the generic result.
        if loadingType == .invoice, result.status == .failure {
            let remainingRetries = result.detail?.remainingRetries ?? 0
            let declinedReason = result.detail?.declinedReason
            debugLog(
                "🟢 ResultPresenter: Invoice failure detected. "
                    + "declinedReason=\(declinedReason ?? "nil") "
                    + "remainingRetries=\(remainingRetries)"
            )

            if remainingRetries > 0 {
                // If the router has been torn down (weak ref), optional chaining would
                // silently no-op and the user would see neither the feedback modal nor
                // the generic Result — explicit guard + fallback avoids that dead end.
                guard let router else {
                    debugLog("⚠️ ResultPresenter: Router is nil; falling back to generic result")
                    await view?.showResult(result)
                    return
                }

                let scenario = mapInvoiceDeclinedReason(declinedReason)
                let capturedImageData = await router.invoiceCapturedImageData
                // Stash the failed validation_id so the next createValidation on
                // Instructions can chain onto it via `retry_of_id` (new upload URL,
                // backend-tracked remaining_retries).
                await MainActor.run {
                    router.pendingInvoiceRetryValidationId = result.validationId
                }
                do {
                    try await router.navigateToInvoiceFeedback(
                        feedback: scenario,
                        capturedImageData: capturedImageData,
                        retriesLeft: remainingRetries,
                        retryBehavior: .popToInvoiceInstructions
                    )
                } catch {
                    debugLog("⚠️ ResultPresenter: Failed to show invoice feedback: \(error)")
                    await view?.showResult(result)
                }
                return
            }
        }

        guard waitForResults else {
            // UI is already showing "Completed", just notify delegate
            await notifyDelegate(with: result)
            return
        }

        if shouldAutoDismiss(for: result.status) {
            await router?.dismissFlow()
            await notifyDelegate(with: result)
            return
        }

        await view?.showResult(result)
    }

    func pollingFailed(error: TruoraException) async {
        debugLog("❌ ResultPresenter: Polling failed: \(error)")

        // Create a failed result for display purposes
        let failedResult = ValidationResult(
            validationId: validationId,
            status: .failure,
            confidence: nil,
            metadata: nil
        )
        finalResult = failedResult

        guard waitForResults else {
            await notifyDelegateError(error)
            return
        }

        if shouldAutoDismiss(for: .failure) {
            await router?.dismissFlow()
            await notifyDelegateError(error)
            return
        }

        await view?.showResult(failedResult)
    }
}

// MARK: - Private Methods

private extension ResultPresenter {
    /// Maps the backend-reported invoice `declined_reason` to a `FeedbackScenario`.
    /// Only `document_not_recognized` renders the "not found" design — any other
    /// reason (including missing/nil) falls back to the "missing text" design.
    func mapInvoiceDeclinedReason(_ declinedReason: String?) -> FeedbackScenario {
        switch declinedReason?.lowercased() {
        case "document_not_recognized": .documentNotRecognized
        default: .missingText
        }
    }

    func shouldAutoDismiss(for status: ValidationStatus) -> Bool {
        guard let config = finishViewConfig else { return false }
        switch status {
        case .success: return config.success == .hide
        case .failure: return config.failure == .hide
        case .pending: return false
        }
    }

    func notifyDelegate(with result: ValidationResult) async {
        guard !delegateCalled else {
            debugLog("⚠️ ResultPresenter: Delegate already called, skipping")
            return
        }
        delegateCalled = true

        // 100ms delay allows the dismiss animation to complete before notifying the delegate.
        // This prevents potential UI glitches where the host app reacts to the delegate
        // callback while the SDK's views are still animating out.
        try? await timeProvider.sleep(nanoseconds: 100_000_000)

        await MainActor.run {
            ValidationConfig.shared.delegate?(.completed(result))
        }
    }

    func notifyDelegateError(_ error: TruoraException) async {
        guard !delegateCalled else {
            debugLog("⚠️ ResultPresenter: Delegate already called, skipping")
            return
        }
        delegateCalled = true

        try? await timeProvider.sleep(nanoseconds: 100_000_000)

        await MainActor.run {
            ValidationConfig.shared.delegate?(.error(error))
        }
    }

    func notifyDelegateCancellation() async {
        guard !delegateCalled else {
            debugLog("⚠️ ResultPresenter: Delegate already called, skipping")
            return
        }
        delegateCalled = true

        // 100ms delay allows the dismiss animation to complete before notifying the delegate.
        // This prevents potential UI glitches where the host app reacts to the delegate
        // callback while the SDK's views are still animating out.
        try? await timeProvider.sleep(nanoseconds: 100_000_000)

        await MainActor.run {
            ValidationConfig.shared.delegate?(.canceled(nil))
        }
    }
}
