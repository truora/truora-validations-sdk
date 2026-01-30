//
//  PassiveCaptureInteractor.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 30/10/25.
//

import Foundation

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

        #if DEBUG
        // Bypass upload in offline mode (DEBUG only)
        if TruoraValidationsSDK.isOfflineMode {
            print("🟢 PassiveCaptureInteractor: Offline mode, mocking successful upload")
            Task {
                await self.presenter?.videoUploadCompleted(validationId: self.validationId)
            }
            return
        }
        #endif

        guard !videoData.isEmpty else {
            print("❌ PassiveCaptureInteractor: Video data is empty")
            Task {
                await presenter.videoUploadFailed(
                    .sdk(SDKError(type: .uploadFailed, details: "Video data is empty"))
                )
            }
            return
        }

        guard let apiClient = ValidationConfig.shared.apiClient else {
            print("❌ PassiveCaptureInteractor: API client not configured")
            Task {
                await presenter.videoUploadFailed(
                    .sdk(SDKError(type: .invalidConfiguration, details: "API client not configured"))
                )
            }
            return
        }

        guard let uploadUrl else {
            Task {
                await presenter.videoUploadFailed(
                    .sdk(SDKError(type: .uploadFailed, details: "No upload URL provided"))
                )
            }
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
        apiClient: TruoraAPIClient,
        uploadUrl: String
    ) async {
        do {
            print("🟢 PassiveCaptureInteractor: Upload URL obtained, uploading video...")

            // Upload video to presigned URL
            try await apiClient.uploadFile(
                uploadUrl: uploadUrl,
                fileData: videoData,
                contentType: "video/mp4"
            )

            guard !Task.isCancelled else {
                print("⚠️ PassiveCaptureInteractor: Upload task was cancelled")
                return
            }

            print("🟢 PassiveCaptureInteractor: Video uploaded successfully")

            // Navigate to result view immediately - polling will happen there
            await presenter?.videoUploadCompleted(validationId: validationId)
        } catch is CancellationError {
            print("⚠️ PassiveCaptureInteractor: Task was cancelled")
        } catch {
            print("❌ PassiveCaptureInteractor: Upload failed: \(error)")
            await presenter?.videoUploadFailed(
                .sdk(SDKError(type: .uploadFailed, details: error.localizedDescription))
            )
        }
    }
}
