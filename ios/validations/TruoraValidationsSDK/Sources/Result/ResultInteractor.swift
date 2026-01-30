//
//  ResultInteractor.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 21/12/25.
//

import Foundation

final class ResultInteractor {
    weak var presenter: ResultInteractorToPresenter?

    let validationId: String
    private let loadingType: ResultLoadingType
    private var pollingTask: Task<Void, Never>?
    private let timeProvider: TimeProvider

    init(
        validationId: String,
        loadingType: ResultLoadingType = .face,
        timeProvider: TimeProvider = RealTimeProvider()
    ) {
        self.validationId = validationId
        self.loadingType = loadingType
        self.timeProvider = timeProvider
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

    func fetchValidationDetail(apiClient: TruoraAPIClient) async throws -> NativeValidationDetailResponse {
        try await apiClient.getValidation(validationId: validationId)
    }

    func performPolling() async {
        guard let apiClient = ValidationConfig.shared.apiClient else {
            await presenter?.pollingFailed(
                error: .sdk(SDKError(type: .invalidConfiguration, details: "API client not configured"))
            )
            return
        }

        do {
            let result = try await pollForResult(apiClient: apiClient)

            // Check cancellation before notifying presenter to avoid UI updates after navigation
            guard !Task.isCancelled else {
                print("⚠️ ResultInteractor: Polling task was cancelled after completion")
                return
            }

            await presenter?.pollingCompleted(result: result)
        } catch is CancellationError {
            print("⚠️ ResultInteractor: Polling task was cancelled")
        } catch let error as TruoraException {
            guard !Task.isCancelled else { return }
            await presenter?.pollingFailed(error: error)
        } catch let error as DecodingError {
            // JSON parsing errors
            guard !Task.isCancelled else { return }
            await presenter?.pollingFailed(
                error: .sdk(
                    SDKError(
                        type: .internalError,
                        details: "Failed to parse server response: \(error.localizedDescription)"
                    )
                )
            )
        } catch {
            // Network and other errors
            guard !Task.isCancelled else { return }
            await presenter?.pollingFailed(
                error: .network(message: "API request failed: \(error.localizedDescription)")
            )
        }
    }

    func pollForResult(apiClient: TruoraAPIClient) async throws -> ValidationResult {
        let backoffIntervals = getBackoffIntervals()

        if loadingType == .document {
            try await timeProvider.sleep(nanoseconds: 1_000_000_000) // 1s
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
                try await timeProvider.sleep(nanoseconds: interval)
            }
        }

        print("❌ ResultInteractor: Polling timeout after \(backoffIntervals.count) attempts")
        throw TruoraException.sdk(
            SDKError(
                type: .identityProcessResultsTimedOut,
                details: "Validation processing timeout. Please check back later."
            )
        )
    }

    func createValidationResult(from validationDetail: NativeValidationDetailResponse) -> ValidationResult {
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
