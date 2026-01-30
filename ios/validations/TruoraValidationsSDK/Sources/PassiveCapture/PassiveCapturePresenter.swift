//
//  PassiveCapturePresenter.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 30/10/25.
//

import AVFoundation
import Foundation
import TruoraCamera
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
    private var countdown: Int
    private var showHelpDialog: Bool = false
    private var showSettingsPrompt: Bool = false
    private var countdownTimer: Timer?
    private var capturedVideoData: Data?
    private var lastFrameData: Data?
    private var uploadState: UploadState = .none
    private var lifecycleState: CameraLifecycleState = .uninitialized
    private var isSettingUpCamera: Bool = false
    private let timeProvider: TimeProvider
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
        useAutocapture: Bool = true,
        timeProvider: TimeProvider = RealTimeProvider()
    ) {
        self.view = view
        self.interactor = interactor
        self.router = router
        self.useAutocapture = useAutocapture
        self.timeProvider = timeProvider
        // Set initial state based on autocapture setting to avoid flash of countdown
        self.currentState = useAutocapture ? .countdown : .manual
        self.countdown = useAutocapture ? 3 : 0
    }

    private func updateUI() async {
        await view?.updateUI(
            state: currentState,
            feedback: currentFeedback,
            countdown: countdown,
            showHelpDialog: showHelpDialog,
            showSettingsPrompt: showSettingsPrompt,
            lastFrameData: lastFrameData,
            uploadState: uploadState
        )
    }

    private func startCountdown() async {
        currentState = .countdown
        countdown = 3
        await updateUI()

        // Timer must be scheduled on main thread to ensure RunLoop is active
        await MainActor.run {
            // Invalidate existing timer before creating a new one
            countdownTimer?.invalidate()
            countdownTimer = timeProvider.scheduledTimer(
                withTimeInterval: 1.0,
                repeats: true
            ) { [weak self] timer in
                guard let self else {
                    timer.invalidate()
                    return
                }

                Task { @MainActor in
                    if self.countdown > 0 {
                        self.countdown -= 1
                        await self.updateUI()
                    } else {
                        timer.invalidate()
                        await self.beginWaitingForFace()
                    }
                }
            }
        }
    }

    /// Moves to recording state but waits for face detection before actually recording.
    private func beginWaitingForFace() async {
        // We want to process frames and show feedback, but not start recording yet.
        lifecycleState = .ready

        currentState = .recording
        currentFeedback = .showFace

        // Start manual timeout window (4s) while we wait for a face
        timingLock.lock()

        videoProcessingStartTime = timeProvider.now
        timingLock.unlock()

        // Reset face detection timer so we require a fresh consecutive second
        resetFaceDetectionTimer()
        await updateUI()
    }

    private func startRecording() async {
        guard lifecycleState != .recording else {
            return
        }

        lifecycleState = .recording
        currentState = .recording
        currentFeedback = .recording

        // Set video processing start time (thread-safe)
        timingLock.lock()
        videoProcessingStartTime = timeProvider.now
        timingLock.unlock()

        await updateUI()

        // Start camera recording immediately, UI handles timing
        await view?.startRecording()
    }

    /// Checks if manual capture timeout has been reached (thread-safe)
    /// Returns true if 4 seconds have passed since video processing started
    private func hasManualTimeout() -> Bool {
        timingLock.lock()
        defer { timingLock.unlock() }

        guard let startTime = videoProcessingStartTime else {
            return false
        }

        let elapsed = timeProvider.now.timeIntervalSince(startTime)
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
        faceDetectionStartTime = timeProvider.now
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

        let elapsed = timeProvider.now.timeIntervalSince(startTime)
        return elapsed >= Self.requiredDetectionTime
    }

    /// Transitions to manual mode with error message (used when autocapture times out)
    private func transitionToManualWithError() async {
        resetFaceDetectionTimer()
        currentState = .manual
        currentFeedback = .showFace
        await updateUI()
    }

    /// Transitions to manual mode without error message (used when autocapture is disabled)
    private func transitionToManualWithoutError() async {
        resetFaceDetectionTimer()
        currentState = .manual
        currentFeedback = .none
        await updateUI()
    }
}

extension PassiveCapturePresenter: PassiveCaptureViewToPresenter {
    func viewDidLoad() async {
        let uploadUrl = await router?.uploadUrl
        interactor?.setUploadUrl(uploadUrl)
        if !isSettingUpCamera {
            print("🟢 PassiveCapturePresenter: viewDidLoad - triggering initial setup")
            isSettingUpCamera = true
            await view?.setupCamera()
        }
        await updateUI()
    }

