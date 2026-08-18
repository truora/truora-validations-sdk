//
//  DocumentCapturePresenter.swift
//  validations
//
//  Created by Truora on 26/12/25.
//

import AVFoundation
import Foundation
import TruoraCamera

/// Camera lifecycle state for document capture
private enum CameraLifecycleState {
    case uninitialized
    case stopped
    case ready
    case capturing
}

private struct EvaluationContext {
    let side: DocumentCaptureSide
    let photoData: Data
    let country: String
    let documentType: String
}

/// Represents a detected document with its confidence scores
private struct DocumentDetection {
    let document: DetectionResult
    let frontScore: Float
    let backScore: Float

    var isFrontSide: Bool {
        frontScore >= backScore
    }
}

// MARK: - Detection State Manager

/// Manages detection timing and debouncing state, protected by NSLock
/// against interleaving at async suspension points
private final class DetectionStateManager {
    private let lock = NSLock()

    /// Autocapture mode flag - thread-safe atomic property
    private var _useAutocapture: Bool

    // Detection timing state
    private var documentDetectionStartTime: Date?
    private var detectionProcessingStartTime: Date?
    private var initialBoundingBox: CGRect?
    private var lastBoundingBox: CGRect?

    // Feedback debounce state
    private var pendingFeedbackType: DocumentFeedbackType?
    private var pendingFeedbackStartTime: Date?
    private var displayedFeedbackType: DocumentFeedbackType = .searching

    // Configuration
    private static let manualTimeoutSeconds: TimeInterval = 15.0
    private static let requiredDetectionTime: TimeInterval = 2.0
    private static let feedbackDebounceTime: TimeInterval = 0.3

    init(useAutocapture: Bool) {
        self._useAutocapture = useAutocapture
    }

    /// Thread-safe getter for useAutocapture
    var useAutocapture: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _useAutocapture
    }

    func startDetectionProcessingTimer() {
        lock.lock()
        detectionProcessingStartTime = Date()
        lock.unlock()
    }

    func resetDetectionProcessingTimer() {
        lock.lock()
        detectionProcessingStartTime = nil
        lock.unlock()
    }

    func resetDocumentDetectionTimer() {
        lock.lock()
        documentDetectionStartTime = nil
        initialBoundingBox = nil
        lock.unlock()
    }

    func hasManualTimeout() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard let startTime = detectionProcessingStartTime else { return false }
        return Date().timeIntervalSince(startTime) >= Self.manualTimeoutSeconds
    }

    func hasSufficientDocumentDetection() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard let startTime = documentDetectionStartTime else { return false }
        return Date().timeIntervalSince(startTime) >= Self.requiredDetectionTime
    }

    func startDocumentDetectionIfNeeded(with bbox: CGRect) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard documentDetectionStartTime == nil else { return false }
        documentDetectionStartTime = Date()
        initialBoundingBox = bbox
        return true
    }

    func setLastBoundingBox(_ bbox: CGRect?) {
        lock.lock()
        lastBoundingBox = bbox
        lock.unlock()
    }

    func getLastBoundingBox() -> CGRect? {
        lock.lock()
        defer { lock.unlock() }
        return lastBoundingBox
    }

    func getInitialBoundingBox() -> CGRect? {
        lock.lock()
        defer { lock.unlock() }
        return initialBoundingBox
    }

    func resetCaptureState() {
        lock.lock()
        lastBoundingBox = nil
        displayedFeedbackType = .scanning
        pendingFeedbackType = nil
        pendingFeedbackStartTime = nil
        lock.unlock()
    }

    func setDisplayedFeedback(_ feedback: DocumentFeedbackType) {
        lock.lock()
        displayedFeedbackType = feedback
        pendingFeedbackType = nil
        pendingFeedbackStartTime = nil
        lock.unlock()
    }

    func setDisplayedFeedbackAndClearBoundingBox(_ feedback: DocumentFeedbackType) {
        lock.lock()
        displayedFeedbackType = feedback
        lastBoundingBox = nil
        pendingFeedbackType = nil
        pendingFeedbackStartTime = nil
        lock.unlock()
    }

    func resetFeedbackDebounce() {
        lock.lock()
        pendingFeedbackType = nil
        pendingFeedbackStartTime = nil
        lock.unlock()
    }

    /// Updates feedback with debouncing. Returns (shouldUpdate, newFeedback)
    func updateDebouncedFeedback(_ newFeedback: DocumentFeedbackType)
    -> (Bool, DocumentFeedbackType) {
        lock.lock()
        defer { lock.unlock() }

        if newFeedback == .scanning || newFeedback == .scanningManual {
            displayedFeedbackType = newFeedback
            pendingFeedbackType = nil
            pendingFeedbackStartTime = nil
            return (true, newFeedback)
        }

        if newFeedback == displayedFeedbackType {
            pendingFeedbackType = nil
            pendingFeedbackStartTime = nil
            return (false, displayedFeedbackType)
        }

        if pendingFeedbackType != newFeedback {
            pendingFeedbackType = newFeedback
            pendingFeedbackStartTime = Date()
            return (false, displayedFeedbackType)
        }

        guard let startTime = pendingFeedbackStartTime else {
            pendingFeedbackType = newFeedback
            pendingFeedbackStartTime = Date()
            return (false, displayedFeedbackType)
        }

        if Date().timeIntervalSince(startTime) >= Self.feedbackDebounceTime {
            displayedFeedbackType = newFeedback
            pendingFeedbackType = nil
            pendingFeedbackStartTime = nil
            return (true, newFeedback)
        }

        return (false, displayedFeedbackType)
    }

    /// Thread-safe check-and-modify for useAutocapture transition.
    /// Returns true if autocapture was enabled and is now disabled.
    func disableAutocaptureIfEnabled() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard _useAutocapture else { return false }
        _useAutocapture = false
        return true
    }
}

