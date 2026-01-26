//
//  DocumentIntroInteractor.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 23/12/25.
//

import Foundation
import TruoraShared

class DocumentIntroInteractor {
    weak var presenter: DocumentIntroInteractorToPresenter?
    private var validationTask: Task<Void, Never>?
    private let country: String
    private let documentType: String
    private let createValidationHandler: (([String: String]) async throws -> ValidationCreateResponse)?

    init(
        presenter: DocumentIntroInteractorToPresenter?,
        country: String,
        documentType: String,
        createValidationHandler: (([String: String]) async throws -> ValidationCreateResponse)? = nil
    ) {
        self.presenter = presenter
        self.country = country
        self.documentType = documentType
        self.createValidationHandler = createValidationHandler
    }

    deinit {
        validationTask?.cancel()
    }
}

extension DocumentIntroInteractor: DocumentIntroPresenterToInteractor {
    func createValidation(accountId: String) {
        validationTask?.cancel()
        validationTask = Task {
            do {
                let response = try await performValidationRequest(accountId: accountId)
                guard !Task.isCancelled else {
                    print("⚠️ DocumentIntroInteractor: Task was cancelled")
                    return
                }
                await notifySuccess(response: response)
            } catch is CancellationError {
                print("⚠️ DocumentIntroInteractor: Task was cancelled")
            } catch {
                await notifyFailure(error: error)
            }
        }
    }
}

// MARK: - Private Helpers

private extension DocumentIntroInteractor {
    func buildFormData(accountId: String) -> [String: String] {
        let request = TruoraShared.ValidationRequest(
            type: ValidationTypes.shared.DOCUMENT_VALIDATION,
            country: country.lowercased(),
            account_id: accountId,
            threshold: nil,
            subvalidations: nil,
            retry_of_id: nil,
            allowed_retries: nil,
            document_type: documentType,
            timeout: nil
        )
        return request.toFormData()
    }

    func performValidationRequest(accountId: String) async throws -> ValidationCreateResponse {
        let formData = buildFormData(accountId: accountId)
        print("🟢 DocumentIntro: Creating validation for account: account=\(accountId)")
        print("🟢 DocumentIntro: country=\(country.lowercased()) documentType=\(documentType)")

        if let createValidationHandler {
            return try await createValidationHandler(formData)
        }

        guard let apiClient = ValidationConfig.shared.apiClient else {
            throw ValidationError.apiError("API client not configured")
        }

        let response = try await apiClient.validations.createValidation(formData: formData)
        return try await SwiftKTORHelper.parseResponse(response, as: ValidationCreateResponse.self)
    }

    @MainActor
    func notifySuccess(response: ValidationCreateResponse) {
        print("🟢 DocumentIntro: Validation created - ID: \(response.validationId)")
        guard let presenter else {
            print("⚠️ DocumentIntro: Presenter deallocated before result")
            return
        }
        presenter.validationCreated(response: response)
    }

    @MainActor
    func notifyFailure(error: Error) {
        print("❌ DocumentIntro: Validation creation failed: \(error)")
        presenter?.validationFailed(
            .apiError("Failed to create validation: \(error.localizedDescription)")
        )
    }
}
