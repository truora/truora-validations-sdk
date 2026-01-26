//
//  PassiveCaptureInteractor.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 30/10/25.
//

import Foundation
import TruoraShared

class PassiveCaptureInteractor {
    weak var presenter: PassiveCaptureInteractorToPresenter?
    let validationId: String
    private var uploadUrl: String?
    private var uploadTask: Task<Void, Never>?

    init(presenter: PassiveCaptureInteractorToPresenter, validationId: String) {
        self.presenter = presenter
        self.validationId = validationId
    }

    deinit {
        uploadTask?.cancel()
    }
}

extension PassiveCaptureInteractor: PassiveCapturePresenterToInteractor {
    func setUploadUrl(_ uploadUrl: String?) {
        self.uploadUrl = uploadUrl
    }

    func uploadVideo(_ videoData: Data) {
        print(
            "🟢 PassiveCaptureInteractor: Uploading video (\(videoData.count) bytes) "
                + "for validation \(validationId)..."
        )

        guard let presenter else {
            print("❌ PassiveCaptureInteractor: Presenter is nil")
            return
        }

        guard videoData.count > 0 else {
            print("❌ PassiveCaptureInteractor: Video data is empty")
            presenter.videoUploadFailed(.uploadFailed("Video data is empty"))
            return
        }

        guard let apiClient = ValidationConfig.shared.apiClient else {
            print("❌ PassiveCaptureInteractor: API client not configured")
            presenter.videoUploadFailed(.invalidConfiguration("API client not configured"))
            return
        }

        guard let uploadUrl else {
            presenter.videoUploadFailed(.uploadFailed("No upload URL provided"))
            return
        }

        uploadTask = Task {
            await performVideoUploadTask(
                videoData: videoData,
                apiClient: apiClient,
                uploadUrl: uploadUrl
            )
        }
    }

    private func performVideoUploadTask(
        videoData: Data,
        apiClient: TruoraValidations,
        uploadUrl: String
    ) async {
        do {
            print("🟢 PassiveCaptureInteractor: Upload URL obtained, uploading video...")

            // Convert video data to KotlinByteArray
            let kotlinBytes = convertDataToKotlinByteArray(videoData)

            // Upload video to presigned URL
            _ = try await apiClient.validations.uploadFile(
                uploadUrl: uploadUrl,
                fileData: kotlinBytes,
                contentType: "video/mp4"
            )

            guard !Task.isCancelled else {
                print("⚠️ PassiveCaptureInteractor: Upload task was cancelled")
                return
            }

            print("🟢 PassiveCaptureInteractor: Video uploaded successfully")

            // Navigate to result view immediately - polling will happen there
            await MainActor.run {
                self.presenter?.videoUploadCompleted(validationId: self.validationId)
            }
        } catch is CancellationError {
            print("⚠️ PassiveCaptureInteractor: Task was cancelled")
        } catch {
            print("❌ PassiveCaptureInteractor: Upload failed: \(error)")
            await MainActor.run {
                self.presenter?.videoUploadFailed(.uploadFailed(error.localizedDescription))
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