final class DocumentCapturePresenter {
    weak var view: DocumentCapturePresenterToView?
    var interactor: DocumentCapturePresenterToInteractor?
    weak var router: ValidationRouter?

    private let validationId: String

    private var currentSide: DocumentCaptureSide = .front
    private var feedbackType: DocumentFeedbackType = .scanning
    private var showHelpDialog: Bool = false
    private var showRotationAnimation: Bool = false
    private var showLoadingScreen: Bool = false

    private var frontPhotoStatus: CaptureStatus?
    private var backPhotoStatus: CaptureStatus?
    private var isSingleSidedDocument: Bool = false

    private var uploadState: UploadState = .none

    private static let maxAttempts = 3
    private static let maxEvaluationErrorRetries = 2

    private var frontEvaluationFailureAttempts: Int = 0
    private var backEvaluationFailureAttempts: Int = 0

    private var evaluationErrorRetryCount: Int = 0
    private var currentEvaluationContext: EvaluationContext?
    private var sideNeedingPreviewClear: DocumentCaptureSide?

    // MARK: - Injection Detection

    private let detectionReporter: DetectionReporter?
    private var runtimeDetectionTask: Task<Void, Never>?
    private static let runtimeDetectionInterval: TimeInterval = 10.0

    private static let rotationAnimationNanoseconds: UInt64 = 4_000_000_000
    private static let successStateHoldNanoseconds: UInt64 = 1_000_000_000

    // MARK: - Autodetection Properties

    private var lifecycleState: CameraLifecycleState = .uninitialized
    private let timeProvider: TimeProvider
    private let detectionState: DetectionStateManager

    // Detection quality thresholds
    private static let stabilityThreshold: CGFloat = 0.015
    private static let maxTotalMovement: CGFloat = 0.08
    private static let centerDistanceThreshold: CGFloat = 0.2
    private static let minDocumentWidth: CGFloat = 0.5
    private static let maxDocumentWidth: CGFloat = 0.9

    /// Constants for logging
    private static let viewName = "doc_capture"
    private static let validationType = "document_validation"

    init(
        view: DocumentCapturePresenterToView,
        interactor: DocumentCapturePresenterToInteractor?,
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
        self.detectionState = DetectionStateManager(useAutocapture: useAutocapture)
        self.timeProvider = timeProvider
        self.detectionReporter = detectionReporter
        self.currentSide = .front
        self.feedbackType = useAutocapture ? .searching : .scanningManual
    }

