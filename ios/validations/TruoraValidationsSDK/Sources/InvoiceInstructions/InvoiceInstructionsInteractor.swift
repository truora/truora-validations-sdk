//
//  InvoiceInstructionsInteractor.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 16/04/26.
//

import Foundation

class InvoiceInstructionsInteractor {
    weak var presenter: InvoiceInstructionsInteractorToPresenter?
    private var validationTask: Task<Void, Never>?
    private var uploadTask: Task<Void, Never>?
    private let country: String
    private let createValidationHandler: ((NativeValidationRequest) async throws -> NativeValidationCreateResponse)?
    private let uploadFileHandler: ((String, Data) async throws -> Void)?
    private let logger: TruoraLogger

    /// Constants for logging
    private static let viewName = "invoice_instructions"
    private static let validationType = "document_validation"

    init(
        presenter: InvoiceInstructionsInteractorToPresenter?,
        country: String,
        createValidationHandler: ((NativeValidationRequest) async throws -> NativeValidationCreateResponse)? = nil,
        uploadFileHandler: ((String, Data) async throws -> Void)? = nil,
        logger: TruoraLogger
    ) {
        self.presenter = presenter
        self.country = country
        self.createValidationHandler = createValidationHandler
        self.uploadFileHandler = uploadFileHandler
        self.logger = logger
    }

    deinit {
        validationTask?.cancel()
        uploadTask?.cancel()
    }
}

extension InvoiceInstructionsInteractor: InvoiceInstructionsPresenterToInteractor {
    func createValidation(accountId: String, retryOfId: String?) {
        validationTask?.cancel()
        validationTask = Task { [weak self] in
            guard let self else { return }
            do {
                let response = try await self.performValidationRequest(
                    accountId: accountId,
                    retryOfId: retryOfId
                )
                guard !Task.isCancelled else {
                    debugLog("⚠️ InvoiceInstructionsInteractor: Task was cancelled")
                    return
                }
                await self.notifySuccess(response: response)
            } catch is CancellationError {
                debugLog("⚠️ InvoiceInstructionsInteractor: Task was cancelled")
            } catch {
                await self.notifyFailure(error: error)
            }
        }
    }

    func uploadFile(uploadUrl: String, fileData: Data, contentType: String) {
        uploadTask?.cancel()
        uploadTask = Task { [weak self] in
            guard let self else { return }
            do {
                if let uploadFileHandler = self.uploadFileHandler {
                    try await uploadFileHandler(uploadUrl, fileData)
                } else {
                    guard let apiClient = ValidationConfig.shared.apiClient else {
                        throw TruoraException.sdk(
                            SDKError(type: .invalidConfiguration, details: "API client not configured")
                        )
                    }
                    try await apiClient.uploadFile(
                        uploadUrl: uploadUrl,
                        fileData: fileData,
                        contentType: contentType
                    )
                }

                guard !Task.isCancelled else { return }
                await self.presenter?.fileUploadCompleted()
            } catch is CancellationError {
                debugLog("⚠️ InvoiceInstructionsInteractor: Upload task was cancelled")
            } catch {
                guard !Task.isCancelled else { return }
                let truoraError: TruoraException = if let existing = error as? TruoraException {
                    existing
                } else {
                    .sdk(
                        SDKError(type: .uploadFailed, details: error.localizedDescription)
                    )
                }
                await self.presenter?.fileUploadFailed(truoraError)
            }
        }
    }

    // MARK: - Logging Methods

    func logViewRendered() async {
        await logger.logView(
            viewName: "render_\(Self.viewName)_succeeded",
            level: .info,
            retention: .oneWeek,
            metadata: [
                "name": Self.viewName,
                "validation_type": Self.validationType
            ]
        )
    }

    func logUploadFileButtonClicked() async {
        await logger.logView(
            viewName: "upload_file_button_clicked",
            level: .info,
            retention: .oneWeek,
            metadata: [
                "name": Self.viewName,
                "validation_type": Self.validationType,
                "selected_country": country,
                "input_method": "file_upload"
            ]
        )
    }

    func logTakePhotoButtonClicked() async {
        await logger.logView(
            viewName: "take_photo_button_clicked",
            level: .info,
            retention: .oneWeek,
            metadata: [
                "name": Self.viewName,
                "validation_type": Self.validationType,
                "selected_country": country,
                "input_method": "camera"
            ]
        )
    }

    func logCancelButtonClicked() async {
        await logger.logView(
            viewName: "cancel_button_clicked",
            level: .info,
            retention: .oneWeek,
            metadata: [
                "name": Self.viewName,
                "validation_type": Self.validationType
            ]
        )
    }

    func logPickerCancelled() async {
        await logger.logView(
            viewName: "picker_cancelled",
            level: .info,
            retention: .oneWeek,
            metadata: [
                "name": Self.viewName,
                "validation_type": Self.validationType
            ]
        )
    }
}

// MARK: - Private Helpers

private extension InvoiceInstructionsInteractor {
    func buildRequest(accountId: String, retryOfId: String?) -> NativeValidationRequest {
        let invoiceConfig = ValidationConfig.shared.invoiceConfig

        return NativeValidationRequest(
            type: NativeValidationTypeEnum.documentValidation.rawValue,
            country: country.lowercased(),
            accountId: accountId,
            threshold: nil,
            subvalidations: nil,
            documentType: NativeDocumentType.invoice.rawValue,
            timeout: invoiceConfig.timeout,
            userAuthorized: true,
            checkManualReviewAvailability: true,
            retryOfId: retryOfId
        )
    }

    func performValidationRequest(
        accountId: String,
        retryOfId: String?
    ) async throws -> NativeValidationCreateResponse {
        let request = buildRequest(accountId: accountId, retryOfId: retryOfId)
        debugLog("🟢 InvoiceInstructions: Creating validation for account: account=\(accountId)")
        debugLog(
            "🟢 InvoiceInstructions: country=\(country.lowercased()) "
                + "documentType=invoice retryOfId=\(retryOfId ?? "nil")"
        )

        if let createValidationHandler {
            return try await createValidationHandler(request)
        }

        guard let apiClient = ValidationConfig.shared.apiClient else {
            throw TruoraException.sdk(SDKError(type: .invalidConfiguration, details: "API client not configured"))
        }

        return try await apiClient.createValidation(request: request)
    }

    func notifySuccess(response: NativeValidationCreateResponse) async {
        debugLog("🟢 InvoiceInstructions: Validation created - ID: \(response.validationId)")
        guard let presenter else {
            debugLog("⚠️ InvoiceInstructions: Presenter deallocated before result")
            return
        }
        await presenter.validationCreated(response: response)
    }

    func notifyFailure(error: Error) async {
        debugLog("❌ InvoiceInstructions: Validation creation failed: \(error)")
        if let truoraError = error as? TruoraException {
            await presenter?.validationFailed(truoraError)
        } else {
            await presenter?.validationFailed(
                .network(message: "Failed to create validation: \(error.localizedDescription)")
            )
        }
    }
}
