//
//  DocumentCaptureViewModel.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 23/12/25.
//

import AVFoundation
import Foundation
import TruoraCamera

// MARK: - View Model

/// ViewModel for the document capture screen.
/// Uses @Published properties which automatically notify SwiftUI on the main thread.
@MainActor final class DocumentCaptureViewModel: ObservableObject {
    @Published var errorMessage: String?
    @Published var showError = false

    // Native state
    @Published var currentSide: DocumentCaptureSide = .front
    @Published var feedbackType: DocumentFeedbackType = .scanningManual
    @Published var showHelpDialog: Bool = false
    @Published var showRotationAnimation: Bool = false
    @Published var showLoadingScreen: Bool = false
    @Published var uploadState: UploadState = .none

    @Published var frontPhotoData: Data?
    @Published var frontPhotoStatus: CaptureStatus?
    @Published var backPhotoData: Data?
    @Published var backPhotoStatus: CaptureStatus?

    /// Tracks if a capture is currently in progress to prevent multiple clicks
    @Published var isCaptureInProgress: Bool = false

    /// TFLite thread count for the document detector, set by the configurator.
    var tfliteThreadCount: Int = 2

    /// Whether autocapture is enabled. When false, the TFLite document detection
    /// model is not loaded, saving ~10MB of memory and startup time.
    var useAutocapture: Bool = true

    var presenter: DocumentCaptureViewToPresenter?
    weak var cameraViewDelegate: DocumentCaptureCameraDelegate?
    private var didLoadOnce: Bool = false
    private let audioPlayer: TruoraAudioPlayer?

    #if DEBUG
    /// Performance advisor reference for the debug overlay. Set by the configurator.
    var performanceAdvisor: PerformanceAdvisor?
    #endif

    init() {
        let configuredCountry = ValidationConfig.shared.documentConfig.country.lowercased()
        self.audioPlayer = TruoraAudioPlayer(
            languageCode: ValidationConfig.shared.lang?.rawValue ?? Locale.current.languageCode ?? "es",
            countryCode: configuredCountry.isEmpty ? "co" : configuredCountry
        )
    }

    func onAppear() {
        guard !didLoadOnce else { return }
        didLoadOnce = true
        Task {
            await presenter?.viewDidBecomeVisible()
            await presenter?.viewDidLoad()
        }
    }

    func onWillAppear() {
        Task { await presenter?.viewWillAppear() }
    }

    func onWillDisappear() {
        audioPlayer?.stop()
        Task { await presenter?.viewWillDisappear() }
    }

    func onAppWillResignActive() {
        Task { await presenter?.appWillResignActive() }
    }

    func onAppDidBecomeActive() {
        Task { await presenter?.appDidBecomeActive() }
    }

    func cameraReady() {
        Task { await presenter?.cameraReady() }
    }

    func photoCaptured(photoData: Data) {
        Task { await presenter?.photoCaptured(photoData: photoData) }
    }

    func detectionsReceived(_ results: [DetectionResult]) {
        Task { await presenter?.detectionsReceived(results) }
    }

    /// Native event handlers
    func captureButtonTapped() {
        isCaptureInProgress = true
        Task { await presenter?.manualCaptureTapped() }
    }

    func helpRequested() {
        // Route through the presenter so its showHelpDialog becomes authoritative and autocapture pauses
        Task { await presenter?.handleCaptureEvent(.helpRequested) }
    }

    func helpDismissed() {
        Task { await presenter?.handleCaptureEvent(.helpDismissed) }
    }

    func cancelTapped() {
        Task { await presenter?.cancelTapped() }
    }

    func retryTapped() {
        Task { await presenter?.retryTapped() }
    }

    /// Called when autocapture becomes unavailable (e.g., ML model fails to load).
    /// Uses `switchToManualCapture()` which has atomic flag protection to ensure
    /// only one transition occurs even if called multiple times concurrently.
    /// This is important because model loading failures may trigger multiple callbacks.
    func autocaptureUnavailable() {
        Task { await presenter?.switchToManualCapture() }
    }

    /// Called when user explicitly requests manual capture mode via UI (e.g., help dialog).
    /// Uses the capture event system which resets detection state and dismisses the dialog.
    /// Unlike `autocaptureUnavailable`, this path handles UI state (dismissing help dialog)
    /// and doesn't need atomic protection since user actions are inherently sequential.
    func userRequestedManualMode() {
        Task { await presenter?.handleCaptureEvent(.switchToManualMode) }
    }
}

// MARK: - DocumentCapturePresenterToView

extension DocumentCaptureViewModel: DocumentCapturePresenterToView {
    func setupCamera() {
        guard let delegate = cameraViewDelegate else {
            errorMessage = TruoraLocalization.string(forKey: LocalizationKeys.cameraErrorInitializationFailed)
            showError = true
            return
        }
        delegate.setupCamera()
    }

    func configureSessionPreset(_ preset: AVCaptureSession.Preset) {
        cameraViewDelegate?.configureSessionPreset(preset)
    }

    func setInferenceLatencyCallback(_ callback: ((TimeInterval) -> Void)?) {
        cameraViewDelegate?.setInferenceLatencyCallback(callback)
    }

    func takePicture() {
        guard let delegate = cameraViewDelegate else {
            errorMessage = TruoraLocalization.string(forKey: LocalizationKeys.cameraErrorCaptureFailed)
            showError = true
            return
        }
        delegate.takePicture()
    }

    func stopCamera() {
        cameraViewDelegate?.stopCamera()
    }

    func pauseVideo() {
        cameraViewDelegate?.pauseVideo()
    }

    func pauseCamera() {
        cameraViewDelegate?.pauseCamera()
    }

    func resumeCamera() {
        cameraViewDelegate?.resumeCamera()
    }

    func updateComposeUI(
        side: DocumentCaptureSide,
        feedbackType: DocumentFeedbackType,
        showHelpDialog: Bool,
        showRotationAnimation: Bool,
        showLoadingScreen: Bool,
        uploadState: UploadState,
        frontPhotoData: Data?,
        frontPhotoStatus: CaptureStatus?,
        backPhotoData: Data?,
        backPhotoStatus: CaptureStatus?,
        clearFrontPhoto: Bool,
        clearBackPhoto: Bool,
        audioInstruction: TruoraAudioInstruction?
    ) {
        self.currentSide = side
        self.feedbackType = feedbackType
        self.showHelpDialog = showHelpDialog
        self.showRotationAnimation = showRotationAnimation
        self.showLoadingScreen = showLoadingScreen
        self.uploadState = uploadState

        if clearFrontPhoto {
            self.frontPhotoData = nil
        } else if let data = frontPhotoData {
            self.frontPhotoData = data
        }
        self.frontPhotoStatus = frontPhotoStatus

        if clearBackPhoto {
            self.backPhotoData = nil
        } else if let data = backPhotoData {
            self.backPhotoData = data
        }
        self.backPhotoStatus = backPhotoStatus

        if let instruction = audioInstruction {
            audioPlayer?.play(instruction)
        }
    }

    func showError(_ message: String) {
        errorMessage = message
        showError = true
    }

    func resetCaptureInProgress() {
        isCaptureInProgress = false
    }
}
