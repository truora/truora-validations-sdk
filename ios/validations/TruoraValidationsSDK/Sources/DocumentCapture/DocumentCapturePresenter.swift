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

    private var isUploading: Bool = false

    private static let maxAttempts = 3
    private static let maxEvaluationErrorRetries = 2

    private var frontEvaluationFailureAttempts: Int = 0
    private var backEvaluationFailureAttempts: Int = 0

    private var evaluationErrorRetryCount: Int = 0
    private var currentEvaluationContext: EvaluationContext?
    private var sideNeedingPreviewClear: DocumentCaptureSide?

    // MARK: - Autodetection Properties

    // MARK: - Read useAutocapture from documentConfig when available

    private let useAutocapture: Bool

    private var lifecycleState: CameraLifecycleState = .uninitialized

    // Thread-safe timing and detection state using NSLock for low-overhead synchronization
    // All properties below are protected by timingLock to prevent race conditions
    private let timingLock = NSLock()
    private var documentDetectionStartTime: Date?
    private var detectionProcessingStartTime: Date?
    private let timeProvider: TimeProvider

    private static let manualTimeoutSeconds: TimeInterval = 15.0
    private static let requiredDetectionTime: TimeInterval = 2.0
    private static let stabilityThreshold: CGFloat = 0.015
    private static let maxTotalMovement: CGFloat = 0.08
    private static let centerDistanceThreshold: CGFloat = 0.2
    private static let minDocumentWidth: CGFloat = 0.5
    private static let maxDocumentWidth: CGFloat = 0.9

    // Feedback debounce to prevent flickering when detection rapidly changes
    // Protected by timingLock for thread safety
    private static let feedbackDebounceTime: TimeInterval = 0.3
    private var pendingFeedbackType: DocumentFeedbackType?
    private var pendingFeedbackStartTime: Date?
    private var displayedFeedbackType: DocumentFeedbackType = .searching

    // Bounding box tracking for stability detection
    // Protected by timingLock for thread safety
    private var initialBoundingBox: CGRect?
    private var lastBoundingBox: CGRect?

    init(
        view: DocumentCapturePresenterToView,
        interactor: DocumentCapturePresenterToInteractor?,
        router: ValidationRouter,
        validationId: String,
        useAutocapture: Bool = true,
        timeProvider: TimeProvider = RealTimeProvider()
    ) {
        self.view = view
        self.interactor = interactor
        self.router = router
        self.validationId = validationId
        self.useAutocapture = useAutocapture
        self.timeProvider = timeProvider
        self.currentSide = .front
        self.feedbackType = useAutocapture ? .searching : .scanningManual
    }

    private func updateUI(
        frontPhotoDataUpdate: Data? = nil,
        backPhotoDataUpdate: Data? = nil,
        clearFrontPhoto: Bool = false,
        clearBackPhoto: Bool = false
    ) async {
        await view?.updateComposeUI(
            side: currentSide,
            feedbackType: feedbackType,
            showHelpDialog: showHelpDialog,
            showRotationAnimation: showRotationAnimation,
            showLoadingScreen: showLoadingScreen,
            frontPhotoData: frontPhotoDataUpdate,
            frontPhotoStatus: frontPhotoStatus,
            backPhotoData: backPhotoDataUpdate,
            backPhotoStatus: backPhotoStatus,
            clearFrontPhoto: clearFrontPhoto,
            clearBackPhoto: clearBackPhoto
        )
    }

    private func transitionToBackSideWithRotation() async {
        showRotationAnimation = true
        await updateUI()

        try? await timeProvider.sleep(nanoseconds: 1_800_000_000)

        showRotationAnimation = false
        currentSide = .back
        feedbackType = useAutocapture ? .scanning : .scanningManual
        evaluationErrorRetryCount = 0
        currentEvaluationContext = nil

        // Reset detection timers for back side
        resetDocumentDetectionTimer()
        startDetectionProcessingTimer()
        lifecycleState = .ready

        await updateUI()
        await view?.setupCamera()
    }

    // MARK: - Timing Helper Methods

    /// Starts the detection processing timer for manual timeout (thread-safe)
    private func startDetectionProcessingTimer() {
        timingLock.lock()
        detectionProcessingStartTime = Date()
        timingLock.unlock()
    }

    /// Resets the detection processing timer (thread-safe)
    private func resetDetectionProcessingTimer() {
        timingLock.lock()
        detectionProcessingStartTime = nil
        timingLock.unlock()
    }

    /// Starts the document detection timer (thread-safe)
    private func startDocumentDetectionTimer() {
        timingLock.lock()
        documentDetectionStartTime = Date()
        timingLock.unlock()
    }

    /// Resets the document detection timer (thread-safe)
    private func resetDocumentDetectionTimer() {
        timingLock.lock()
        documentDetectionStartTime = nil
        initialBoundingBox = nil
        timingLock.unlock()
    }

    /// Checks if manual capture timeout has been reached (thread-safe)
    /// Returns true if manualTimeoutSeconds have passed since detection processing started
    private func hasManualTimeout() -> Bool {
        timingLock.lock()
        defer { timingLock.unlock() }

        guard let startTime = detectionProcessingStartTime else {
            return false
        }

        let elapsed = Date().timeIntervalSince(startTime)
        return elapsed >= Self.manualTimeoutSeconds
    }

    /// Checks if sufficient consecutive document detection time has elapsed (thread-safe)
    /// Returns true if requiredDetectionTime has passed since document detection started
    private func hasSufficientDocumentDetection() -> Bool {
        timingLock.lock()
        defer { timingLock.unlock() }

        guard let startTime = documentDetectionStartTime else {
            return false
        }

        let elapsed = Date().timeIntervalSince(startTime)
        return elapsed >= Self.requiredDetectionTime
    }

    /// Starts detection timer and sets initial bounding box atomically (thread-safe)
    /// - Parameter bbox: The initial bounding box to set
    /// - Returns: true if timer was started (was nil), false if already running
    private func startDocumentDetectionIfNeeded(with bbox: CGRect) -> Bool {
        timingLock.lock()
        defer { timingLock.unlock() }

        guard documentDetectionStartTime == nil else {
            return false
        }

        documentDetectionStartTime = Date()
        initialBoundingBox = bbox
        return true
    }

    /// Sets the last bounding box (thread-safe)
    private func setLastBoundingBox(_ bbox: CGRect?) {
        timingLock.lock()
        lastBoundingBox = bbox
        timingLock.unlock()
    }

    /// Clears last bounding box and resets capture state (thread-safe)
    private func resetCaptureState() {
        timingLock.lock()
        lastBoundingBox = nil
        displayedFeedbackType = .scanning
        pendingFeedbackType = nil
        pendingFeedbackStartTime = nil
        timingLock.unlock()
    }

    /// Transitions to manual mode when autocapture timeout is reached
    private func transitionToManualMode() async {
        resetDocumentDetectionTimer()
        feedbackType = .scanningManual
        timingLock.lock()
        displayedFeedbackType = .scanningManual
        pendingFeedbackType = nil
        pendingFeedbackStartTime = nil
        timingLock.unlock()
        await updateUI()
    }

    /// Updates feedback with debouncing to prevent flickering (thread-safe)
    /// Only updates the displayed feedback if the new type has been consistent for feedbackDebounceTime
    /// - Parameter newFeedback: The new feedback type to potentially display
    /// - Returns: true if the displayed feedback was updated, false if still debouncing
    private func updateDebouncedFeedback(_ newFeedback: DocumentFeedbackType) -> Bool {
        timingLock.lock()
        defer { timingLock.unlock() }

        // Scanning feedback should always be shown immediately (good state)
        // Also skip debouncing when in manual mode
        if newFeedback == .scanning || newFeedback == .scanningManual {
            feedbackType = newFeedback
            displayedFeedbackType = newFeedback
            pendingFeedbackType = nil
            pendingFeedbackStartTime = nil
            return true
        }

        // If this is the same as currently displayed, nothing to do
        if newFeedback == displayedFeedbackType {
            pendingFeedbackType = nil
            pendingFeedbackStartTime = nil
            return false
        }

        // If this is a new pending feedback type, start the timer
        if pendingFeedbackType != newFeedback {
            pendingFeedbackType = newFeedback
            pendingFeedbackStartTime = Date()
            return false
        }

        // Check if we've waited long enough to show this feedback
        guard let startTime = pendingFeedbackStartTime else {
            pendingFeedbackType = newFeedback
            pendingFeedbackStartTime = Date()
            return false
        }

        let elapsed = Date().timeIntervalSince(startTime)
        if elapsed >= Self.feedbackDebounceTime {
            feedbackType = newFeedback
            displayedFeedbackType = newFeedback
            pendingFeedbackType = nil
            pendingFeedbackStartTime = nil
            return true
        }

        return false
    }

    /// Resets debounce state (thread-safe, call when resetting detection state)
    private func resetFeedbackDebounce() {
        timingLock.lock()
        pendingFeedbackType = nil
        pendingFeedbackStartTime = nil
        timingLock.unlock()
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
        timingLock.lock()
        let lastBbox = lastBoundingBox
        let initBbox = initialBoundingBox
        timingLock.unlock()

        guard let lastBbox, let initBbox else {
            return true
        }

        let dx = abs(currentBbox.midX - lastBbox.midX)
        let dy = abs(currentBbox.midY - lastBbox.midY)
        let dw = abs(currentBbox.width - lastBbox.width)
        let dh = abs(currentBbox.height - lastBbox.height)

        let isFrameStable = dx < Self.stabilityThreshold && dy < Self.stabilityThreshold &&
            dw < Self.stabilityThreshold && dh < Self.stabilityThreshold

        let tdx = abs(currentBbox.midX - initBbox.midX)
        let tdy = abs(currentBbox.midY - initBbox.midY)
        let tdw = abs(currentBbox.width - initBbox.width)
        let tdh = abs(currentBbox.height - initBbox.height)

        let isTotalStable = tdx < Self.maxTotalMovement && tdy < Self.maxTotalMovement &&
            tdw < Self.maxTotalMovement && tdh < Self.maxTotalMovement

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

        let frontUploadUrl = await router.frontUploadUrl
        let reverseUploadUrl = await router.reverseUploadUrl

        guard let frontUploadUrl, !frontUploadUrl.isEmpty else {
            await view?.showError("Missing front upload URL")
            return
        }

        let isSingleSided = (reverseUploadUrl == nil || reverseUploadUrl?.isEmpty == true)

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
            startDetectionProcessingTimer()
        }

        await view?.setupCamera()

        await updateUI()
    }

    func viewWillAppear() async {
        // On initial load, skip restart logic as it's handled by viewDidLoad
        guard lifecycleState != .uninitialized else {
            print("🟢 DocumentCapturePresenter: viewWillAppear - initial load, skipping")
            return
        }

        // If upload in progress, don't restart camera
        guard !isUploading else {
            print("🟢 DocumentCapturePresenter: viewWillAppear - skipping restart (upload in progress)")
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
            resetDocumentDetectionTimer()
            startDetectionProcessingTimer()
        }

        await view?.setupCamera()
    }

    private func resetToInitialState() async {
        // Reset all state to initial values for a fresh start
        lifecycleState = .stopped
        feedbackType = useAutocapture ? .searching : .scanningManual

        timingLock.lock()
        displayedFeedbackType = feedbackType
        lastBoundingBox = nil
        timingLock.unlock()

        evaluationErrorRetryCount = 0
        currentEvaluationContext = nil

        // Reset detection timers and debounce state
        resetDocumentDetectionTimer()
        startDetectionProcessingTimer()
        resetFeedbackDebounce()
        await updateUI()
    }

    func cameraReady() async {
        lifecycleState = .ready
    }

    func viewWillDisappear() async {
        // Pause video first to discard any in-progress recording
        if lifecycleState == .capturing {
            await view?.pauseVideo()
        }

        // Then stop camera completely (resets skipMediaNotification = false for clean restart)
        await view?.stopCamera()

        // Set lifecycle state to stopped so we can restart when returning
        lifecycleState = .stopped

        // Clean up timers and debounce state
        resetDocumentDetectionTimer()
        resetDetectionProcessingTimer()
        resetFeedbackDebounce()
    }

    func photoCaptured(photoData: Data) async {
        guard !isUploading else {
            return
        }

        guard !photoData.isEmpty else {
            await view?.showError("Captured photo is empty")
            lifecycleState = .ready
            return
        }

        isUploading = true
        lifecycleState = .capturing
        feedbackType = .scanning
        showLoadingScreen = true
        evaluationErrorRetryCount = 0

        await view?.pauseVideo()

        // Reset detection timers during capture/upload
        resetDocumentDetectionTimer()
        resetDetectionProcessingTimer()

        switch currentSide {
        case .front:
            frontPhotoStatus = .loading
            await updateUI(frontPhotoDataUpdate: photoData)
            handleCaptureFlow(side: .front, photoData: photoData)
        case .back:
            backPhotoStatus = .loading
            await updateUI(backPhotoDataUpdate: photoData)
            handleCaptureFlow(side: .back, photoData: photoData)
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
                resetDocumentDetectionTimer()
                startDetectionProcessingTimer()
                resetFeedbackDebounce()
                feedbackType = .searching
                timingLock.lock()
                displayedFeedbackType = .searching
                timingLock.unlock()
                lifecycleState = .ready
            }

            await updateUI()
        case .switchToManualMode:
            showHelpDialog = false
            feedbackType = .scanningManual
            timingLock.lock()
            displayedFeedbackType = .scanningManual
            timingLock.unlock()
            resetDocumentDetectionTimer()
            resetDetectionProcessingTimer()
            resetFeedbackDebounce()
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
        await router?.handleCancellation()
    }

    func retryTapped() async {
        await resetToInitialState()
        await view?.setupCamera()
    }

    private func validateCurrentStateAndResetTimer() async -> Bool {
        // Skip detection processing if not in autocapture mode or already capturing/uploading
        guard useAutocapture,
              lifecycleState == .ready,
              feedbackType != .scanningManual,
              !isUploading,
              !showHelpDialog,
              !showLoadingScreen else {
            return false
        }

        // Check for manual timeout - transition to manual mode
        if hasManualTimeout() {
            await transitionToManualMode()
            return false
        }

        return true
    }

    private func processDocumentDetection(_ detection: DocumentDetection) async {
        let isFront = detection.isFrontSide

        let isInvalidSide = (isFront && currentSide == .back) || (!isFront && currentSide == .front)
        if isInvalidSide {
            resetDocumentDetectionTimer()
            if updateDebouncedFeedback(.rotate) {
                await updateUI()
            }
            return
        }

        // Check quality and stability (Match Android)
        let bbox = detection.document.boundingBox
        if isQualityDetection(detection.document), isStableDetection(bbox) {
            // Document detected - start or continue detection timer (thread-safe)
            _ = startDocumentDetectionIfNeeded(with: bbox)
            _ = updateDebouncedFeedback(.scanning)
        } else {
            resetDocumentDetectionTimer()
            updateDetectionFeedback(detection.document)
        }

        setLastBoundingBox(bbox)

        // Check if document has been detected long enough for auto-capture
        if hasSufficientDocumentDetection() {
            lifecycleState = .capturing
            feedbackType = .scanning
            resetDocumentDetectionTimer()
            resetDetectionProcessingTimer()
            resetCaptureState()

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
                resetDocumentDetectionTimer()
                if updateDebouncedFeedback(.multipleDocuments) {
                    await updateUI()
                }
                return
            }

            detected = DocumentDetection(document: document, frontScore: frontScore, backScore: backScore)
        }

        guard let detected else {
            resetDocumentDetectionTimer()
            setLastBoundingBox(nil)
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
        isUploading = false
        showLoadingScreen = false

        switch side {
        case .front:
            frontPhotoStatus = .success
            await updateUI()

            let reverseUploadUrl = await router?.reverseUploadUrl
            let isSingleSided = (reverseUploadUrl == nil || reverseUploadUrl?.isEmpty == true)

            if isSingleSided {
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
        isUploading = false
        feedbackType = useAutocapture ? .searching : .scanningManual
        showLoadingScreen = false
        lifecycleState = .ready

        if side == .front {
            frontPhotoStatus = nil
        } else if side == .back {
            backPhotoStatus = nil
        }

        // Reset detection timers for retry
        if useAutocapture {
            resetDocumentDetectionTimer()
            startDetectionProcessingTimer()
        }

        await updateUI()
        await view?.showError(
            error.errorDescription ?? "An error occurred during photo upload. Please try again."
        )
        await view?.setupCamera()
    }

    func imageEvaluationStarted(side: DocumentCaptureSide, previewData: Data) async {
        isUploading = true
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

        isUploading = true
        showLoadingScreen = true
        feedbackType = .scanning

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
        isUploading = false
        showLoadingScreen = false
        lifecycleState = .stopped

        // Reset detection timers for retry
        resetDocumentDetectionTimer()
        resetDetectionProcessingTimer()

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
            isUploading = false
            showLoadingScreen = false

            feedbackType = .scanningManual
            await updateUI()
            await view?.setupCamera()
            await view?.showError(
                error.errorDescription ?? "An error occurred during image evaluation. Please try again."
            )
            return
        }

        isUploading = true
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
        await view?.stopCamera()

        try? await timeProvider.sleep(nanoseconds: 500_000_000)

        do {
            try await router?.navigateToResult(validationId: validationId, loadingType: .document)
        } catch {
            await view?.showError(error.localizedDescription)
        }
    }

    func handleCaptureFlow(side: DocumentCaptureSide, photoData: Data) {
        guard router != nil else {
            isUploading = false
            showLoadingScreen = false
            Task { await view?.showError("Router not configured") }
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