    /// Thread-safe accessor for useAutocapture state
    private var useAutocapture: Bool {
        detectionState.useAutocapture
    }

    private func updateUI(
        frontPhotoDataUpdate: Data? = nil,
        backPhotoDataUpdate: Data? = nil,
        clearFrontPhoto: Bool = false,
        clearBackPhoto: Bool = false,
        audioInstruction: TruoraAudioInstruction? = nil
    ) async {
        await view?.updateComposeUI(
            side: currentSide,
            feedbackType: feedbackType,
            showHelpDialog: showHelpDialog,
            showRotationAnimation: showRotationAnimation,
            showLoadingScreen: showLoadingScreen,
            uploadState: uploadState,
            frontPhotoData: frontPhotoDataUpdate,
            frontPhotoStatus: frontPhotoStatus,
            backPhotoData: backPhotoDataUpdate,
            backPhotoStatus: backPhotoStatus,
            clearFrontPhoto: clearFrontPhoto,
            clearBackPhoto: clearBackPhoto,
            audioInstruction: audioInstruction
        )
    }

    private func transitionToBackSideWithRotation() async {
        uploadState = .none

        showRotationAnimation = true
        await updateUI()

        await view?.resumeCamera()

        try? await timeProvider.sleep(nanoseconds: Self.rotationAnimationNanoseconds)

        showRotationAnimation = false
        currentSide = .back
        feedbackType = useAutocapture ? .scanning : .scanningManual
        evaluationErrorRetryCount = 0
        currentEvaluationContext = nil

        // Reset detection timers for back side
        detectionState.resetDocumentDetectionTimer()
        detectionState.startDetectionProcessingTimer()
        lifecycleState = .ready

        await updateUI(audioInstruction: .placeTheBack)
    }

    /// Transitions to manual mode when autocapture timeout is reached
    private func transitionToManualMode() async {
        detectionState.resetDocumentDetectionTimer()
        feedbackType = .scanningManual
        detectionState.setDisplayedFeedback(.scanningManual)
        await updateUI(audioInstruction: .documentNotFound)
    }

    /// Updates feedback with debouncing, returns true if UI should update
    private func updateDebouncedFeedback(_ newFeedback: DocumentFeedbackType) -> Bool {
        let (shouldUpdate, feedback) = detectionState.updateDebouncedFeedback(newFeedback)
        if shouldUpdate {
            feedbackType = feedback
        }
        return shouldUpdate
    }

    private func isQualityDetection(_ document: DetectionResult) -> Bool {
        let bbox = document.boundingBox
        let width = bbox.width
        let centerX = bbox.midX
        let centerY = bbox.midY

        let distance = sqrt(pow(centerX - 0.5, 2) + pow(centerY - 0.5, 2))

        let isRightSize = width >= Self.minDocumentWidth && width <= Self.maxDocumentWidth
        let isCentered = distance <= Self.centerDistanceThreshold

        return isRightSize && isCentered
    }

    private func isStableDetection(_ currentBbox: CGRect) -> Bool {
        let lastBbox = detectionState.getLastBoundingBox()
        let initBbox = detectionState.getInitialBoundingBox()

        guard let lastBbox, let initBbox else {
            return true
        }

        let dx = abs(currentBbox.midX - lastBbox.midX)
        let dy = abs(currentBbox.midY - lastBbox.midY)
        let dw = abs(currentBbox.width - lastBbox.width)
        let dh = abs(currentBbox.height - lastBbox.height)

        let isFrameStable = dx < Self.stabilityThreshold && dy < Self.stabilityThreshold
            && dw < Self.stabilityThreshold && dh < Self.stabilityThreshold

        let tdx = abs(currentBbox.midX - initBbox.midX)
        let tdy = abs(currentBbox.midY - initBbox.midY)
        let tdw = abs(currentBbox.width - initBbox.width)
        let tdh = abs(currentBbox.height - initBbox.height)

        let isTotalStable = tdx < Self.maxTotalMovement && tdy < Self.maxTotalMovement
            && tdw < Self.maxTotalMovement && tdh < Self.maxTotalMovement

        return isFrameStable && isTotalStable
    }

