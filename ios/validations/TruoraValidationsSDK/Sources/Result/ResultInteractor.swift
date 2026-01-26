//
//  ResultInteractor.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 21/12/25.
//

import Foundation
import TruoraShared

final class ResultInteractor {
    weak var presenter: ResultInteractorToPresenter?

    private let validationId: String
    private let loadingType: LoadingType
    private var pollingTask: Task<Void, Never>?

    init(validationId: String, loadingType: LoadingType = .face) {
        self.validationId = validationId
        self.loadingType = loadingType
    }

    deinit {
        pollingTask?.cancel()
    }
}

// MARK: - ResultPresenterToInteractor

extension ResultInteractor: ResultPresenterToInteractor {
    func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            await self?.performPolling()
        }
    }

    func cancelPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }
}

// MARK: - Private Methods

private extension ResultInteractor {
    func getBackoffIntervals() -> [UInt64] {
        // Exponential-ish backoff: 1s, 2s, 4s, 8s, then 10s, 12s intervals (max ~68s total)
        [
            1_000_000_000, // 1s
            2_000_000_000, // 2s
            4_000_000_000, // 4s
            8_000_000_000, // 8s
            8_000_000_000, // 8s
            8_000_000_000, // 8s
            8_000_000_000, // 8s
            8_000_000_000, // 8s
            10_000_000_000, // 10s
            12_000_000_000 // 12s
        ]
    }

    func shouldReturnResult(for status: String) -> Bool {
        status.lowercased() != "pending"
    }

    func fetchValidationDetail(apiClient: TruoraValidations) async throws -> ValidationDetailResponse {
        let response = try await apiClient.validations.getValidation(validationId: validationId)
        return try await SwiftKTORHelper.parseResponse(response, as: ValidationDetailResponse.self)
    }

    func performPolling() async {
        guard let apiClient = ValidationConfig.shared.apiClient else {
            await MainActor.run { [weak self] in
                self?.presenter?.pollingFailed(error: .invalidConfiguration("API client not configured"))
            }
            return
        }

        do {
            let result = try await pollForResult(apiClient: apiClient)

            // Check cancellation before notifying presenter to avoid UI updates after navigation
            guard !Task.isCancelled else {
                print("⚠️ ResultInteractor: Polling task was cancelled after completion")
                return
            }

            await MainActor.run { [weak self] in
                self?.presenter?.pollingCompleted(result: result)
            }
        } catch is CancellationError {
            print("⚠️ ResultInteractor: Polling task was cancelled")
        } catch let error as ValidationError {
            guard !Task.isCancelled else { return }
            await MainActor.run { [weak self] in
                self?.presenter?.pollingFailed(error: error)
            }
        } catch {
            guard !Task.isCancelled else { return }
            await MainActor.run { [weak self] in
                self?.presenter?.pollingFailed(error: .apiError(error.localizedDescription))
            }
        }
    }

    func pollForResult(apiClient: TruoraValidations) async throws -> ValidationResult {
        let backoffIntervals = getBackoffIntervals()

        if loadingType == .document {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1s
        }

        for (attempt, interval) in backoffIntervals.enumerated() {
            guard !Task.isCancelled else {
                throw CancellationError()
            }

            print("🟢 ResultInteractor: Polling attempt \(attempt + 1)/\(backoffIntervals.count)...")

            do {
                let validationDetail = try await fetchValidationDetail(apiClient: apiClient)
                if shouldReturnResult(for: validationDetail.validationStatus) {
                    return createValidationResult(from: validationDetail)
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                // On last attempt, propagate the error; otherwise log and retry
                if attempt == backoffIntervals.count - 1 {
                    throw error
                }
                let errorMsg = error.localizedDescription
                print("⚠️ ResultInteractor: Transient error on attempt \(attempt + 1), retrying: \(errorMsg)")
            }

            // Sleep throws CancellationError if task is cancelled, which is expected behavior
            if attempt < backoffIntervals.count - 1 {
                try await Task.sleep(nanoseconds: interval)
            }
        }

        print("❌ ResultInteractor: Polling timeout after \(backoffIntervals.count) attempts")
        throw ValidationError.apiError(
            "Validation processing timeout. Please check back later."
        )
    }

    func createValidationResult(from validationDetail: ValidationDetailResponse) -> ValidationResult {
        let status: ValidationStatus = switch validationDetail.validationStatus.lowercased() {
        case "success":
            .success
        case "failed", "failure":
            .failed
        default:
            .processing
        }

        let confidence = validationDetail.details?.faceRecognitionValidations?.confidenceScore

        return ValidationResult(
            validationId: validationDetail.validationId,
            status: status,
            confidence: confidence,
            metadata: nil
        )
    }
}
