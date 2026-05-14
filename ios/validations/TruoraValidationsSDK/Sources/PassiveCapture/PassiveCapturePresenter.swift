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
    private var countdownTask: Task<Void, Never>?
    private var capturedVideoData: Data?
    private var lastFrameData: Data?
    private var uploadState: UploadState = .none
    private var lifecycleState: CameraLifecycleState = .uninitialized
    private var isSettingUpCamera: Bool = false
    private let timeProvider: TimeProvider
    private let useAutocapture: Bool

    /// Constants for logging
    private static let viewName = "face_capture"
    private static let validationType = "face_validation"

    private var wasRecordingBeforeHelp: Bool = false
    private var stateAtHelp: PassiveCaptureState?
    private var feedbackAtHelp: FeedbackType = .none

    private var wasRecordingAtSuspend: Bool = false
    private var stateAtSuspend: PassiveCaptureState?
    private var uploadStateAtSuspend: UploadState = .none
    private var wasHelpOpenAtSuspend: Bool = false

    private enum PendingCameraReadyAction {
        case none
        case resumeFromSuspendWasRecordingAuto
        case resumeFromSuspendWasRecordingManual
    }

    private var pendingCameraReadyAction: PendingCameraReadyAction = .none

    // Timing properties protected by NSLock against interleaving
    // at async suspension points (low-overhead synchronization)
    private let timingLock = NSLock()
    private var videoProcessingStartTime: Date?
    private var faceDetectionStartTime: Date?
    static let manualTimeoutSeconds: TimeInterval = 4.0
    static let requiredDetectionTime: TimeInterval = 1.0

    // Face centering thresholds (normalized [0,1] coordinates)
    static let minFaceHeight: CGFloat = 0.20
    static let maxFaceHeight: CGFloat = 0.85
    static let centerDistanceThreshold: CGFloat = 0.25

    /// Minimum face bbox height to render an oval in multi-face mode.
    /// Lower than `minFaceHeight` so clearly visible background faces (e.g. ~18% tall
    /// per Figma PROC-6872) still get an oval, while tiny noise detections are dropped.
    static let minMultiFaceRenderHeight: CGFloat = 0.08

    /// Yaw at or above this magnitude (in radians) blocks autocapture and emits .lookForward.
    /// 25° matches Android's YAW_THRESHOLD_DEGREES for cross-platform UX consistency. On iOS 13/14
    /// Vision yaw is reported in {0, ±45°} discrete bins, so any threshold in (0°, 45°) blocks only
    /// the ±45° bucket; iOS 15+ reports continuous yaw and the check applies directly.
    static let yawThresholdRadians: Double = 25.0 * .pi / 180.0

    /// Hysteresis thresholds for the multi-face state, in consecutive frames.
    /// Filters out single-frame Vision flicker that otherwise pops ovals on/off
    /// at detector frame rate (~20-30Hz).
    private static let multiFaceEnterFrames: Int = 2
    private static let multiFaceExitFrames: Int = 3

    /// EMA blend factor for per-face oval coordinates. Lower = more smoothing.
    /// 0.4 keeps response snappy while killing the per-frame "throb" Vision bboxes
    /// produce on stationary faces.
    private static let multiFaceSmoothingAlpha: CGFloat = 0.4

    /// Hysteresis + smoothing state for multi-face detection. Reset whenever the
    /// presenter leaves a state that draws per-face ovals (manual transition,
    /// help dialog, lifecycle resets).
    private var multiFaceConfirmCount: Int = 0
    private var multiFaceClearCount: Int = 0
    private var multiFaceActive: Bool = false
    private var smoothedMultiFaceBoxes: [CGRect] = []

    private let validationId: String

    // MARK: - Injection Detection

    private let detectionReporter: DetectionReporter?
    private var runtimeDetectionTask: Task<Void, Never>?
    private static let runtimeDetectionInterval: TimeInterval = 10.0

    init(
        view: PassiveCapturePresenterToView,
        interactor: PassiveCapturePresenterToInteractor?,
        router: ValidationRouter,
        validationId: String,
        useAutocapture: Bool = true,
        timeProvider: TimeProvider = RealTimeProvider(),
        detectionReporter: DetectionReporter? = ValidationConfig.shared.detectionReporter
    ) {
        self.view = view
        self.interactor = interactor
        self.router = router
        self.validationId = validationId
        self.useAutocapture = useAutocapture
        self.timeProvider = timeProvider
        self.detectionReporter = detectionReporter
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

        // Cancel any existing countdown before starting a new one
        countdownTask?.cancel()
        countdownTask = Task { [weak self] in
            guard let self else { return }
            while self.countdown > 0 {
                try? await self.timeProvider.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                self.countdown -= 1
                await self.updateUI()
            }
            guard !Task.isCancelled else { return }
            await self.beginWaitingForFace()
        }
    }

    /// Moves to recording state but waits for face detection before actually recording.
    private func beginWaitingForFace() async {
        // We want to process frames and show feedback, but not start recording yet.
        lifecycleState = .ready

        currentState = .recording
        currentFeedback = .showFace

        // Start manual timeout window (4s) while we wait for a face
        startProcessingTimer()

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
        startProcessingTimer()

        await updateUI()

        // Start camera recording immediately, UI handles timing
        await view?.startRecording()
    }

    /// Checks if manual capture timeout has been reached (thread-safe)
    /// Returns true if 4 seconds have passed since video processing started
    private func hasManualTimeout() -> Bool {
        timingLock.withLock {
            guard let startTime = videoProcessingStartTime else {
                return false
            }

            let elapsed = timeProvider.now.timeIntervalSince(startTime)
            return elapsed >= Self.manualTimeoutSeconds
        }
    }

    /// Resets the video processing timer (thread-safe)
    private func resetProcessingTimer() {
        timingLock.withLock {
            videoProcessingStartTime = nil
        }
    }

    /// Starts the video processing timer (thread-safe)
    private func startProcessingTimer() {
        timingLock.lock()
        videoProcessingStartTime = timeProvider.now
        timingLock.unlock()
    }

    /// Starts the face detection timer (thread-safe)
    private func startFaceDetectionTimer() {
        timingLock.withLock {
            faceDetectionStartTime = timeProvider.now
        }
    }

    /// Resets the face detection timer (thread-safe)
    private func resetFaceDetectionTimer() {
        timingLock.withLock {
            faceDetectionStartTime = nil
        }
    }

    /// Checks if sufficient consecutive face detection time has elapsed (thread-safe)
    /// Returns true if 1 second has passed since face detection started
    private func hasSufficientFaceDetection() -> Bool {
        timingLock.withLock {
            guard let startTime = faceDetectionStartTime else {
                return false
            }

            let elapsed = timeProvider.now.timeIntervalSince(startTime)
            return elapsed >= Self.requiredDetectionTime
        }
    }

    /// Checks if the detected face is centered on the oval guide with
    /// appropriate size. The oval is centered in the overlay which uses
    /// extendingIntoSafeArea(), so its center is at (0.5, 0.5) in
    /// normalized screen coordinates. Vision framework returns normalized
    /// coordinates with Y-origin at bottom-left, but since the oval center
    /// is at 0.5 on both axes, the distance calculation is symmetric.
    private func isFaceCenteredOnOval(_ face: DetectionResult) -> Bool {
        let bbox = face.boundingBox
        let faceHeight = bbox.height
        let faceCenterX = bbox.midX
        let faceCenterY = bbox.midY

        // Check face size (height-based since faces are taller than wide)
        guard faceHeight >= Self.minFaceHeight,
              faceHeight <= Self.maxFaceHeight else {
            return false
        }

        // Oval center is at (0.5, 0.5) in the full-screen overlay
        let ovalCenterX: CGFloat = 0.5
        let ovalCenterY: CGFloat = 0.5

        // Euclidean distance from face center to oval center
        let distance = sqrt(
            pow(faceCenterX - ovalCenterX, 2)
                + pow(faceCenterY - ovalCenterY, 2)
        )

        return distance <= Self.centerDistanceThreshold
    }

    /// Returns true when the face is sufficiently frontal for autocapture.
    /// Null yaw (Vision could not compute it) returns true — we never block on missing data.
    func isFaceFacingForward(_ face: DetectionResult) -> Bool {
        guard case .face(_, let yaw) = face.category else { return true }
        guard let yaw else { return true }
        return abs(yaw) < Self.yawThresholdRadians
    }

    /// Transitions to manual mode with error message (used when autocapture times out)
    private func transitionToManualWithError() async {
        resetFaceDetectionTimer()
        resetMultiFaceState()
        currentState = .manual
        currentFeedback = .showFace
        await view?.updateDetectedFaceBoundingBoxes([])
        await updateUI()
    }

    /// Transitions to manual mode without error message (used when autocapture is disabled)
    private func transitionToManualWithoutError() async {
        resetFaceDetectionTimer()
        resetMultiFaceState()
        currentState = .manual
        currentFeedback = .none
        await view?.updateDetectedFaceBoundingBoxes([])
        await updateUI()
    }

    /// Advances the multi-face hysteresis state and emits boxes when active.
    /// Returns `true` when the caller in `detectionsReceived` should hold the
    /// current UI and skip the single/no-face branches — either because we
    /// just emitted multi-face boxes, or because we are in the enter-warmup
    /// window waiting for confirmation. Returns `false` to let those run.
    private func shouldWaitAfterApplyingHysteresis(
        isMultiFaceFrame: Bool,
        renderableBoxes: [CGRect]
    ) async -> Bool {
        advanceHysteresisCounters(isMultiFaceFrame: isMultiFaceFrame)

        if multiFaceActive, !isMultiFaceFrame, multiFaceClearCount >= Self.multiFaceExitFrames {
            multiFaceActive = false
            smoothedMultiFaceBoxes = []
        } else if !multiFaceActive, isMultiFaceFrame, multiFaceConfirmCount >= Self.multiFaceEnterFrames {
            multiFaceActive = true
        }

        guard multiFaceActive else {
            // Inactive: hold the prior UI only while the enter-warmup window
            // is still confirming; otherwise let the caller continue.
            return isMultiFaceFrame
        }

        // Active: emit smoothed boxes for the current frame, or hold the
        // previous smoothed boxes through the exit-warmup window so a
        // 1-frame dropout doesn't visibly flicker the ovals.
        let toEmit = isMultiFaceFrame
            ? smoothMultiFaceBoxes(renderableBoxes)
            : smoothedMultiFaceBoxes
        await view?.updateDetectedFaceBoundingBoxes(toEmit)
        await resetTimerAndUpdateFeedback(.multiplePeople)
        return true
    }

    private func advanceHysteresisCounters(isMultiFaceFrame: Bool) {
        guard isMultiFaceFrame else {
            multiFaceClearCount += 1
            multiFaceConfirmCount = 0
            return
        }
        multiFaceConfirmCount += 1
        multiFaceClearCount = 0
    }

    /// Resets the multi-face hysteresis and smoothing state. Call whenever the
    /// presenter stops emitting per-face ovals so a later re-entry starts clean.
    private func resetMultiFaceState() {
        multiFaceConfirmCount = 0
        multiFaceClearCount = 0
        multiFaceActive = false
        smoothedMultiFaceBoxes = []
    }

    /// EMA-smooths per-face boxes against the previous frame so stationary faces
    /// stop "throbbing" between Vision frames. Boxes are sorted by midX so the
    /// SwiftUI ForEach offset stays bound to the same face across frames (kills
    /// detector-side ID switches).
    private func smoothMultiFaceBoxes(_ rawBoxes: [CGRect]) -> [CGRect] {
        let sortedRaw = rawBoxes.sorted { $0.midX < $1.midX }

        guard !smoothedMultiFaceBoxes.isEmpty,
              smoothedMultiFaceBoxes.count == sortedRaw.count else {
            // First frame in a multi-face episode, or face count changed —
            // snap to the new boxes instead of blending across mismatched counts.
            smoothedMultiFaceBoxes = sortedRaw
            return sortedRaw
        }

        let alpha = Self.multiFaceSmoothingAlpha
        let blended = zip(sortedRaw, smoothedMultiFaceBoxes).map { raw, prev in
            CGRect(
                x: prev.minX * (1 - alpha) + raw.minX * alpha,
                y: prev.minY * (1 - alpha) + raw.minY * alpha,
                width: prev.width * (1 - alpha) + raw.width * alpha,
                height: prev.height * (1 - alpha) + raw.height * alpha
            )
        }
        smoothedMultiFaceBoxes = blended
        return blended
    }
}

