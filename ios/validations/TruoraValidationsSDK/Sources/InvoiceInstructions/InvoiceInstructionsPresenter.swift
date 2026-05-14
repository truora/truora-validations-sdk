//
//  InvoiceInstructionsPresenter.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 16/04/26.
//

import Foundation

class InvoiceInstructionsPresenter {
    weak var view: InvoiceInstructionsPresenterToView?
    var interactor: InvoiceInstructionsPresenterToInteractor?
    weak var router: ValidationRouter?

    /// Upload URL received from the backend after creating the validation.
    private var uploadUrl: String?

    /// Validation ID received from the backend.
    private var validationId: String?

    init(
        view: InvoiceInstructionsPresenterToView,
        interactor: InvoiceInstructionsPresenterToInteractor?,
        router: ValidationRouter
    ) {
        self.view = view
        self.interactor = interactor
        self.router = router
    }

    deinit {}
}

extension InvoiceInstructionsPresenter: InvoiceInstructionsViewToPresenter {
    func viewDidLoad() async {
        // Intentionally fired on every re-appear so telemetry captures how many times
        // a user lands on Instructions (e.g., via retry pops from feedback).
        await interactor?.logViewRendered()

        // Re-fired on every Instructions re-appear (see `InvoiceInstructionsViewModel.onAppear`).
        // A retry pending on the router means we landed here from a retriable failure — the
        // cached upload URL is now stale, so drop it and chain a new validation with
        // `retry_of_id`. Otherwise only create on first appearance (no uploadUrl yet).
        let hasPendingRetry = await MainActor.run { router?.pendingInvoiceRetryValidationId != nil }
        if hasPendingRetry {
            uploadUrl = nil
            validationId = nil
            await createValidation()
            return
        }
        if uploadUrl == nil {
            await createValidation()
        }
    }

    private func createValidation() async {
        guard let accountId = ValidationConfig.shared.accountId else {
            await view?.showError("Missing account ID")
            return
        }
        guard let interactor else {
            await view?.showError("Interactor not configured")
            return
        }
        // If the user is coming back from InvoiceFeedback after a retriable failure,
        // chain onto the previous validation so the backend preserves remaining_retries
        // and issues a fresh upload URL. The pending id is one-shot: clear it here so a
        // subsequent re-appear (without a new failure) creates a brand-new validation.
        let retryOfId = await MainActor.run { () -> String? in
            let id = router?.pendingInvoiceRetryValidationId
            router?.pendingInvoiceRetryValidationId = nil
            return id
        }
        await view?.showLoading()
        interactor.createValidation(accountId: accountId, retryOfId: retryOfId)
    }

    func uploadFileTapped() async {
        await interactor?.logUploadFileButtonClicked()
        guard let router else {
            debugLog("⚠️ InvoiceInstructionsPresenter: uploadFileTapped with nil router")
            return
        }
        await router.presentInvoiceFilePicker(presenter: self)
    }

    func takePhotoTapped() async {
        await interactor?.logTakePhotoButtonClicked()
        guard let router else {
            debugLog("⚠️ InvoiceInstructionsPresenter: takePhotoTapped with nil router")
            return
        }
        await router.presentInvoiceCamera(presenter: self)
    }

    func cancelTapped() async {
        await interactor?.logCancelButtonClicked()
        await router?.handleCancellation(loadingType: .invoice)
    }

    /// Handles a file/photo chosen by the user.
    ///
    /// - Important: `uploadUrl` and `validationId` are populated by `validationCreated`
    ///   before the loading overlay is hidden. Because `LoadingOverlayView` intercepts
    ///   all touches while `isLoading == true`, the upload/take-photo buttons cannot be
    ///   tapped until those values are ready — so the "missing URL" guards below are
    ///   only reachable via an unexpected protocol misuse.
    func fileSelected(data: Data, contentType: String) async {
        guard let uploadUrl, !uploadUrl.isEmpty else {
            await view?.showError("Missing upload URL")
            return
        }

        guard let interactor else {
            await view?.showError("Interactor not configured")
            return
        }

        // Check if upload URL has expired
        if UploadUrlValidator.isExpired(uploadUrl) {
            await view?.showError("Validation expired. The time limit was exceeded.")
            return
        }

        // Fire the upload and navigate straight to Result so the user sees a single
        // Verifying screen instead of a loading overlay on Instructions + Result's
        // own loading. If the upload fails, `fileUploadFailed` routes the error through
        // `router.handleError` so it surfaces on top of whichever screen is visible.
        interactor.uploadFile(uploadUrl: uploadUrl, fileData: data, contentType: contentType)

        guard let router, let validationId else {
            await view?.showError("Missing router or validation ID")
            return
        }

        // Stash a preview for InvoiceFeedback. PDFs are rasterized to PNG because the
        // feedback view renders via `UIImage(data:)`, which cannot decode PDF bytes.
        let previewData = InvoicePreviewGenerator.previewImageData(
            from: data,
            contentType: contentType
        )
        await MainActor.run { router.invoiceCapturedImageData = previewData }

        do {
            try await router.navigateToResult(
                validationId: validationId,
                loadingType: .invoice
            )
        } catch {
            await view?.showError(error.localizedDescription)
        }
    }

    func pickerCancelled() async {
        await interactor?.logPickerCancelled()
    }

    func fileSelectionFailed(message: String) async {
        await view?.showError(message)
    }
}

extension InvoiceInstructionsPresenter: InvoiceInstructionsInteractorToPresenter {
    func validationCreated(response: NativeValidationCreateResponse) async {
        let responseValidationId = response.validationId
        let frontUploadUrl = response.instructions?.frontUrl

        ValidationConfig.shared.updateValidationId(responseValidationId)

        guard let frontUploadUrl, !frontUploadUrl.isEmpty else {
            await view?.hideLoading()
            await view?.showError("Missing upload URL")
            return
        }

        self.uploadUrl = frontUploadUrl
        self.validationId = responseValidationId

        await view?.hideLoading()
    }

    func validationFailed(_ error: TruoraException) async {
        await view?.hideLoading()
        await router?.handleError(error)
    }

    func fileUploadCompleted() async {
        // Navigation to Result already happened from `fileSelected`; Result's polling
        // will transition to success/failure once the backend finishes processing.
    }

    func fileUploadFailed(_ error: TruoraException) async {
        // Pop Result off the stack so the user lands back on Instructions and can
        // retry the upload instead of getting ejected from the flow by `handleError`.
        await router?.popToInvoiceInstructions()
        await view?.showError(error.localizedDescription)
    }
}
