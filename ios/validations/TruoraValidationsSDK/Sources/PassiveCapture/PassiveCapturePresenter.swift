//
//  PassiveCapturePresenter.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 30/10/25.
//

import AVFoundation
import Foundation
import TruoraCamera
import TruoraShared
import UIKit

/// Camera lifecycle state consolidating initialization, readiness, and recording status
private enum CameraLifecycleState {
    case uninitialized // Initial state before camera setup
    case stopped // Camera was initialized but is now stopped
    case ready // Camera ready, not recording
    case recording // Actively recording
}

class PassiveCapturePresenter {
    weak var view: PassiveCapturePresenterToView?
    var interactor: PassiveCapturePresenterToInteractor?
    weak var router: ValidationRouter?

    var currentState: PassiveCaptureState
    private var currentFeedback: FeedbackType = .none
    private var countdown: Int32
    private var showHelpDialog: Bool = false
    private var showSettingsPrompt: Bool = false
    private var countdownTimer: Timer?
    private var capturedVideoData: Data?
    private var lastFrameData: Data?
    private var uploadState: UploadState = .none
    private var lifecycleState: CameraLifecycleState = .uninitialized
    private var isSettingUpCamera: Bool = false
    private let useAutocapture: Bool

    // Thread-safe timing properties using NSLock
    // for low-overhead synchronization
    private let timingLock = NSLock()
    private var videoProcessingStartTime: Date?
    private var faceDetectionStartTime: Date?
    static let manualTimeoutSeconds: TimeInterval = 4.0
    static let requiredDetectionTime: TimeInterval = 1.0

    init(
        view: PassiveCapturePresenterToView,
        interactor: PassiveCapturePresenterToInteractor?,
        router: ValidationRouter,
        useAutocapture: Bool = true
    ) {
        self.view = view
        self.interactor = interactor
        self.router = router
        self.useAutocapture = useAutocapture
        // Set initial state based on autocapture setting to avoid flash of countdown
        self.currentState = useAutocapture ? .countdown : .manual
        self.countdown = useAutocapture ? 3 : 0
    }

    private func updateUI() {
        view?.updateComposeUI(
            state: currentState,
            feedback: currentFeedback,
            countdown: countdown,
            showHelpDialog: showHelpDialog,
            showSettingsPrompt: showSettingsPrompt,
            lastFrameData: lastFrameData,
            uploadState: uploadState
        )
    }

    private func startCountdown() {
        currentState = .countdown
        countdown = 3
        updateUI()

        // Invalidate existing timer before creating a new one
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(
            withTimeInterval: 1.0,
            repeats: true
        ) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }

            if self.countdown > 0 {
                self.countdown -= 1
                self.updateUI()
            } else {
                timer.invalidate()
                self.beginWaitingForFace()
            }
        }
    }

    /// Moves to recording state but waits for face detection before actually recording.
    private func beginWaitingForFace() {
        // We want to process frames and show feedback, but not start recording yet.
        lifecycleState = .ready

        currentState = .recording
        currentFeedback = .showFace

        // Start manual timeout window (4s) while we wait for a face
        timingLock.lock()

        videoProcessingStartTime = Date()
        timingLock.unlock()

        // Reset face detection timer so we require a fresh consecutive second
        resetFaceDetectionTimer()
        updateUI()
    }

    private func startRecording() {
        guard lifecycleState != .recording else {
            return
        }

        lifecycleState = .recording
        currentState = .recording
        currentFeedback = .recording

        // Set video processing start time (thread-safe)
        timingLock.lock()
        videoProcessingStartTime = Date()
        timingLock.unlock()

        updateUI()

        // Wait a moment for UI to update, then start camera recording
        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.5
        ) { [weak self] in
            self?.view?.startRecording()
        }
    }

    /// Checks if manual capture timeout has been reached (thread-safe)
    /// Returns true if 4 seconds have passed since video processing started
    private func hasManualTimeout() -> Bool {
        timingLock.lock()
        defer { timingLock.unlock() }

        guard let startTime = videoProcessingStartTime else {
            return false
        }

        let elapsed = Date().timeIntervalSince(startTime)
        return elapsed >= Self.manualTimeoutSeconds
    }

    /// Resets the video processing timer (thread-safe)
    private func resetProcessingTimer() {
        timingLock.lock()
        videoProcessingStartTime = nil
        timingLock.unlock()
    }

    /// Starts the face detection timer (thread-safe)
    private func startFaceDetectionTimer() {
        timingLock.lock()
        faceDetectionStartTime = Date()
        timingLock.unlock()
    }

    /// Resets the face detection timer (thread-safe)
    private func resetFaceDetectionTimer() {
        timingLock.lock()
        faceDetectionStartTime = nil
        timingLock.unlock()
    }

    /// Checks if sufficient consecutive face detection time has elapsed (thread-safe)
    /// Returns true if 1 second has passed since face detection started
    private func hasSufficientFaceDetection() -> Bool {
        timingLock.lock()
        defer { timingLock.unlock() }

        guard let startTime = faceDetectionStartTime else {
            return false
        }
        let elapsed = Date().timeIntervalSince(startTime)
        return elapsed >= Self.requiredDetectionTime
    }

    /// Transitions to manual mode with error message (used when autocapture times out)
    private func transitionToManualWithError() {
        resetFaceDetectionTimer()
        currentState = .manual
        currentFeedback = .showFace
        updateUI()
    }

    /// Transitions to manual mode without error message (used when autocapture is disabled)
    private func transitionToManualWithoutError() {
        resetFaceDetectionTimer()
        currentState = .manual
        currentFeedback = .none
        updateUI()
    }
}