    func viewWillAppear() async {
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
                await resetToInitialState()
                await view?.setupCamera()
            }
        case .notDetermined:
            if !isSettingUpCamera {
                print("🟠 Permission not determined, triggering setup...")
                isSettingUpCamera = true
                await view?.setupCamera()
            }
        case .denied, .restricted:
            print("❌ Permission still denied")
            await cameraPermissionDenied()
        @unknown default:
            break
        }
    }

    private func resetToInitialState() async {
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

        await updateUI()
    }

    func cameraReady() async {
        isSettingUpCamera = false
        lifecycleState = .ready
        showSettingsPrompt = false
        await updateUI()
        if useAutocapture {
            print("🟢 PassiveCapturePresenter: Camera ready, starting countdown")
            await startCountdown()
        } else {
            print("🟢 PassiveCapturePresenter: Camera ready, autocapture disabled - going to manual mode")
            await transitionToManualWithoutError()
        }
    }

    func videoRecordingCompleted(videoData: Data) async {
        print("🟢 PassiveCapturePresenter: Received video data (\(videoData.count) bytes)")
        lifecycleState = .ready
        capturedVideoData = videoData
        uploadState = .uploading

        // Keep state as RECORDING with no feedback during upload
        // This prevents UI from showing buttons or messages
        currentFeedback = .none

        // Pause camera during upload - freezes preview on last frame without tearing down
        await view?.pauseCamera()

        await updateUI()
        interactor?.uploadVideo(videoData)
    }

    func lastFrameCaptured(frameData: Data) async {
        print("🟢 Last frame (\(frameData.count) bytes)")
        lastFrameData = frameData

        // Don't update state/feedback if already uploading
        if uploadState != .uploading, uploadState != .success {
            currentFeedback = .none
            currentState = .recording
        }

        await updateUI()
    }

    func validateCurrentStateAndResetTimer() async -> Bool {
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
            await transitionToManualWithError()

            return false
        }

        return true
    }

    func detectionsReceived(_ results: [DetectionResult]) async {
        guard await validateCurrentStateAndResetTimer() else { return }

        // Extract faces from detection results
        let faces = results.filter { result in
            guard case .face = result.category else {
                return false
            }
            return true
        }

        guard !faces.isEmpty else {
            resetFaceDetectionTimer()
            // Only update feedback if not currently recording
            guard lifecycleState != .recording else { return }
            currentFeedback = .showFace
            await updateUI()

            return
        }

        guard faces.count == 1 else {
            resetFaceDetectionTimer()
            // Only update feedback if not currently recording
            guard lifecycleState != .recording else { return }
            currentFeedback = .multiplePeople
            await updateUI()

            return
        }

        // Start timer on first valid face, or check if we've had consecutive faces for 1 second
        if faceDetectionStartTime == nil {
            startFaceDetectionTimer()
        }

        // Only update feedback if not currently recording
        guard lifecycleState != .recording else { return }

        currentFeedback = .none
        await updateUI()

        guard hasSufficientFaceDetection() else { return }
        await startRecording()
    }

    func viewWillDisappear() async {
        // Pause video first to discard any in-progress recording
        if lifecycleState == .recording {
            await view?.pauseVideo()
        }

        // Then stop camera completely (resets skipMediaNotification = false for clean restart)
        await view?.stopCamera()

        // Set lifecycle state to stopped so we can restart when returning
        lifecycleState = .stopped

        // Clean up timers
        resetFaceDetectionTimer()
        countdownTimer?.invalidate()
        resetProcessingTimer()
    }

    func cameraPermissionDenied() async {
        isSettingUpCamera = false
        print("❌ PassiveCapturePresenter: Camera permission denied")
        print("🔔 Showing settings prompt to user")
        showSettingsPrompt = true
        await updateUI()
    }

    func handleCaptureEvent(_ event: PassiveCaptureEvent) async {
        switch event {
        case .helpRequested:
            await view?.pauseVideo()
            showHelpDialog = true
            await updateUI()
        case .helpDismissed:
            showHelpDialog = false
            // Reset recording state
            lifecycleState = .ready

            if useAutocapture {
                // Start fresh from countdown (camera is still running, just reset the flow)
                await startCountdown()
            } else {
                // When autocapture is disabled, stay in manual state
                currentState = .manual
                currentFeedback = .none
                await updateUI()
            }
        case .manualRecordingRequested:
            await handleManualRecordingRequested()
        case .openSettingsRequested:
            await openSettings()
        case .settingsPromptDismissed:
            showSettingsPrompt = false
            await updateUI()
        case .recordVideoRequested:
            showHelpDialog = false
            await startRecording()
        case .recordingCompleted:
            await handleRecordingCompleted()
        default:
            break
        }
    }

    private func handleManualRecordingRequested() async {
        showHelpDialog = false
        currentState = .manual
        currentFeedback = .none
        await updateUI()
    }

    private func openSettings() async {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            await UIApplication.shared.open(url, options: [:])
        }
    }

    private func handleRecordingCompleted() async {
        if lifecycleState == .recording {
            await view?.stopRecording()
        } else {
            print("⚠️ PassiveCapturePresenter: Recording already stopped, skipping stop call")
        }
    }
}

extension PassiveCapturePresenter: PassiveCaptureInteractorToPresenter {
    func videoUploadCompleted(validationId: String) async {
        uploadState = .success
        await updateUI()

        // Stop camera before navigating to results
        await view?.stopCamera()

        // Small delay before navigation
        try? await timeProvider.sleep(nanoseconds: 500_000_000)

        do {
            try await router?.navigateToResult(
                validationId: validationId,
                loadingType: .face
            )
        } catch {
            await view?.showError(error.localizedDescription)
        }
    }

    func videoUploadFailed(_ error: TruoraException) async {
        uploadState = .none
        await updateUI()

        // Stop camera before dismissing flow
        await view?.stopCamera()

        await router?.handleError(error)
    }
}
