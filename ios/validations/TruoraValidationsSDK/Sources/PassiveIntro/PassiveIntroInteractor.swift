//
//  PassiveIntroInteractor.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 31/10/25.
//

import Foundation
import TruoraShared

class PassiveIntroInteractor {
    weak var presenter: PassiveIntroInteractorToPresenter?
    private var validationTask: Task<Void, Never>?
    private let enrollmentTask: Task<Void, Error>?

    init(presenter: PassiveIntroInteractorToPresenter?, enrollmentTask: Task<Void, Error>?) {
        self.presenter = presenter
        self.enrollmentTask = enrollmentTask
    }

    deinit {
        validationTask?.cancel()
        enrollmentTask?.cancel()
    }
}

extension PassiveIntroInteractor: PassiveIntroPresenterToInteractor {
    func createValidation(accountId: String) {
        guard let apiClient = ValidationConfig.shared.apiClient else {
            presenter?.validationFailed(.apiError("API client not configured"))
            return
        }

        validationTask = Task {
            do {
                let request = createValidationRequest(accountId: accountId)
                print("🟢 PassiveIntro: Creating validation for account: \(accountId)")

                let response = try await apiClient.validations.createValidation(
                    formData: request.toFormData()
                )

                guard !Task.isCancelled else {
                    print("⚠️ PassiveIntroInteractor: Task was cancelled")
                    return
                }

                let validationResponse = try await handleValidationResponse(response)
                await MainActor.run {
                    self.presenter?.validationCreated(response: validationResponse)
                }
            } catch is CancellationError {
                print("⚠️ PassiveIntroInteractor: Task was cancelled")
            } catch {
                handleValidationError(error)
            }
        }
    }

    private func createValidationRequest(accountId: String) -> TruoraShared.ValidationRequest {
        // Get similarity threshold from configuration
        let similarityThresholdFromConfig = Double(ValidationConfig.shared.faceConfig.similarityThreshold)
        let threshold: KotlinDouble? = KotlinDouble(value: similarityThresholdFromConfig)

        // Get timeout from configuration (in seconds)
        let timeoutSecondsFromConfig = ValidationConfig.shared.faceConfig.timeoutSeconds
        let timeout: KotlinInt? = timeoutSecondsFromConfig > 0
            ? KotlinInt(value: Int32(timeoutSecondsFromConfig))
            : nil

        return TruoraShared.ValidationRequest(
            type: ValidationTypes.shared.FACE_RECOGNITION,
            country: nil,
            account_id: accountId,
            threshold: threshold,
            subvalidations: [
                SubValidationTypes.shared.PASSIVE_LIVENESS,
                SubValidationTypes.shared.SIMILARITY
            ],
            retry_of_id: nil,
            allowed_retries: nil,
            document_type: nil,
            timeout: timeout
        )
    }

    private func handleValidationResponse(
        _ response: TruoraShared.Ktor_client_coreHttpResponse
    ) async throws -> ValidationCreateResponse {
        let validationResponse = try await SwiftKTORHelper.parseResponse(
            response,
            as: ValidationCreateResponse.self
        )
        print("🟢 PassiveIntro: Validation created - ID: \(validationResponse.validationId)")
        return validationResponse
    }

    private func handleValidationError(_ error: Error) {
        print("❌ PassiveIntro: Validation creation failed: \(error)")
        Task { @MainActor in
            self.presenter?.validationFailed(
                .apiError("Failed to create validation: \(error.localizedDescription)")
            )
        }
    }

    func enrollmentCompleted() async throws {
        guard let task = enrollmentTask else {
            print("⚠️ PassiveIntro: No enrollment task to wait for")
            return
        }

        guard !task.isCancelled else {
            print("⚠️ PassiveIntro: Enrollment task is already cancelled")
            throw CancellationError()
        }

        try await task.value
    }
}
