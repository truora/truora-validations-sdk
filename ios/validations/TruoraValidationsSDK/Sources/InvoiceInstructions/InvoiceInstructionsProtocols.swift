//
//  InvoiceInstructionsProtocols.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 16/04/26.
//

import Foundation

// MARK: - View to Presenter

protocol InvoiceInstructionsViewToPresenter: AnyObject {
    func viewDidLoad() async
    func uploadFileTapped() async
    func takePhotoTapped() async
    func cancelTapped() async
    /// Called by the router delegate when the user picks a file or takes a photo.
    func fileSelected(data: Data, contentType: String) async
    /// Called by the router delegate when the user cancels the picker/camera.
    func pickerCancelled() async
    /// Called by the router delegate when a file could not be read or exceeds the size limit.
    func fileSelectionFailed(message: String) async
}

// MARK: - Presenter to View

/// Protocol for updating the invoice intro view.
/// Implementations should ensure UI updates are performed on the main thread.
@MainActor protocol InvoiceInstructionsPresenterToView: AnyObject {
    func showLoading()
    func hideLoading()
    func showError(_ message: String)
}

// MARK: - Presenter to Interactor

protocol InvoiceInstructionsPresenterToInteractor: AnyObject {
    /// Creates a validation. Pass `retryOfId` to chain onto a previously failed validation
    /// (see backend `retry_of_id` contract) — the response inherits the decremented
    /// `remaining_retries` from the original and gives a fresh upload URL.
    func createValidation(accountId: String, retryOfId: String?)
    func uploadFile(uploadUrl: String, fileData: Data, contentType: String)
    func logViewRendered() async
    func logUploadFileButtonClicked() async
    func logTakePhotoButtonClicked() async
    func logCancelButtonClicked() async
    func logPickerCancelled() async
}

// MARK: - Interactor to Presenter

protocol InvoiceInstructionsInteractorToPresenter: AnyObject {
    func validationCreated(response: NativeValidationCreateResponse) async
    func validationFailed(_ error: TruoraException) async
    func fileUploadCompleted() async
    func fileUploadFailed(_ error: TruoraException) async
}