    private func updateDetectionFeedback(_ document: DetectionResult) {
        let bbox = document.boundingBox
        let newFeedback: DocumentFeedbackType =
            if bbox.width < Self.minDocumentWidth {
                .closer
            } else if bbox.width > Self.maxDocumentWidth {
                .further
            } else {
                .center
            }
        _ = updateDebouncedFeedback(newFeedback)
    }
}

extension DocumentCapturePresenter: DocumentCaptureViewToPresenter {
    func viewDidLoad() async {
        guard let router else {
            await view?.showError("Router not configured")
            return
        }

        let frontUploadUrl = await router.consumeFrontUploadUrl()
        let reverseUploadUrl = await router.consumeReverseUploadUrl()

        guard let frontUploadUrl, !frontUploadUrl.isEmpty else {
            await view?.showError("Missing front upload URL")
            return
        }

        let isSingleSided = (reverseUploadUrl == nil || reverseUploadUrl?.isEmpty == true)
        self.isSingleSidedDocument = isSingleSided

        if !isSingleSided {
            guard let reverseUploadUrl, !reverseUploadUrl.isEmpty else {
                await view?.showError("Missing reverse upload URL")
                return
            }
        }

        interactor?
            .setUploadUrls(
                frontUploadUrl: frontUploadUrl,
                reverseUploadUrl: reverseUploadUrl
            )

        // Initialize autodetection state
        feedbackType = useAutocapture ? .searching : .scanningManual

        if useAutocapture {
            detectionState.startDetectionProcessingTimer()
        }

        await view?.setupCamera()

        await updateUI()
    }

    func viewDidBecomeVisible() async {
        uploadState = .none
    }

    func viewWillAppear() async {
        // On initial load, skip restart logic as it's handled by viewDidLoad
        guard lifecycleState != .uninitialized else {
            return
        }

        guard uploadState != .uploading, uploadState != .success, uploadState != .navigatedToResult else {
            debugLog("🟢 DocumentCapturePresenter: viewWillAppear - skipping (uploadState: \(uploadState))")
            return
        }

        // Clear preview for side that failed evaluation when returning from feedback
        if let sideToClear = sideNeedingPreviewClear {
            sideNeedingPreviewClear = nil
            switch sideToClear {
            case .front:
                frontPhotoStatus = nil
                await updateUI(frontPhotoDataUpdate: nil, clearFrontPhoto: true)
            case .back:
                backPhotoStatus = nil
                await updateUI(backPhotoDataUpdate: nil, clearBackPhoto: true)
            default:
                break
            }
        }

        // Restart detection timers when returning (e.g., from background or feedback modal)
        if useAutocapture {
            detectionState.resetDocumentDetectionTimer()
            detectionState.startDetectionProcessingTimer()
        }

        await view?.setupCamera()
    }

    private func resetToInitialState() async {
        // Reset all state to initial values for a fresh start
        lifecycleState = .stopped
        feedbackType = useAutocapture ? .searching : .scanningManual

        detectionState.setDisplayedFeedbackAndClearBoundingBox(feedbackType)

        evaluationErrorRetryCount = 0
        currentEvaluationContext = nil

        // Reset detection timers and debounce state
        detectionState.resetDocumentDetectionTimer()
        detectionState.startDetectionProcessingTimer()
        detectionState.resetFeedbackDebounce()
        await updateUI()
    }