extension PassiveCapturePresenter: PassiveCaptureViewToPresenter {
    func viewDidLoad() {
        interactor?.setUploadUrl(router?.uploadUrl)
        if !isSettingUpCamera {
            print("🟢 PassiveCapturePresenter: viewDidLoad - triggering initial setup")
            isSettingUpCamera = true
            view?.setupCamera()
        }
        updateUI()
    }

    func viewWillAppear() {
        // On initial load, skip restart logic as it's handled by viewDidLoad
        guard lifecycleState != .uninitialized else {
            print("🟢 PassiveCapturePresenter: viewWillAppear - initial load, skipping")
            return
        }

        // If upload in progress, don't restart camera
        guard uploadState != .uploading, uploadState != .success else {
            print("🟢 PassiveCapturePresenter: viewWillAppear - skipping restart (upload in progress)")
            return
        }

        // Re-try setup when returning to view (e.g. from Settings or background)
        print("🟢 viewWillAppear, checking camera permissions...")
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        switch status {
        case .authorized:
            if lifecycleState == .stopped, !isSettingUpCamera {
                print("✅ Permission granted, restarting camera...")
                isSettingUpCamera = true
                resetToInitialState()
                view?.setupCamera()
            }
        case .notDetermined:
            if !isSettingUpCamera {
                print("🟠 Permission not determined, triggering setup...")
                isSettingUpCamera = true
                view?.setupCamera()
            }
        case .denied, .restricted:
            print("❌ Permission still denied")
            cameraPermissionDenied()
        @unknown default:
            break
        }
    }

    private func resetToInitialState() {
        // Reset all state to initial values for a fresh start
        currentState = .countdown
        currentFeedback = .none
        countdown = 3
        showHelpDialog = false
        lifecycleState = .stopped
        capturedVideoData = nil
        lastFrameData = nil

        // Clean up timers
        countdownTimer?.invalidate()
        countdownTimer = nil
        resetFaceDetectionTimer()
        resetProcessingTimer()

        updateUI()
    }

    func cameraReady() {
        isSettingUpCamera = false
        lifecycleState = .ready
        showSettingsPrompt = false
        updateUI()
        if useAutocapture {
            print("🟢 PassiveCapturePresenter: Camera ready, starting countdown")
            startCountdown()
        } else {
            print("🟢 PassiveCapturePresenter: Camera ready, autocapture disabled - going to manual mode")
            transitionToManualWithoutError()
        }
    }

    func videoRecordingCompleted(videoData: Data) {
        print("🟢 PassiveCapturePresenter: Received video data (\(videoData.count) bytes)")
        lifecycleState = .ready
        capturedVideoData = videoData
        uploadState = .uploading

        // Keep state as RECORDING with no feedback during upload
        // This prevents UI from showing buttons or messages
        currentFeedback = .none

        // Pause camera during upload - freezes preview on last frame without tearing down
        view?.pauseCamera()

        updateUI()
        interactor?.uploadVideo(videoData)
    }

    func lastFrameCaptured(frameData: Data) {
        print("🟢 Last frame (\(frameData.count) bytes)")
        lastFrameData = frameData

        // Don't update state/feedback if already uploading
        if uploadState != .uploading, uploadState != .success {
            currentFeedback = .none
            currentState = .recording
        }

        updateUI()
    }

