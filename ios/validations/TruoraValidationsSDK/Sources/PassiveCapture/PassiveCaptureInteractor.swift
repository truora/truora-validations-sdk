//
//  PassiveCaptureInteractor.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 30/10/25.
//

import Foundation

// MARK: - Telemetry Enums

enum FaceCaptureMode: String {
    case auto
    case manual
}

enum FaceVideoManualTriggerReason: String {
    case qualityGateTimeout = "quality_gate_timeout"
    case clientWithoutAutocapture = "client_without_autocapture"
}

// MARK: - Interactor

class PassiveCaptureInteractor {
    weak var presenter: PassiveCaptureInteractorToPresenter?
    let validationId: String
    private var uploadUrl: String?
    private var uploadTask: Task<Void, Never>?
    private let logger: TruoraLogger

    /// Constants for logging
    private static let validationType = "face_validation"

    init(
        presenter: PassiveCaptureInteractorToPresenter,
        validationId: String,
        logger: TruoraLogger
    ) {
        self.presenter = presenter
        self.validationId = validationId
        self.logger = logger
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
        debugLog(
            "🟢 PassiveCaptureInteractor: Uploading video (\(videoData.count) bytes) "
                + "for validation \(validationId)..."
        )

        guard let presenter else {
            debugLog("❌ PassiveCaptureInteractor: Presenter is nil")
            return
        }

        #if DEBUG
        if handleOfflineMode() {
            return
        }
        #endif

        let validated = validateUploadPreconditions(
            videoData: videoData,
            presenter: presenter
        )
        guard let validated else {
            return
        }

        uploadTask = Task {
            await performVideoUploadTask(
                videoData: videoData,
                apiClient: validated.apiClient,
                uploadUrl: validated.uploadUrl
            )
        }
    }

    #if DEBUG
    private func handleOfflineMode() -> Bool {
        guard TruoraValidationsSDK.isOfflineMode else { return false }
        debugLog("🟢 PassiveCaptureInteractor: Offline mode, mocking successful upload")
        Task { await self.presenter?.videoUploadCompleted(validationId: self.validationId) }
        return true
    }
    #endif

    private func validateUploadPreconditions(
        videoData: Data,
        presenter: PassiveCaptureInteractorToPresenter
    ) -> (apiClient: TruoraAPIClient, uploadUrl: String)? {
        guard !videoData.isEmpty else {
            debugLog("❌ PassiveCaptureInteractor: Video data is empty")
            let details = "Video data is empty"
            reportUploadError(presenter: presenter, type: .uploadFailed, details: details)
            return nil
        }

        guard let apiClient = ValidationConfig.shared.apiClient else {
            debugLog("❌ PassiveCaptureInteractor: API client not configured")
            let details = "API client not configured"
            reportUploadError(presenter: presenter, type: .invalidConfiguration, details: details)
            return nil
        }

        guard let uploadUrl else {
            let details = "No upload URL provided"
            reportUploadError(presenter: presenter, type: .uploadFailed, details: details)
            return nil
        }

        if !UploadUrlValidator.isTruoraFilesUploadUrl(uploadUrl) {
            debugLog("❌ PassiveCaptureInteractor: Upload URL is not a valid Truora endpoint")
            let details = "Invalid file upload link"
            reportUploadError(presenter: presenter, type: .uploadFailed, details: details)
            return nil
        }

        if UploadUrlValidator.isExpired(uploadUrl) {
            debugLog("❌ PassiveCaptureInteractor: Upload URL has expired (validation timeout)")
            let details = "Validation expired. The time limit was exceeded."
            reportUploadError(presenter: presenter, type: .validationError, details: details)
            return nil
        }

        return (apiClient, uploadUrl)
    }

    private func reportUploadError(
        presenter: PassiveCaptureInteractorToPresenter,
        type: SDKErrorType,
        details: String
    ) {
        Task { await presenter.videoUploadFailed(.sdk(SDKError(type: type, details: details))) }
    }