    func cameraReady() async {
        lifecycleState = .ready
        await updateUI(audioInstruction: .placeTheFront)

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
                "selected_camera": "back"
            ]
        )
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
                "selected_camera": "back"
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
                "selected_camera": "back"
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

    func cameraPermissionDenied() async {
        debugLog("❌ DocumentCapturePresenter: Camera permission denied")

        await view?.stopCamera()
        lifecycleState = .stopped

        await logCameraOpenFailed(errorMessage: "Camera permission denied")

        await router?.handleError(CameraError.permissionDenied().toTruoraException())
    }

    func viewWillDisappear() async {
        // Stop runtime injection detection
        stopRuntimeDetection()

        // Pause video first to discard any in-progress recording
        if lifecycleState == .capturing {
            await view?.pauseVideo()
        }

        // Then stop camera completely (resets skipMediaNotification = false for clean restart)
        await view?.stopCamera()

        // Set lifecycle state to stopped so we can restart when returning
        lifecycleState = .stopped

        // Clean up timers and debounce state
        detectionState.resetDocumentDetectionTimer()
        detectionState.resetDetectionProcessingTimer()
        detectionState.resetFeedbackDebounce()
    }

    func appWillResignActive() async {
        if uploadState == .uploading || uploadState == .success || uploadState == .navigatedToResult {
            await view?.pauseCamera()
            return
        }

        // On capture screen: stop camera so we can restart cleanly on resume.
        if lifecycleState == .capturing {
            await view?.pauseVideo()
        }
        await view?.stopCamera()
        lifecycleState = .stopped
        detectionState.resetDocumentDetectionTimer()
        detectionState.resetDetectionProcessingTimer()
        detectionState.resetFeedbackDebounce()
    }

    func appDidBecomeActive() async {
        if uploadState == .uploading || uploadState == .success || uploadState == .navigatedToResult {
            return
        }

        guard lifecycleState != .uninitialized else { return }

        if lifecycleState == .stopped {
            await view?.setupCamera()
            return
        }

        await view?.resumeCamera()
    }

    func photoCaptured(photoData: Data) async {
        guard uploadState != .uploading else {
            return
        }

        guard !photoData.isEmpty else {
            await view?.showError("Captured photo is empty")
            lifecycleState = .ready
            return
        }

        uploadState = .uploading
        lifecycleState = .capturing
        feedbackType = .scanning
        showLoadingScreen = true
        evaluationErrorRetryCount = 0

        // Reset detection timers during capture/upload
        detectionState.resetDocumentDetectionTimer()
        detectionState.resetDetectionProcessingTimer()

        switch currentSide {
        case .front:
            frontPhotoStatus = .loading
            await updateUI(frontPhotoDataUpdate: photoData)
            await handleCaptureFlow(side: .front, photoData: photoData)
        case .back:
            backPhotoStatus = .loading
            await updateUI(backPhotoDataUpdate: photoData)
            await handleCaptureFlow(side: .back, photoData: photoData)
        }
    }

    func handleCaptureEvent(_ event: DocumentAutoCaptureEvent) async {
        switch event {
        case .helpRequested:
            showHelpDialog = true
            await updateUI()
        case .helpDismissed:
            showHelpDialog = false
            // Reset detection state when returning from help
            if useAutocapture {
                detectionState.resetDocumentDetectionTimer()
                detectionState.startDetectionProcessingTimer()
                detectionState.resetFeedbackDebounce()
                feedbackType = .searching
                detectionState.setDisplayedFeedback(.searching)
                lifecycleState = .ready
            }

            await updateUI()
        case .switchToManualMode:
            showHelpDialog = false
            feedbackType = .scanningManual
            detectionState.setDisplayedFeedback(.scanningManual)
            detectionState.resetDocumentDetectionTimer()
            detectionState.resetDetectionProcessingTimer()
            detectionState.resetFeedbackDebounce()
            await updateUI()
        case .manualCaptureRequested:
            await view?.takePicture()
        }
    }

    func manualCaptureTapped() async {
        await handleCaptureEvent(.manualCaptureRequested)
    }

    func cancelTapped() async {
        await view?.stopCamera()
        await router?.handleCancellation(loadingType: .document)
    }

    func retryTapped() async {
        await resetToInitialState()
        await view?.setupCamera()
    }

    func switchToManualCapture() async {
        // Called when autocapture model fails to load - switch to manual mode silently.
        // Uses DetectionStateManager's atomic flag to ensure thread-safe transition.
        // Only the first caller will succeed; subsequent calls are no-ops.
        guard detectionState.disableAutocaptureIfEnabled() else { return }
        await transitionToManualMode()
    }

    private func validateCurrentStateAndResetTimer() async -> Bool {
        // Skip detection processing if not in autocapture mode or already capturing/uploading
        guard useAutocapture,
              lifecycleState == .ready,
              feedbackType != .scanningManual,
              uploadState != .uploading,
              !showHelpDialog,
              !showLoadingScreen else {
            return false
        }

        // Check for manual timeout - transition to manual mode
        if detectionState.hasManualTimeout() {
            await transitionToManualMode()
            return false
        }

        return true
    }

    private func processDocumentDetection(_ detection: DocumentDetection) async {
        let isFront = detection.isFrontSide

        let isInvalidSide = (isFront && currentSide == .back) || (!isFront && currentSide == .front)
        if isInvalidSide {
            detectionState.resetDocumentDetectionTimer()
            if updateDebouncedFeedback(.rotate) {
                await updateUI(audioInstruction: .rotateDocument)
            }
            return
        }

        // Check quality and stability (Match Android)
        let bbox = detection.document.boundingBox
        if isQualityDetection(detection.document), isStableDetection(bbox) {
            // Document detected - start or continue detection timer (thread-safe)
            _ = detectionState.startDocumentDetectionIfNeeded(with: bbox)
            _ = updateDebouncedFeedback(.scanning)
        } else {
            detectionState.resetDocumentDetectionTimer()
            updateDetectionFeedback(detection.document)
        }

        detectionState.setLastBoundingBox(bbox)

        // Check if document has been detected long enough for auto-capture
        if detectionState.hasSufficientDocumentDetection() {
            lifecycleState = .capturing
            feedbackType = .scanning
            detectionState.resetDocumentDetectionTimer()
            detectionState.resetDetectionProcessingTimer()
            detectionState.resetCaptureState()

            await updateUI()
            await view?.takePicture()
        } else {
            await updateUI()
        }
    }

    func detectionsReceived(_ results: [DetectionResult]) async {
        guard await validateCurrentStateAndResetTimer() else { return }

        var detected: DocumentDetection?

        for document in results {
            guard case .document(let scores) = document.category,
                  let frontScore = scores?[0],
                  let backScore = scores?[1],
                  frontScore != 0 || backScore != 0 else {
                continue
            }

            if detected != nil {
                // Multiple documents
                detectionState.resetDocumentDetectionTimer()
                if updateDebouncedFeedback(.multipleDocuments) {
                    await updateUI()
                }
                return
            }

            detected = DocumentDetection(
                document: document, frontScore: frontScore, backScore: backScore
            )
        }

        guard let detected else {
            detectionState.resetDocumentDetectionTimer()
            detectionState.setLastBoundingBox(nil)
            if updateDebouncedFeedback(.locate) {
                await updateUI()
            }
            return
        }

        await processDocumentDetection(detected)
    }
}