extension PassiveCapturePresenter: PassiveCaptureViewToPresenter {
    func viewDidLoad() async {
        let uploadUrl = await router?.consumeUploadUrl()
        interactor?.setUploadUrl(uploadUrl)
        if !isSettingUpCamera {
            debugLog("🟢 PassiveCapturePresenter: viewDidLoad - triggering initial setup")
            isSettingUpCamera = true
            await view?.setupCamera()
        }
        await updateUI()
    }

    // MARK: - Logging Methods

    private func logViewRendered() async {
        guard let logger = try? TruoraLoggerImplementation.shared else {
            return
        }
        await logger.logView(
            viewName: "render_\(Self.viewName)_succeeded",
            level: .info,
            retention: .oneWeek,
            metadata: [
                "name": Self.viewName,
                "validation_type": Self.validationType
            ]
        )
    }

    private func logCameraOpened() async {
        guard let logger = try? TruoraLoggerImplementation.shared else {
            return
        }
        await logger.logCamera(
            eventName: "camera_successfully_opened",
            level: .info,
            errorMessage: nil,
            retention: .oneWeek,
            metadata: [
                "validation_type": Self.validationType,
                "selected_camera": "front"
            ]
        )
    }

    private func logCameraOpenFailed(errorMessage: String) async {
        guard let logger = try? TruoraLoggerImplementation.shared else {
            return
        }
        await logger.logCamera(
            eventName: "open_camera_failed",
            level: .error,
            errorMessage: errorMessage,
            retention: .oneWeek,
            metadata: [
                "validation_type": Self.validationType,
                "selected_camera": "front"
            ]
        )
    }