    func validateCurrentStateAndResetTimer() -> Bool {
        if currentState != .recording || showHelpDialog {
            resetFaceDetectionTimer()

            return false
        }

        // Don't process frames during upload - camera is stopped
        if uploadState == .uploading || uploadState == .success {
            return false
        }

        // Do not check manual timeout if already recording
        if lifecycleState != .recording, hasManualTimeout() {
            transitionToManualWithError()

            return false
        }

        return true
    }

    func detectionsReceived(_ results: [DetectionResult]) {
        let isValid = validateCurrentStateAndResetTimer()
        if !isValid {
            return
        }

        // Extract faces from detection results
        let faces = results.filter { result in
            guard case .face = result.category else {
                return false
            }
            return true
        }

        guard faces.count > 0 else {
            resetFaceDetectionTimer()
            // Only update feedback if not currently recording
            if lifecycleState != .recording {
                currentFeedback = .showFace
                updateUI()
            }

            return
        }

        guard faces.count == 1 else {
            resetFaceDetectionTimer()
            // Only update feedback if not currently recording
            if lifecycleState != .recording {
                currentFeedback = .multiplePeople
                updateUI()
            }

            return
        }

        // Start timer on first valid face, or check if we've had consecutive faces for 1 second
        if faceDetectionStartTime == nil {
            startFaceDetectionTimer()
        }

        // Only update feedback if not currently recording
        if lifecycleState != .recording {
            currentFeedback = .none
            updateUI()
        }

        if hasSufficientFaceDetection(), lifecycleState != .recording {
            startRecording()
        }
    }

    func viewWillDisappear() {
        // Pause video first to discard any in-progress recording
        if lifecycleState == .recording {
            view?.pauseVideo()
        }

        // Then stop camera completely (resets skipMediaNotification = false for clean restart)
        view?.stopCamera()

        // Set lifecycle state to stopped so we can restart when returning
        lifecycleState = .stopped

        // Clean up timers
        resetFaceDetectionTimer()
        countdownTimer?.invalidate()
        resetProcessingTimer()
    }

    func cameraPermissionDenied() {
        isSettingUpCamera = false
        print("❌ PassiveCapturePresenter: Camera permission denied")
        print("🔔 Showing settings prompt to user")
        showSettingsPrompt = true
        updateUI()
    }

    func handleCaptureEvent(_ event: PassiveCaptureEvent) {
        if event is PassiveCaptureEventHelpRequested {
            view?.pauseVideo()
            showHelpDialog = true
            updateUI()
        } else if event is PassiveCaptureEventHelpDismissed {
            showHelpDialog = false
            // Reset recording state
            lifecycleState = .ready

            if useAutocapture {
                // Start fresh from countdown (camera is still running, just reset the flow)
                startCountdown()
            } else {
                // When autocapture is disabled, stay in manual state
                currentState = .manual
                currentFeedback = .none
                updateUI()
            }
        } else if event is PassiveCaptureEventManualRecordingRequested {
            handleManualRecordingRequested()
        } else if event is PassiveCaptureEventOpenSettingsRequested {
            openSettings()
        } else if event is PassiveCaptureEventSettingsPromptDismissed {
            showSettingsPrompt = false
            updateUI()
        } else if event is PassiveCaptureEventRecordVideoRequested {
            showHelpDialog = false
            startRecording()
        } else if event is PassiveCaptureEventRecordingCompleted {
            handleRecordingCompleted()
        }
    }

    private func handleManualRecordingRequested() {
        showHelpDialog = false
        currentState = .manual
        currentFeedback = .none
        updateUI()
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url, options: [:]) { [weak self] success in
                if !success {
                    print("❌ PassiveCapturePresenter: Failed to open settings")
                    self?.showSettingsPrompt = false
                    self?.updateUI()
                }
            }
        }
    }

    private func handleRecordingCompleted() {
        if lifecycleState == .recording {
            view?.stopRecording()
        } else {
            print("⚠️ PassiveCapturePresenter: Recording already stopped, skipping stop call")
        }
    }
}

extension PassiveCapturePresenter: PassiveCaptureInteractorToPresenter {
    func videoUploadCompleted(validationId: String) {
        uploadState = .success
        updateUI()

        // Stop camera before navigating to results
        view?.stopCamera()

        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.5
        ) { [weak self] in
            do {
                try self?.router?.navigateToResult(
                    validationId: validationId,
                    loadingType: TruoraShared.LoadingType.face
                )
            } catch {
                self?.view?.showError(error.localizedDescription)
            }
        }
    }

    func videoUploadFailed(_ error: ValidationError) {
        uploadState = .none
        updateUI()

        // Stop camera before dismissing flow
        view?.stopCamera()

        router?.handleError(error)
    }
}
