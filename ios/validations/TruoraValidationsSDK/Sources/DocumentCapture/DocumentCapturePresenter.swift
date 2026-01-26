//
//  DocumentCapturePresenter.swift
//  validations
//
//  Created by Truora on 26/12/25.
//

import AVFoundation
import Foundation
import TruoraCamera
import TruoraShared

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

    // MARK: - Autodetection Properties

    // MARK: - Read useAutocapture from documentConfig when available

    private let useAutocapture: Bool = true

    private var lifecycleState: CameraLifecycleState = .uninitialized

    // Thread-safe timing properties using NSLock for low-overhead synchronization
    private let timingLock = NSLock()
    private var documentDetectionStartTime: Date?
    private var detectionProcessingStartTime: Date?

    static let manualTimeoutSeconds: TimeInterval = 5.0
    static let requiredDetectionTime: TimeInterval = 1.0

    init(
        view: DocumentCapturePresenterToView,
        interactor: DocumentCapturePresenterToInteractor?,
        router: ValidationRouter,
        validationId: String
    ) {
        self.view = view
        self.interactor = interactor
        self.router = router
        self.validationId = validationId
    }

    deinit {
        cancelManualModeTimer()
    }

    private func updateUI(frontPhotoDataUpdate: Data? = nil, backPhotoDataUpdate: Data? = nil) {
        view?.updateComposeUI(
            side: currentSide,
            feedbackType: feedbackType,
            showHelpDialog: showHelpDialog,
            showRotationAnimation: showRotationAnimation,
            showLoadingScreen: showLoadingScreen,
            frontPhotoData: frontPhotoDataUpdate,
            frontPhotoStatus: frontPhotoStatus,
            backPhotoData: backPhotoDataUpdate,
            backPhotoStatus: backPhotoStatus
        )
    }

    private func transitionToBackSideWithRotation() {
        cancelManualModeTimer()
        showRotationAnimation = true
        updateUI()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
            guard let self else { return }
            self.showRotationAnimation = false
            self.currentSide = .back
            self.feedbackType = useAutocapture ? .scanning : .scanningManual
            self.evaluationErrorRetryCount = 0
            self.currentEvaluationContext = nil

            // Reset detection timers for back side
            self.resetDocumentDetectionTimer()
            self.startDetectionProcessingTimer()
            self.lifecycleState = .ready

            self.updateUI()
            self.view?.setupCamera()
        }
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

    /// Transitions to manual mode when autocapture timeout is reached
    private func transitionToManualMode() {
        resetDocumentDetectionTimer()
        feedbackType = .scanningManual
        updateUI()
    }
    
    // MARK: - Manual Mode Timer (placeholder methods)
    
    /// Starts timer for manual mode fallback (currently a no-op)
    private func startManualModeTimer() {
        // Placeholder: Timer logic can be implemented here if needed
        // Currently, manual mode transition is handled by hasManualTimeout()
    }
    
    /// Cancels manual mode timer (currently a no-op)
    private func cancelManualModeTimer() {
        // Placeholder: Timer cleanup logic can be implemented here if needed
        // Currently, manual mode transition is handled by hasManualTimeout()
    }
}

extension DocumentCapturePresenter: DocumentCaptureViewToPresenter {
    func viewDidLoad() {
        guard let router else {
            view?.showError("Router not configured")
            return
        }

        guard let frontUploadUrl = router.frontUploadUrl, !frontUploadUrl.isEmpty else {
            view?.showError("Missing front upload URL")
            return
        }

        let isSingleSided = (router.reverseUploadUrl == nil || router.reverseUploadUrl?.isEmpty == true)
        
        // Declare reverseUploadUrl outside of conditional scope
        let reverseUploadUrl: String?
        if !isSingleSided {
            guard let uploadUrl = router.reverseUploadUrl, !uploadUrl.isEmpty else {
                view?.showError("Missing reverse upload URL")
                return
            }
            reverseUploadUrl = uploadUrl
        } else {
            reverseUploadUrl = nil
        }

        interactor?.setUploadUrls(frontUploadUrl: frontUploadUrl, reverseUploadUrl: reverseUploadUrl)

        // Initialize autodetection state
        feedbackType = useAutocapture ? .none : .scanningManual

        if useAutocapture {
            startDetectionProcessingTimer()
        }

        view?.setupCamera()

        updateUI()
        startManualModeTimer()
    }

    func viewWillAppear() {
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

        // Restart detection timers when returning (e.g., from background or feedback modal)
        if useAutocapture {
            resetDocumentDetectionTimer()
            startDetectionProcessingTimer()
        }

        view?.setupCamera()
    }

