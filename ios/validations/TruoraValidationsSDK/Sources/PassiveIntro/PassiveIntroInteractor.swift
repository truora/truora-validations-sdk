//
//  PassiveIntroInteractor.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 31/10/25.
//

import Foundation

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
        // Use the native API Client from ValidationConfig
        guard let apiClient = ValidationConfig.shared.apiClient else {
            Task {
                await presenter?.validationFailed(
                    .sdk(SDKError(type: .invalidConfiguration, details: "API client not configured"))
                )
            }
            return
        }

        #if DEBUG
        // Offline Mode Mock (DEBUG only)
        if TruoraValidationsSDK.isOfflineMode {
            print("🟢 PassiveIntro: Offline mode, mocking validation creation")
            let instructions = NativeValidationInstructions(
                fileUploadLink: "https://mock.url/upload",
                frontUrl: nil,
                reverseUrl: nil
            )
            let response = NativeValidationCreateResponse(
                validationId: "offline-validation-id",
                instructions: instructions
            )
            Task {
                await self.presenter?.validationCreated(response: response)
            }
            return
        }
        #endif

        validationTask = Task {
            do {
                let request = createValidationRequest(accountId: accountId)
                print("🟢 PassiveIntro: Creating validation for account: \(accountId)")

                // Call native API
                let response = try await apiClient.createValidation(request: request)

                guard !Task.isCancelled else {
                    print("⚠️ PassiveIntroInteractor: Task was cancelled")
                    return
                }

                await presenter?.validationCreated(response: response)
            } catch is CancellationError {
                print("⚠️ PassiveIntroInteractor: Task was cancelled")
            } catch {
                await handleValidationError(error)
            }
        }
    }

    private func createValidationRequest(accountId: String) -> NativeValidationRequest {
        // Get similarity threshold from configuration
        let threshold = Double(ValidationConfig.shared.faceConfig.similarityThreshold)

        // Get timeout from configuration (in seconds)
        let timeoutSeconds = ValidationConfig.shared.faceConfig.timeoutSeconds
        let timeout = timeoutSeconds > 0 ? timeoutSeconds : nil

        return NativeValidationRequest(
            type: NativeValidationTypeEnum.faceRecognition.rawValue,
            country: nil,
            accountId: accountId,
            threshold: threshold,
            subvalidations: [
                NativeSubValidationTypeEnum.passiveLiveness.rawValue,
                NativeSubValidationTypeEnum.similarity.rawValue
            ],
            documentType: nil,
            timeout: timeout
        )
    }

    private func handleValidationError(_ error: Error) async {
        print("❌ PassiveIntro: Validation creation failed: \(error)")
        if let truoraError = error as? TruoraException {
            await presenter?.validationFailed(truoraError)
        } else {
            await presenter?.validationFailed(
                .network(message: "Failed to create validation: \(error.localizedDescription)")
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