    private func logCameraPermissionGranted() async {
        guard let logger = try? TruoraLoggerImplementation.shared else {
            return
        }
        await logger.logCamera(
            eventName: "camera_permissions_granted",
            level: .info,
            errorMessage: nil,
            retention: .oneWeek,
            metadata: [
                "validation_type": Self.validationType,
                "selected_camera": "front"
            ]
        )
    }

    private func logCameraCrashed(errorMessage: String) async {
        guard let logger = try? TruoraLoggerImplementation.shared else {
            return
        }
        await logger.logCamera(
            eventName: "camera_crashed",
            level: .fatal,
            errorMessage: errorMessage,
            retention: .oneMonth,
            metadata: [
                "validation_type": Self.validationType,
                "selected_camera": "front"
            ]
        )
    }

    func cameraError(_ errorMessage: String) async {
        if lifecycleState == .uninitialized || lifecycleState == .stopped {
            await logCameraOpenFailed(errorMessage: errorMessage)
        } else {
            await logCameraCrashed(errorMessage: errorMessage)
        }
    }

    func viewWillAppear() async {
        // On initial load, skip restart logic as it's handled by viewDidLoad
        guard lifecycleState != .uninitialized else {
            return
        }

        // If upload in progress, don't try to re-setup; upload flow controls the camera.
        // Background/foreground behavior is handled via appWillResignActive/appDidBecomeActive.
        guard uploadState != .uploading, uploadState != .success else {
            debugLog(
                "🟢 PassiveCapturePresenter: viewWillAppear - skipping upload restart "
                    + "(uploadState: \(uploadState))"
            )
            return
        }

        // Re-try setup when returning to view (e.g. from Settings or background)
        debugLog("🟢 viewWillAppear, checking camera permissions...")
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        switch status {
        case .authorized:
            await logCameraPermissionGranted()
            if lifecycleState == .stopped, !isSettingUpCamera {
                debugLog("✅ Permission granted, restarting camera...")
                isSettingUpCamera = true
                await resetToInitialState()
                await view?.setupCamera()
            }
        case .notDetermined:
            if !isSettingUpCamera {
                debugLog("🟠 Permission not determined, triggering setup...")
                isSettingUpCamera = true
                await view?.setupCamera()
            }
        case .denied, .restricted:
            debugLog("❌ Permission still denied")
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
        countdownTask?.cancel()
        countdownTask = nil
        resetFaceDetectionTimer()
        resetProcessingTimer()

        // Reset recording button state
        await view?.resetRecordingInProgress()

        await updateUI()
    }

    func cameraReady() async {
        isSettingUpCamera = false
        lifecycleState = .ready
        showSettingsPrompt = false

        // Log view and camera events concurrently (independent operations)
        async let logView: Void = logViewRendered()
        async let logCamera: Void = logCameraOpened()
        _ = await (logView, logCamera)

        // Layer 2: Report camera detection
        let shouldBlock = await reportDetectionLayer("camera")
        if shouldBlock {
            stopRuntimeDetection()
            await router?.handleError(TruoraException.sdk(SDKError(type: .validationInterrupted)))
            return
        }

        // Layer 3: Start periodic runtime detection
        startRuntimeDetection()

        await updateUI()

        switch pendingCameraReadyAction {
        case .resumeFromSuspendWasRecordingAuto:
            pendingCameraReadyAction = .none
            // Restart at detection (no countdown) and let stable face trigger recording.
            await beginWaitingForFace()
        case .resumeFromSuspendWasRecordingManual:
            pendingCameraReadyAction = .none
            // Restart manual and immediately start recording again.
            await transitionToManualWithoutError()
            await startRecording()
        case .none:
            if useAutocapture {
                debugLog("🟢 PassiveCapturePresenter: Camera ready, starting countdown")
                await startCountdown()
            } else {
                debugLog("🟢 PassiveCapturePresenter: Camera ready, autocapture disabled")
                await transitionToManualWithoutError()
            }
        }
    }

    // MARK: - Injection Detection Methods

    private func reportDetectionLayer(_ layer: String) async -> Bool {
        guard let reporter = detectionReporter else { return false }
        return await reporter.reportLayer(layer)
    }

    private func startRuntimeDetection() {
        stopRuntimeDetection()
        guard detectionReporter != nil else { return }

        runtimeDetectionTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(
                    nanoseconds: UInt64(Self.runtimeDetectionInterval * 1_000_000_000)
                )
                guard !Task.isCancelled else { break }
                let shouldBlock = await self?.reportDetectionLayer("runtime") ?? false
                if shouldBlock {
                    self?.stopRuntimeDetection()
                    await self?.router?.handleError(
                        TruoraException.sdk(SDKError(type: .validationInterrupted))
                    )
                    break
                }
            }
        }
    }

    private func stopRuntimeDetection() {
        runtimeDetectionTask?.cancel()
        runtimeDetectionTask = nil
    }

    func videoRecordingCompleted(videoData: Data) async {
        debugLog("🟢 PassiveCapturePresenter: Received video data (\(videoData.count) bytes)")
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
        debugLog("🟢 Last frame (\(frameData.count) bytes)")
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

    /// Resets the face detection timer and updates feedback if not recording.
    private func resetTimerAndUpdateFeedback(_ feedback: FeedbackType) async {
        resetFaceDetectionTimer()
        guard lifecycleState != .recording else { return }
        currentFeedback = feedback
        await updateUI()
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

        let renderableBoxes = faces
            .map(\.boundingBox)
            .filter { $0.height >= Self.minMultiFaceRenderHeight }
        // Classify multi-face on the raw face count so the .multiplePeople
        // toast still fires when a tiny background face is filtered out by
        // minMultiFaceRenderHeight; that filter only gates rendering.
        let isMultiFaceFrame = faces.count >= 2

        if await shouldWaitAfterApplyingHysteresis(
            isMultiFaceFrame: isMultiFaceFrame,
            renderableBoxes: renderableBoxes
        ) {
            return
        }

        guard !faces.isEmpty else {
            await view?.updateDetectedFaceBoundingBoxes([])
            await resetTimerAndUpdateFeedback(.showFace)
            return
        }

        await view?.updateDetectedFaceBoundingBoxes([])

        // Single face detected - check if centered on the oval
        guard isFaceCenteredOnOval(faces[0]) else {
            debugLog("🟠 Face not centered on oval, showing CENTER_FACE feedback")
            await resetTimerAndUpdateFeedback(.centerFace)
            return
        }

        guard isFaceFacingForward(faces[0]) else {
            debugLog("🟠 Face not facing forward, showing LOOK_FORWARD feedback")
            await resetTimerAndUpdateFeedback(.lookForward)
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
        // Stop runtime injection detection
        stopRuntimeDetection()

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
        countdownTask?.cancel()
        resetProcessingTimer()
    }

    func appWillResignActive() async {
        // Snapshot state so we can resume correctly.
        wasRecordingAtSuspend = (lifecycleState == .recording)
        stateAtSuspend = currentState
        uploadStateAtSuspend = uploadState
        wasHelpOpenAtSuspend = showHelpDialog

        // Stop time-based flows; on resume we require fresh detections.
        countdownTask?.cancel()
        countdownTask = nil
        resetFaceDetectionTimer()
        resetProcessingTimer()

        // If uploading, do not tear down camera; keep it paused/frozen and let upload continue.
        if uploadState == .uploading || uploadState == .success {
            await view?.pauseCamera()
            return
        }

        // If we were recording, stop it without producing media.
        if lifecycleState == .recording {
            await view?.pauseVideo()
            lifecycleState = .ready
        }

        // Pause session (do not tear down) to preserve preview layer state.
        await view?.pauseCamera()
    }

    func appDidBecomeActive() async {
        // If uploading (or already completed), do not attempt to restart camera.
        if uploadState == .uploading || uploadState == .success {
            return
        }

        // If the view isn't visible anymore, viewWillAppear/viewDidLoad will handle restart.
        guard lifecycleState != .uninitialized else { return }

        // If camera was stopped while app was inactive (e.g., upload failed/completed but we didn't
        // navigate away), restart it now.
        if lifecycleState == .stopped, !isSettingUpCamera {
            isSettingUpCamera = true
            await view?.setupCamera()
            return
        }

        // If recording was interrupted by backgrounding, restart flow as requested.
        if wasRecordingAtSuspend {
            // Avoid overwriting an existing pending action if we get multiple
            // suspend/resume cycles while setup is still in flight.
            guard pendingCameraReadyAction == .none, !isSettingUpCamera else {
                return
            }

            wasRecordingAtSuspend = false
            if useAutocapture {
                pendingCameraReadyAction = .resumeFromSuspendWasRecordingAuto
            } else {
                pendingCameraReadyAction = .resumeFromSuspendWasRecordingManual
            }

            // Clean restart to ensure recording can start reliably.
            await view?.stopCamera()
            lifecycleState = .stopped
            isSettingUpCamera = true
            await view?.setupCamera()
            return
        }

        // If we were in countdown when user left, the timer was invalidated so countdown is stuck.
        // Restart countdown from 3 so it runs again.
        if stateAtSuspend == .countdown {
            stateAtSuspend = nil
            await startCountdown()
            await view?.resumeCamera()
            if wasHelpOpenAtSuspend {
                showHelpDialog = true
                await updateUI()
            }
            wasHelpOpenAtSuspend = false
            uploadStateAtSuspend = .none
            return
        }

        // Otherwise, just resume the paused session and keep UI/state as-is.
        await view?.resumeCamera()

        // If we were in recording (showFace phase) waiting for face or manual timeout, we reset the
        // processing timer on suspend so the 4s manual timeout never fired. Restart it so the
        // fallback to manual "start recording" can trigger after 4s.
        if stateAtSuspend == .recording, lifecycleState != .recording {
            startProcessingTimer()
            stateAtSuspend = nil
        }

        // If help was open during suspend, keep it open (no auto-restart).
        if wasHelpOpenAtSuspend {
            showHelpDialog = true
            await updateUI()
        }

        // Clear one-shot suspend snapshot flags.
        wasHelpOpenAtSuspend = false
        stateAtSuspend = nil
        uploadStateAtSuspend = .none
    }

    func cameraPermissionDenied() async {
        isSettingUpCamera = false
        debugLog("❌ PassiveCapturePresenter: Camera permission denied")

        await view?.stopCamera()
        lifecycleState = .stopped

        await logCameraOpenFailed(errorMessage: "Camera permission denied")

        await router?.handleError(CameraError.permissionDenied().toTruoraException())
    }

    func handleCaptureEvent(_ event: PassiveCaptureEvent) async {
        switch event {
        case .helpRequested:
            await handleHelpRequested()
        case .helpDismissed:
            await handleHelpDismissed()
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

    private func handleHelpRequested() async {
        stateAtHelp = currentState
        feedbackAtHelp = currentFeedback

        // Pause any timed flows while help is visible.
        countdownTask?.cancel()
        countdownTask = nil
        resetFaceDetectionTimer()

        wasRecordingBeforeHelp = (lifecycleState == .recording)
        if lifecycleState == .recording {
            await view?.pauseVideo()
            lifecycleState = .ready
        }
        showHelpDialog = true
        resetMultiFaceState()
        await view?.updateDetectedFaceBoundingBoxes([])
        await updateUI()
    }

    private func handleHelpDismissed() async {
        showHelpDialog = false
        if wasRecordingBeforeHelp {
            wasRecordingBeforeHelp = false
            lifecycleState = .ready
            if useAutocapture {
                // Restart at detection and let stable face trigger recording.
                await beginWaitingForFace()
            } else {
                // Return to manual and restart recording automatically.
                currentState = .manual
                currentFeedback = .none
                await updateUI()
                await startRecording()
            }
        } else {
            // Restore a sane state after dismissing help.
            if useAutocapture {
                switch stateAtHelp {
                case .countdown:
                    await startCountdown()
                case .recording:
                    await beginWaitingForFace()
                case .manual:
                    await transitionToManualWithoutError()
                case .none:
                    currentFeedback = feedbackAtHelp
                    await updateUI()
                }
            } else {
                await transitionToManualWithoutError()
            }
        }

        stateAtHelp = nil
        feedbackAtHelp = .none
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
            debugLog("⚠️ PassiveCapturePresenter: Recording already stopped, skipping stop call")
        }
    }
}

extension PassiveCapturePresenter: PassiveCaptureInteractorToPresenter {
    func videoUploadCompleted(validationId: String) async {
        uploadState = .success
        await view?.resetRecordingInProgress()

        // Log successful face capture
        await interactor?.logFaceCaptureSucceeded()

        await updateUI()

        // Stop camera before navigating to results
        await view?.stopCamera()
        lifecycleState = .stopped

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
        await view?.resetRecordingInProgress()

        // Log failed face capture
        let errorMessage = error.errorDescription ?? "Unknown error"
        await interactor?.logFaceCaptureFailed(errorMessage: errorMessage)

        await updateUI()

        // Stop camera before dismissing flow
        await view?.stopCamera()
        lifecycleState = .stopped

        // Validation timeout - navigate to result screen to show failure
        if isValidationError(error) {
            guard let router else {
                debugLog("Router is nil, cannot navigate to result after validation timeout")
                return
            }
            do {
                try await router.navigateToResult(
                    validationId: validationId,
                    loadingType: .face
                )
            } catch let navError {
                debugLog("Navigation to result failed during validation timeout: \(navError)")
                await router.handleError(
                    TruoraException.sdk(
                        SDKError(
                            type: .internalError,
                            details: "Navigation failed: \(navError.localizedDescription)"
                        )
                    )
                )
            }
            return
        }

        await router?.handleError(error)
    }

    private func isValidationError(_ error: TruoraException) -> Bool {
        guard case .sdk(let sdkError) = error else { return false }
        return sdkError.type == .validationError
    }
}
