//
//  DocumentCaptureInteractor.swift
//  validations
//
//  Created by Truora on 26/12/25.
//

import Foundation
import UIKit

final class DocumentCaptureInteractor {
    weak var presenter: DocumentCaptureInteractorToPresenter?

    private var frontUploadUrl: String?
    private var reverseUploadUrl: String?

    private var uploadTask: Task<Void, Never>?
    private var evaluationTask: Task<Void, Never>?
    private let uploadFileHandler: ((String, Data) async throws -> Void)?
    private let logger: TruoraLogger

    /// Constants for logging
    private static let validationType = "document_validation"

    init(
        presenter: DocumentCaptureInteractorToPresenter,
        uploadFileHandler: ((String, Data) async throws -> Void)? = nil,
        logger: TruoraLogger
    ) {
        self.presenter = presenter
        self.uploadFileHandler = uploadFileHandler
        self.logger = logger
    }
}

extension DocumentCaptureInteractor: DocumentCapturePresenterToInteractor {
    func setUploadUrls(frontUploadUrl: String, reverseUploadUrl: String?) {
        self.frontUploadUrl = frontUploadUrl
        self.reverseUploadUrl = reverseUploadUrl
    }

    func uploadPhoto(side: DocumentCaptureSide, photoData: Data) {
        guard let presenter else {
            return
        }

        guard !photoData.isEmpty else {
            Task {
                await presenter.photoUploadFailed(
                    side: side,
                    error: .sdk(SDKError(type: .uploadFailed, details: "Photo data is empty"))
                )
            }
            return
        }

        guard let apiClient = ValidationConfig.shared.apiClient else {
            Task {
                let details = "API client not configured"
                await presenter.photoUploadFailed(
                    side: side,
                    error: .sdk(SDKError(type: .invalidConfiguration, details: details))
                )
            }
            return
        }

        let uploadUrl: String? = switch side {
        case .front: frontUploadUrl
        case .back: reverseUploadUrl
        }

        guard let uploadUrl, !uploadUrl.isEmpty else {
            Task {
                await presenter.photoUploadFailed(
                    side: side,
                    error: .sdk(SDKError(type: .uploadFailed, details: "No upload URL provided"))
                )
            }
            return
        }

        if !UploadUrlValidator.isTruoraFilesUploadUrl(uploadUrl) {
            Task {
                await presenter.photoUploadFailed(
                    side: side,
                    error: .sdk(SDKError(type: .uploadFailed, details: "Invalid file upload link"))
                )
            }
            return
        }

        // Check if upload URL has expired (validation timeout)
        if UploadUrlValidator.isExpired(uploadUrl) {
            Task {
                await presenter.photoUploadFailed(
                    side: side,
                    error: .sdk(SDKError(
                        type: .validationError,
                        details: "Validation expired. The time limit was exceeded."
                    ))
                )
            }
            return
        }
        performUpload(uploadUrl: uploadUrl, photoData: photoData, side: side, apiClient: apiClient)
    }

    func evaluateImage(
        side: DocumentCaptureSide,
        photoData: Data,
        country: String,
        documentType: String,
        validationId: String
    ) {
        guard let presenter else {
            return
        }

        guard !photoData.isEmpty else {
            Task {
                await presenter.imageEvaluationErrored(
                    side: side,
                    error: .sdk(SDKError(type: .uploadFailed, details: "Photo data is empty"))
                )
            }
            return
        }

        guard let apiClient = ValidationConfig.shared.apiClient else {
            Task {
                let details = "API client not configured"
                await presenter.imageEvaluationErrored(
                    side: side,
                    error: .sdk(SDKError(type: .invalidConfiguration, details: details))
                )
            }
            return
        }

        Task { await presenter.imageEvaluationStarted(side: side, previewData: photoData) }

        performImageEvaluation(
            side: side,
            photoData: photoData,
            country: country,
            documentType: documentType,
            validationId: validationId,
            apiClient: apiClient
        )
    }

    private func performUpload(
        uploadUrl: String,
        photoData: Data,
        side: DocumentCaptureSide,
        apiClient: TruoraAPIClient
    ) {
        uploadTask?.cancel()
        uploadTask = Task { [weak self] in
            do {
                if let uploadFileHandler = self?.uploadFileHandler {
                    try await uploadFileHandler(uploadUrl, photoData)
                } else {
                    try await apiClient.uploadFile(
                        uploadUrl: uploadUrl,
                        fileData: photoData,
                        contentType: "image/png"
                    )
                }

                guard !Task.isCancelled else {
                    return
                }

                await self?.presenter?.photoUploadCompleted(side: side)
            } catch is CancellationError {
                // No-op
            } catch {
                await self?.presenter?.photoUploadFailed(
                    side: side,
                    error: .sdk(SDKError(type: .uploadFailed, details: error.localizedDescription))
                )
            }
        }
    }

    // MARK: - Logging Methods

