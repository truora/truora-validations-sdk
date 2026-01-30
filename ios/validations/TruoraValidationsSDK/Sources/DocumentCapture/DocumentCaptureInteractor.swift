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

    init(
        presenter: DocumentCaptureInteractorToPresenter,
        uploadFileHandler: ((String, Data) async throws -> Void)? = nil
    ) {
        self.presenter = presenter
        self.uploadFileHandler = uploadFileHandler
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
                await presenter.photoUploadFailed(
                    side: side,
                    error: .sdk(SDKError(type: .invalidConfiguration, details: "API client not configured"))
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
                await presenter.imageEvaluationErrored(
                    side: side,
                    error: .sdk(SDKError(type: .invalidConfiguration, details: "API client not configured"))
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
            throw TruoraException.sdk(SDKError(type: .internalError, details: "Unable to decode image data"))
        }

        let scaled = scaleImage(image, maxDimension: 1024)

        guard let jpegData = scaled.jpegData(compressionQuality: 0.7) else {
            throw TruoraException.sdk(SDKError(type: .internalError, details: "Unable to encode image as JPEG"))
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

                guard !Task.isCancelled else {
                    return
                }

                // Check if status is explicitly success
                let isSuccess = response.status == "success"
                if isSuccess {
                    await self.presenter?.imageEvaluationSucceeded(side: side, previewData: photoData)
                } else {
                    await self.presenter?.imageEvaluationFailed(
                        side: side,
                        previewData: photoData,
                        reason: response.feedback?.reason
                    )
                }
            } catch is CancellationError {
                // No-op
            } catch let truoraError as TruoraException {
                // Preserve TruoraException errors thrown from evaluation logic
                guard !Task.isCancelled else {
                    return
                }
                await self.presenter?.imageEvaluationErrored(side: side, error: truoraError)
            } catch let apiError as TruoraAPIError {
                // Wrap API errors - use network case to preserve error info for retry logic
                guard !Task.isCancelled else {
                    return
                }
                let errorMessage = apiError.errorDescription ?? "Image evaluation API error: \(apiError)"
                await self.presenter?.imageEvaluationErrored(
                    side: side,
                    error: .network(
                        message: errorMessage,
                        underlyingError: apiError
                    )
                )
            } catch {
                // Wrap other errors (e.g., Swift runtime errors)
                guard !Task.isCancelled else {
                    return
                }
                await self.presenter?.imageEvaluationErrored(
                    side: side,
                    error: .sdk(
                        SDKError(
                            type: .internalError,
                            details: "Image evaluation failed: \(error.localizedDescription)"
                        )
                    )
                )
            }
        }
    }
}
