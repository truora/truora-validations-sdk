//
//  DocumentCaptureInteractor.swift
//  validations
//
//  Created by Truora on 26/12/25.
//

import Foundation
import TruoraShared
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

    deinit {
        uploadTask?.cancel()
        evaluationTask?.cancel()
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

        guard photoData.count > 0 else {
            presenter.photoUploadFailed(side: side, error: .uploadFailed("Photo data is empty"))
            return
        }

        guard let apiClient = ValidationConfig.shared.apiClient else {
            presenter.photoUploadFailed(
                side: side,
                error: .invalidConfiguration("API client not configured")
            )
            return
        }

        let uploadUrl: String? = switch side {
        case .front: frontUploadUrl
        case .back: reverseUploadUrl
        default: nil
        }

        guard let uploadUrl, !uploadUrl.isEmpty else {
            presenter.photoUploadFailed(side: side, error: .uploadFailed("No upload URL provided"))
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
            presenter.imageEvaluationErrored(
                side: side,
                error: .apiError("Photo data is empty")
            )
            return
        }

        // Re-enable image evaluation once API permissions are granted: https://truora.atlassian.net/browse/AL-269
        if let countryEnum = TruoraCountry.companion.fromId(id: country.uppercased()),
           let docTypeEnum = TruoraDocumentType.companion.fromValue(value: documentType) {
            presenter.imageEvaluationSucceeded(side: side, previewData: photoData)
            return
        }

        // if let countryEnum = TruoraCountry.companion.fromId(id: country.uppercased()),
        //    let docTypeEnum = TruoraDocumentType.companion.fromValue(value: documentType),
        //    TruoraSelectionMapper.shared.shouldSkipImageEvaluation(
        //        country: countryEnum,
        //        documentType: docTypeEnum
        //    ) {
        //     presenter.imageEvaluationSucceeded(side: side, previewData: photoData)
        //     return
        // }

        guard let apiClient = ValidationConfig.shared.apiClient else {
            presenter.imageEvaluationErrored(
                side: side,
                error: .invalidConfiguration("API client not configured")
            )
            return
        }

        presenter.imageEvaluationStarted(side: side, previewData: photoData)

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
        apiClient: TruoraValidations
    ) {
        uploadTask?.cancel()
        uploadTask = Task {
            do {
                if let uploadFileHandler {
                    try await uploadFileHandler(uploadUrl, photoData)
                } else {
                    let kotlinBytes = convertDataToKotlinByteArray(photoData)
                    _ = try await apiClient.validations.uploadFile(
                        uploadUrl: uploadUrl,
                        fileData: kotlinBytes,
                        contentType: "image/png"
                    )
                }

                guard !Task.isCancelled else {
                    return
                }

                await MainActor.run {
                    self.presenter?.photoUploadCompleted(side: side)
                }
            } catch is CancellationError {
                // No-op
            } catch {
                await MainActor.run {
                    self.presenter?.photoUploadFailed(
                        side: side,
                        error: .uploadFailed(error.localizedDescription)
                    )
                }
            }
        }
    }

    private func convertDataToKotlinByteArray(_ data: Data) -> KotlinByteArray {
        data.withUnsafeBytes { (bufferPointer: UnsafeRawBufferPointer) -> KotlinByteArray in
            let byteArray = KotlinByteArray(size: Int32(data.count))
            for index in 0 ..< data.count {
                let byte = Int8(bitPattern: bufferPointer[index])
                byteArray.set(index: Int32(index), value: byte)
            }
            return byteArray
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
    ) throws -> ImageEvaluationRequest {
        guard let image = UIImage(data: photoData) else {
            throw ValidationError.apiError("Unable to decode image data")
        }

        let scaled = scaleImage(image, maxDimension: 1024)

        guard let jpegData = scaled.jpegData(compressionQuality: 0.7) else {
            throw ValidationError.apiError("Unable to encode image as JPEG")
        }

        let base64 = jpegData.base64EncodedString()
        let documentSide = mapSideToAPI(side)

        return ImageEvaluationRequest(
            image: base64,
            country: country.uppercased(),
            document_type: documentType,
            document_side: documentSide,
            validation_id: validationId,
            evaluation_type: "document"
        )
    }

    func mapSideToAPI(_ side: DocumentCaptureSide) -> String {
        switch side {
        case .front:
            "front"
        case .back:
            "reverse"
        default:
            "front"
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
        apiClient: TruoraValidations
    ) {
        evaluationTask?.cancel()
        evaluationTask = Task.detached { [weak self] in
            guard let self else { return }

            do {
                let request = try self.buildImageEvaluationRequest(
                    side: side,
                    photoData: photoData,
                    country: country,
                    documentType: documentType,
                    validationId: validationId
                )

                let response = try await apiClient.imageEvaluation.evaluateImage(request: request)
                let parsed = try await SwiftKTORHelper.parseResponse(
                    response,
                    as: ImageEvaluationResponse.self
                )

                guard !Task.isCancelled else {
                    return
                }

                await MainActor.run { [weak self] in
                    guard let self else { return }

                    if parsed.status.lowercased() == "success" {
                        self.presenter?.imageEvaluationSucceeded(side: side, previewData: photoData)
                    } else {
                        self.presenter?.imageEvaluationFailed(
                            side: side,
                            previewData: photoData,
                            reason: parsed.feedback?.reason
                        )
                    }
                }
            } catch is CancellationError {
                // No-op
            } catch {
                guard !Task.isCancelled else {
                    return
                }
                await MainActor.run { [weak self] in
                    self?.presenter?.imageEvaluationErrored(
                        side: side,
                        error: .apiError(error.localizedDescription)
                    )
                }
            }
        }
    }
}