    func logDocCaptureSucceeded(side: DocumentCaptureSide, validationId: String) async {
        let eventName = side == .front
            ? "doc_front_capture_succeeded"
            : "doc_reverse_capture_succeeded"
        await logger.logML(
            eventName: eventName,
            level: .info,
            errorMessage: nil,
            retention: .oneWeek,
            metadata: [
                "validation_type": Self.validationType,
                "validation_id": validationId
            ]
        )
    }

    func logDocCaptureFailed(side: DocumentCaptureSide, validationId: String, errorMessage: String) async {
        let eventName = side == .front
            ? "doc_front_capture_failed"
            : "doc_reverse_capture_failed"
        await logger.logML(
            eventName: eventName,
            level: .error,
            errorMessage: errorMessage,
            retention: .oneWeek,
            metadata: [
                "validation_type": Self.validationType,
                "validation_id": validationId
            ]
        )
    }

    func logDocFeedbackSucceeded(validationId: String, result: String, reason: String?) async {
        var metadata: [String: Any] = [
            "result": result,
            "validation_type": Self.validationType,
            "validation_id": validationId
        ]
        if let reason {
            metadata["reason"] = reason
        }
        await logger.logFeedback(
            eventName: "doc_feedback_succeeded",
            level: .info,
            errorMessage: nil,
            retention: .oneMonth,
            metadata: metadata
        )
    }

    func logDocFeedbackFailed(validationId: String, errorMessage: String) async {
        await logger.logFeedback(
            eventName: "doc_feedback_failed",
            level: .error,
            errorMessage: errorMessage,
            retention: .oneMonth,
            metadata: [
                "validation_type": Self.validationType,
                "validation_id": validationId
            ]
        )
    }
}

private extension DocumentCaptureInteractor {
    func buildImageEvaluationRequest(
        side: DocumentCaptureSide,
        photoData: Data,
        country: String,
        documentType: String,
        validationId: String
    ) throws -> NativeImageEvaluationRequest {
        guard let image = UIImage(data: photoData) else {
            let details = "Unable to decode image data"
            throw TruoraException.sdk(SDKError(type: .internalError, details: details))
        }

        let scaled = scaleImage(image, maxDimension: 1024)

        guard let jpegData = scaled.jpegData(compressionQuality: 0.7) else {
            let details = "Unable to encode image as JPEG"
            throw TruoraException.sdk(SDKError(type: .internalError, details: details))
        }

        let base64Image = jpegData.base64EncodedString()
        let documentSide = mapSideToAPI(side)

        return NativeImageEvaluationRequest(
            image: base64Image,
            country: country.uppercased(),
            documentType: documentType,
            documentSide: documentSide,
            validationId: validationId,
            evaluationType: "document"
        )
    }

    func mapSideToAPI(_ side: DocumentCaptureSide) -> String {
        switch side {
        case .front:
            "front"
        case .back:
            "reverse"
        }
    }

    func scaleImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        guard let cgImage = image.cgImage else {
            return image
        }

        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)

        guard width > maxDimension || height > maxDimension else {
            return image
        }

        let ratio = width / height
        let targetSize =
            if width > height {
                CGSize(width: maxDimension, height: maxDimension / ratio)
            } else {
                CGSize(width: maxDimension * ratio, height: maxDimension)
            }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    func performImageEvaluation(
        side: DocumentCaptureSide,
        photoData: Data,
        country: String,
        documentType: String,
        validationId: String,
        apiClient: TruoraAPIClient
    ) {
        evaluationTask?.cancel()
        evaluationTask = Task { [weak self] in
            guard let self else { return }

            do {
                let request = try self.buildImageEvaluationRequest(
                    side: side,
                    photoData: photoData,
                    country: country,
                    documentType: documentType,
                    validationId: validationId
                )

                let response = try await apiClient.evaluateImage(request: request)

                guard !Task.isCancelled else { return }

                if response.status == "success" {
                    await self.presenter?.imageEvaluationSucceeded(
                        side: side,
                        previewData: photoData
                    )
                } else {
                    await self.presenter?.imageEvaluationFailed(
                        side: side,
                        previewData: photoData,
                        reason: response.feedback?.reason
                    )
                }
            } catch is CancellationError {
                // No-op: Task was cancelled, ignore error
            } catch {
                // Handle all other errors (TruoraException, TruoraAPIError, and generic errors)
                // Error type checking is preserved in handleEvaluationError for retry logic
                guard !Task.isCancelled else { return }
                await self.handleEvaluationError(error, side: side)
            }
        }
    }

    private func handleEvaluationError(_ error: Error, side: DocumentCaptureSide) async {
        let truoraError: TruoraException
        if let existing = error as? TruoraException {
            truoraError = existing
        } else if let apiError = error as? TruoraAPIError {
            let fallbackMsg = "Image evaluation API error: \(apiError)"
            let errorMessage = apiError.errorDescription ?? fallbackMsg
            truoraError = .network(message: errorMessage, underlyingError: apiError)
        } else {
            truoraError = .sdk(
                SDKError(
                    type: .internalError,
                    details: "Image evaluation failed: \(error.localizedDescription)"
                )
            )
        }
        await presenter?.imageEvaluationErrored(side: side, error: truoraError)
    }
}