    private func resetToInitialState() {
        // Reset all state to initial values for a fresh start
        lifecycleState = .stopped
        feedbackType = useAutocapture ? .none : .scanningManual
        evaluationErrorRetryCount = 0
        currentEvaluationContext = nil

        // Reset detection timers for back side
        resetDocumentDetectionTimer()
        startDetectionProcessingTimer()
        updateUI()
    }

    func cameraReady() {
        lifecycleState = .ready
    }

    func viewWillDisappear() {
        // Pause video first to discard any in-progress recording
        if lifecycleState == .capturing {
            view?.pauseVideo()
        }

        // Then stop camera completely (resets skipMediaNotification = false for clean restart)
        view?.stopCamera()

        // Set lifecycle state to stopped so we can restart when returning
        lifecycleState = .stopped

        // Clean up timers
        resetDocumentDetectionTimer()
        resetDetectionProcessingTimer()
    }

    func photoCaptured(photoData: Data) {
        guard !isUploading else {
            return
        }

        guard photoData.count > 0 else {
            view?.showError("Captured photo is empty")
            lifecycleState = .ready
            return
        }

        cancelManualModeTimer()
        isUploading = true
        lifecycleState = .capturing
        feedbackType = .scanning
        showLoadingScreen = true
        evaluationErrorRetryCount = 0

        view?.pauseVideo()

        // Reset detection timers during capture/upload
        resetDocumentDetectionTimer()
        resetDetectionProcessingTimer()

        switch currentSide {
        case .front:
            frontPhotoStatus = .loading
            updateUI(frontPhotoDataUpdate: photoData)
            handleCaptureFlow(side: .front, photoData: photoData)
        case .back:
            backPhotoStatus = .loading
            updateUI(backPhotoDataUpdate: photoData)
            handleCaptureFlow(side: .back, photoData: photoData)
        default:
            isUploading = false
            lifecycleState = .ready
            feedbackType = useAutocapture ? .none : .scanningManual
            showLoadingScreen = false
            updateUI()
            view?.showError("Unknown document capture side")
        }
    }

    func handleCaptureEvent(_ event: DocumentAutoCaptureEvent) {
        if event is DocumentAutoCaptureEventHelpRequested {
            showHelpDialog = true
            updateUI()
            return
        }

        if event is DocumentAutoCaptureEventHelpDismissed {
            showHelpDialog = false
            // Reset detection state when returning from help
            if useAutocapture {
                resetDocumentDetectionTimer()
                startDetectionProcessingTimer()
                feedbackType = .none
                lifecycleState = .ready
            }

            updateUI()
            return
        }

        if event is DocumentAutoCaptureEventSwitchToManualMode {
            showHelpDialog = false
            feedbackType = .scanningManual
            resetDocumentDetectionTimer()
            resetDetectionProcessingTimer()
            updateUI()
            return
        }

        if event is DocumentAutoCaptureEventManualCaptureRequested {
            view?.takePicture()
            return
        }
    }

    private func validateCurrentStateAndResetTimer() -> Bool {
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
            transitionToManualMode()
            return false
        }

        return true
    }

    // swiftlint:disable:next large_tuple
    private func processDocumentDetection(detected: (document: DetectionResult, frontScore: Float, backScore: Float)) {
        let isFront = detected.frontScore >= detected.backScore

        let isInvalidSide = (isFront && currentSide == .back) || (!isFront && currentSide == .front)
        if isInvalidSide {
            resetDocumentDetectionTimer()
            feedbackType = .rotate
            updateUI()

            return
        }

        // Document detected - start or continue detection timer
        if documentDetectionStartTime == nil {
            startDocumentDetectionTimer()
        }

        // Check if document has been detected long enough for auto-capture
        if hasSufficientDocumentDetection() {
            lifecycleState = .capturing
            feedbackType = .scanning
            resetDocumentDetectionTimer()
            resetDetectionProcessingTimer()

            updateUI()
            view?.takePicture()
        }
    }

    func detectionsReceived(_ results: [DetectionResult]) {
        let isValid = validateCurrentStateAndResetTimer()
        if !isValid {
            return
        }

        // swiftlint:disable:next large_tuple
        var detected: (document: DetectionResult, frontScore: Float, backScore: Float)?

        for document in results {
            guard case .document(let scores) = document.category,
                  let frontScore = scores?[0],
                  let backScore = scores?[1],
                  frontScore != 0 || backScore != 0 else {
                continue
            }

            if detected != nil {
                // Multiple documents
                feedbackType = .locate
                resetDocumentDetectionTimer()
                updateUI()
                return
            }

            detected = (document, frontScore, backScore)
        }

        guard let detected else {
            feedbackType = .locate
            resetDocumentDetectionTimer()
            updateUI()
            return
        }

        processDocumentDetection(detected: detected)
    }
}