    private func performVideoUploadTask(
        videoData: Data,
        apiClient: TruoraAPIClient,
        uploadUrl: String
    ) async {
        do {
            debugLog("🟢 PassiveCaptureInteractor: Upload URL obtained, uploading video...")

            // Upload video to presigned URL
            try await apiClient.uploadFile(
                uploadUrl: uploadUrl,
                fileData: videoData,
                contentType: "video/mp4"
            )

            guard !Task.isCancelled else {
                debugLog("⚠️ PassiveCaptureInteractor: Upload task was cancelled")
                return
            }

            debugLog("🟢 PassiveCaptureInteractor: Video uploaded successfully")

            // Navigate to result view immediately - polling will happen there
            await presenter?.videoUploadCompleted(validationId: validationId)
        } catch is CancellationError {
            debugLog("⚠️ PassiveCaptureInteractor: Task was cancelled")
        } catch {
            debugLog("❌ PassiveCaptureInteractor: Upload failed: \(error)")
            await presenter?.videoUploadFailed(
                .sdk(SDKError(type: .uploadFailed, details: error.localizedDescription))
            )
        }
    }

    // MARK: - Logging Methods

    func logFaceCaptureSucceeded() async {
        await logger.logML(
            eventName: "face_capture_succeeded",
            level: .info,
            errorMessage: nil,
            retention: .oneWeek,
            metadata: [
                "validation_type": Self.validationType,
                "validation_id": validationId
            ]
        )
    }

    func logFaceCaptureFailed(errorMessage: String) async {
        await logger.logML(
            eventName: "face_capture_failed",
            level: .error,
            errorMessage: errorMessage,
            retention: .oneWeek,
            metadata: [
                "validation_type": Self.validationType,
                "validation_id": validationId
            ]
        )
    }

    func logFaceQualityGatePassed(timeToReadyMs: Int) async {
        await logger.logML(
            eventName: "face_quality_gate_passed",
            level: .info,
            errorMessage: nil,
            retention: .oneWeek,
            metadata: [
                "screen_name": "PassiveLiveness",
                "validation_type": "passive",
                "face_capture_mode": FaceCaptureMode.auto.rawValue,
                "time_to_ready_ms": timeToReadyMs
            ]
        )
    }

    func logFaceQualityGateTimeout(lastHint: String) async {
        await logger.logML(
            eventName: "face_quality_gate_timeout",
            level: .info,
            errorMessage: nil,
            retention: .oneWeek,
            metadata: [
                "screen_name": "PassiveLiveness",
                "validation_type": "passive",
                "last_hint": lastHint,
                "timeout_duration_seconds": Int(PassiveCapturePresenter.manualTimeoutSeconds)
            ]
        )
    }

    func logFaceVideoManualModeForced(triggerReason: FaceVideoManualTriggerReason) async {
        await logger.logML(
            eventName: "face_video_manual_mode_forced",
            level: .info,
            errorMessage: nil,
            retention: .oneWeek,
            metadata: [
                "screen_name": "PassiveLiveness",
                "validation_type": "passive",
                "trigger_reason": triggerReason.rawValue,
                "face_capture_mode": FaceCaptureMode.manual.rawValue
            ]
        )
    }

    func logFaceQualitySessionSummary(
        totalDurationMs: Int,
        hintDurationsMs: [String: Int],
        dominantHint: String,
        dominantHintPercent: Int,
        autocaptureFired: Bool
    ) async {
        var metadata: [String: Any] = [
            "screen_name": "PassiveLiveness",
            "validation_type": "passive",
            "total_duration_ms": totalDurationMs,
            "dominant_hint": dominantHint,
            "dominant_hint_percent": dominantHintPercent,
            "autocapture_fired": autocaptureFired
        ]
        for (key, value) in hintDurationsMs {
            metadata["hint_\(key.lowercased())_ms"] = value
        }
        await logger.logML(
            eventName: "face_quality_session_summary",
            level: .info,
            errorMessage: nil,
            retention: .oneWeek,
            metadata: metadata
        )
    }
}