extension DocumentCapturePresenter: DocumentCaptureInteractorToPresenter {
    func photoUploadCompleted(side: DocumentCaptureSide) async {
        showLoadingScreen = false
        await view?.resetCaptureInProgress()

        // Log doc capture succeeded
        await interactor?.logDocCaptureSucceeded(side: side, validationId: validationId)

        switch side {
        case .front:
            frontPhotoStatus = .success
            await updateUI()

            if isSingleSidedDocument {
                await navigateToResultAfterDelay()
            } else {
                await transitionToBackSideWithRotation()
            }

        case .back:
            backPhotoStatus = .success
            await updateUI()

            await navigateToResultAfterDelay()
        }
    }

    func photoUploadFailed(side: DocumentCaptureSide, error: TruoraException) async {
        showLoadingScreen = false
        await view?.resetCaptureInProgress()

        // Validation timeout - navigate to result screen to show failure
        if isValidationError(error) {
            await view?.stopCamera()
            uploadState = .navigatedToResult
            do {
                try await router?.navigateToResult(
                    validationId: validationId,
                    loadingType: .document
                )
            } catch {
                uploadState = .none
                // Reset state before showing error to allow user retry
                feedbackType = useAutocapture ? .searching : .scanningManual
                lifecycleState = .ready
                await view?.setupCamera()
                await view?.showError(error.localizedDescription)
            }
            return
        }

        // Other errors - show error and allow retry
        uploadState = .none
        feedbackType = useAutocapture ? .searching : .scanningManual
        lifecycleState = .ready

        // Log doc capture failed
        let errorMessage = error.errorDescription ?? "Unknown error"
        await interactor?.logDocCaptureFailed(side: side, validationId: validationId, errorMessage: errorMessage)

        if side == .front {
            frontPhotoStatus = nil
        } else if side == .back {
            backPhotoStatus = nil
        }

        // Reset detection timers for retry
        if useAutocapture {
            detectionState.resetDocumentDetectionTimer()
            detectionState.startDetectionProcessingTimer()
        }

        await updateUI()
        await view?.showError(
            error.errorDescription ?? "An error occurred during photo upload. Please try again."
        )
        await view?.setupCamera()
    }