extension DocumentCapturePresenter: DocumentCaptureInteractorToPresenter {
    func photoUploadCompleted(side: DocumentCaptureSide) {
        isUploading = false
        showLoadingScreen = false

        switch side {
        case .front:
            frontPhotoStatus = .success
            updateUI()

            let isSingleSided = (router?.reverseUploadUrl == nil || router?.reverseUploadUrl?.isEmpty == true)

            if isSingleSided {
                view?.stopCamera()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    guard let self else { return }
                    do {
                        try self.router?.navigateToResult(validationId: self.validationId, loadingType: .document)
                    } catch {
                        self.view?.showError(error.localizedDescription)
                    }
                }
            } else {
                transitionToBackSideWithRotation()
            }

        case .back:
            backPhotoStatus = .success
            updateUI()

            view?.stopCamera()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self else { return }
                do {
                    try self.router?.navigateToResult(validationId: self.validationId, loadingType: .document)
                } catch {
                    self.view?.showError(error.localizedDescription)
                }
            }

        default:
            feedbackType = .scanningManual
            showLoadingScreen = false
            updateUI()
            view?.showError("Unknown document capture side")
        }
    }

    func photoUploadFailed(side: DocumentCaptureSide, error: ValidationError) {
        isUploading = false
        feedbackType = useAutocapture ? .none : .scanningManual
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

        updateUI()
        view?.showError(error.localizedDescription)
        view?.setupCamera()
    }

    func imageEvaluationStarted(side: DocumentCaptureSide, previewData: Data) {
        isUploading = true
        showLoadingScreen = true
        feedbackType = .scanning
        evaluationErrorRetryCount = 0

        if side == .front {
            frontPhotoStatus = .loading
            updateUI(frontPhotoDataUpdate: previewData)
        } else if side == .back {
            backPhotoStatus = .loading
            updateUI(backPhotoDataUpdate: previewData)
        } else {
            updateUI()
        }
    }

    func imageEvaluationSucceeded(side: DocumentCaptureSide, previewData: Data) {
        evaluationErrorRetryCount = 0

        isUploading = true
        showLoadingScreen = true
        feedbackType = .scanning

        if side == .front {
            frontPhotoStatus = .loading
            updateUI(frontPhotoDataUpdate: previewData)
        } else if side == .back {
            backPhotoStatus = .loading
            updateUI(backPhotoDataUpdate: previewData)
        } else {
            updateUI()
        }

        interactor?.uploadPhoto(side: side, photoData: previewData)
    }

    func imageEvaluationFailed(side: DocumentCaptureSide, previewData: Data, reason: String?) {
        isUploading = false
        showLoadingScreen = false
        lifecycleState = .stopped

        // Reset detection timers for retry
        resetDocumentDetectionTimer()
        resetDetectionProcessingTimer()

        incrementEvaluationFailureAttempts(side: side)
        let retriesLeft = retriesLeftForSide(side)

        let scenario = mapReasonToScenario(reason: reason, side: side)

        do {
            try router?.navigateToDocumentFeedback(
                feedback: scenario,
                capturedImageData: previewData,
                retriesLeft: retriesLeft
            )
        } catch {
            view?.showError(error.localizedDescription)
        }
    }

    func imageEvaluationErrored(side: DocumentCaptureSide, error: ValidationError) {
        if evaluationErrorRetryCount < Self.maxEvaluationErrorRetries,
           let context = currentEvaluationContext,
           context.side == side {
            evaluationErrorRetryCount += 1
            interactor?.evaluateImage(
                side: side,
                photoData: context.photoData,
                country: context.country,
                documentType: context.documentType,
                validationId: validationId
            )
            return
        }

        guard let context = currentEvaluationContext, context.side == side else {
            isUploading = false
            showLoadingScreen = false

            feedbackType = .scanningManual
            updateUI()
            view?.setupCamera()
            view?.showError(error.localizedDescription)
            return
        }

        isUploading = true
        showLoadingScreen = true
        feedbackType = .scanning

        if side == .front {
            frontPhotoStatus = .loading
            updateUI(frontPhotoDataUpdate: context.photoData)
        } else if side == .back {
            backPhotoStatus = .loading
            updateUI(backPhotoDataUpdate: context.photoData)
        } else {
            updateUI()
        }

        interactor?.uploadPhoto(side: side, photoData: context.photoData)
    }
}

private extension DocumentCapturePresenter {
    func handleCaptureFlow(side: DocumentCaptureSide, photoData: Data) {
        guard let router else {
            isUploading = false
            showLoadingScreen = false
            view?.showError("Router not configured")
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
        default:
            0
        }
    }

    func incrementEvaluationFailureAttempts(side: DocumentCaptureSide) {
        switch side {
        case .front:
            frontEvaluationFailureAttempts += 1
        case .back:
            backEvaluationFailureAttempts += 1
        default:
            break
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
}