    private func isValidationError(_ error: TruoraException) -> Bool {
        guard case .sdk(let sdkError) = error else { return false }
        return sdkError.type == .validationError
    }

    func imageEvaluationStarted(side: DocumentCaptureSide, previewData: Data) async {
        uploadState = .uploading
        showLoadingScreen = true
        feedbackType = .scanning
        evaluationErrorRetryCount = 0

        if side == .front {
            frontPhotoStatus = .loading
            await updateUI(frontPhotoDataUpdate: previewData)
        } else if side == .back {
            backPhotoStatus = .loading
            await updateUI(backPhotoDataUpdate: previewData)
        } else {
            await updateUI()
        }
    }

    func imageEvaluationSucceeded(side: DocumentCaptureSide, previewData: Data) async {
        evaluationErrorRetryCount = 0
        sideNeedingPreviewClear = nil

        uploadState = .uploading
        showLoadingScreen = true
        feedbackType = .scanning

        // Log feedback succeeded
        await interactor?.logDocFeedbackSucceeded(validationId: validationId, result: "valid", reason: nil)

        if side == .front {
            frontPhotoStatus = .loading
            await updateUI(frontPhotoDataUpdate: previewData)
        } else if side == .back {
            backPhotoStatus = .loading
            await updateUI(backPhotoDataUpdate: previewData)
        } else {
            await updateUI()
        }

        interactor?.uploadPhoto(side: side, photoData: previewData)
    }

    func imageEvaluationFailed(side: DocumentCaptureSide, previewData: Data, reason: String?) async {
        uploadState = .none
        showLoadingScreen = false
        await view?.resetCaptureInProgress()
        lifecycleState = .stopped

        // Log feedback failed
        let errorMessage = reason ?? "Document validation failed"
        await interactor?.logDocFeedbackFailed(validationId: validationId, errorMessage: errorMessage)

        // Reset detection timers for retry
        detectionState.resetDocumentDetectionTimer()
        detectionState.resetDetectionProcessingTimer()

        // Mark side for preview clearing when returning from feedback
        sideNeedingPreviewClear = side

        incrementEvaluationFailureAttempts(side: side)
        let retriesLeft = retriesLeftForSide(side)

        let scenario = mapReasonToScenario(reason: reason, side: side)

        do {
            try await router?.navigateToDocumentFeedback(
                feedback: scenario,
                capturedImageData: previewData,
                retriesLeft: retriesLeft
            )
        } catch {
            await view?.showError(error.localizedDescription)
        }
    }

    func imageEvaluationErrored(side: DocumentCaptureSide, error: TruoraException) async {
        // Don't retry on authentication errors (401) - these are permanent failures
        let isRetryableError = !isAuthenticationError(error)

        if isRetryableError,
           evaluationErrorRetryCount < Self.maxEvaluationErrorRetries,
           let context = currentEvaluationContext,
           context.side == side {
            evaluationErrorRetryCount += 1

            // Exponential backoff: 1s, 2s, 4s...
            let delaySeconds = pow(2.0, Double(evaluationErrorRetryCount - 1))
            let delayNanoseconds = UInt64(delaySeconds * 1_000_000_000)
            try? await timeProvider.sleep(nanoseconds: delayNanoseconds)

            interactor?.evaluateImage(
                side: side,
                photoData: context.photoData,
                country: context.country,
                documentType: context.documentType,
                validationId: validationId
            )
            return
        }

        // Clear preview state since we're not showing feedback
        sideNeedingPreviewClear = nil

        guard let context = currentEvaluationContext, context.side == side else {
            uploadState = .none
            showLoadingScreen = false
            await view?.resetCaptureInProgress()

            feedbackType = .scanningManual
            await updateUI()
            await view?.setupCamera()
            await view?.showError(
                error.errorDescription
                    ?? "An error occurred during image evaluation. Please try again."
            )
            return
        }

        uploadState = .uploading
        showLoadingScreen = true
        feedbackType = .scanning

        switch side {
        case .front:
            frontPhotoStatus = .loading
            await updateUI(frontPhotoDataUpdate: context.photoData)
        case .back:
            backPhotoStatus = .loading
            await updateUI(backPhotoDataUpdate: context.photoData)
        }

        interactor?.uploadPhoto(side: side, photoData: context.photoData)
    }
}

private extension DocumentCapturePresenter {
    func navigateToResultAfterDelay() async {
        uploadState = .success
        await updateUI()

        try? await timeProvider.sleep(nanoseconds: Self.successStateHoldNanoseconds)

        await view?.stopCamera()

        do {
            try await router?.navigateToResult(validationId: validationId, loadingType: .document)
        } catch {
            uploadState = .none
            await view?.showError(error.localizedDescription)
        }
    }

    func handleCaptureFlow(side: DocumentCaptureSide, photoData: Data) async {
        guard router != nil else {
            uploadState = .none
            showLoadingScreen = false
            await view?.showError("Router not configured")
            return
        }

        let attempts = evaluationFailureAttempts(for: side)
        if attempts >= Self.maxAttempts - 1 {
            interactor?.uploadPhoto(side: side, photoData: photoData)
            return
        }

        let documentConfig = ValidationConfig.shared.documentConfig
        guard !documentConfig.country.isEmpty, !documentConfig.documentType.isEmpty else {
            interactor?.uploadPhoto(side: side, photoData: photoData)
            return
        }

        currentEvaluationContext = EvaluationContext(
            side: side,
            photoData: photoData,
            country: documentConfig.country,
            documentType: documentConfig.documentType
        )
        interactor?.evaluateImage(
            side: side,
            photoData: photoData,
            country: documentConfig.country,
            documentType: documentConfig.documentType,
            validationId: validationId
        )
    }

    func evaluationFailureAttempts(for side: DocumentCaptureSide) -> Int {
        switch side {
        case .front:
            frontEvaluationFailureAttempts
        case .back:
            backEvaluationFailureAttempts
        }
    }

    func incrementEvaluationFailureAttempts(side: DocumentCaptureSide) {
        switch side {
        case .front:
            frontEvaluationFailureAttempts += 1
        case .back:
            backEvaluationFailureAttempts += 1
        }
    }

    func retriesLeftForSide(_ side: DocumentCaptureSide) -> Int {
        let attempts = evaluationFailureAttempts(for: side)
        return max(0, Self.maxAttempts - attempts)
    }

    func mapReasonToScenario(reason: String?, side: DocumentCaptureSide) -> FeedbackScenario {
        guard let reason else {
            return .documentNotFound
        }

        switch reason.uppercased() {
        case "FACE_NOT_FOUND":
            return .faceNotFound
        case "BLURRY_IMAGE":
            return .blurryImage
        case "LOW_LIGHT":
            return .lowLight
        case "IMAGE_WITH_REFLECTION":
            return .imageWithReflection
        default:
            if side == .front {
                return .frontOfDocumentNotFound
            }
            if side == .back {
                return .backOfDocumentNotFound
            }
            return .documentNotFound
        }
    }

    /// Checks if the error is an authentication error (401 Unauthorized)
    /// Authentication errors should not be retried as they indicate a permanent failure
    private func isAuthenticationError(_ error: TruoraException) -> Bool {
        switch error {
        case .network(_, let underlyingError):
            // Check underlying TruoraAPIError for structured unauthorized detection
            if let apiError = underlyingError as? TruoraAPIError {
                if case .unauthorized = apiError {
                    return true
                }
            }
            return false
        case .sdk, .validationApi:
            return false
        }
    }
}
