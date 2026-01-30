//
//  DocumentCapturePresenterTests.swift
//  TruoraValidationsSDKTests
//
//  Created by Truora on 26/12/25.
//

import XCTest
@testable import TruoraValidationsSDK

// swiftlint:disable type_body_length

/// Tests for DocumentCapturePresenter following VIPER architecture
/// Verifies photo capture flow, upload coordination, and state management
@MainActor final class DocumentCapturePresenterTests: XCTestCase {
    // MARK: - Properties

    private var sut: DocumentCapturePresenter!
    private var mockView: MockDocumentCaptureView!
    private var mockInteractor: MockDocumentCaptureInteractor!
    private var mockRouter: MockDocumentCaptureRouter!
    private var mockTimeProvider: MockTimeProvider!

    // MARK: - Lifecycle

    override func setUp() {
        super.setUp()
        mockView = MockDocumentCaptureView()
        mockInteractor = MockDocumentCaptureInteractor()
        mockTimeProvider = MockTimeProvider()
        let navController = UINavigationController()
        mockRouter = MockDocumentCaptureRouter(navigationController: navController)
        mockRouter.frontUploadUrl = "https://example.com/front"
        mockRouter.reverseUploadUrl = "https://example.com/reverse"

        sut = DocumentCapturePresenter(
            view: mockView,
            interactor: mockInteractor,
            router: mockRouter,
            validationId: "test-validation-id",
            timeProvider: mockTimeProvider
        )
    }

    override func tearDown() {
        sut = nil
        mockView = nil
        mockInteractor = nil
        mockRouter = nil
        mockTimeProvider = nil
        ValidationConfig.shared.reset()
        super.tearDown()
    }

    // MARK: - View Lifecycle Tests

    func testViewDidLoad_withValidUrls_configuresInteractorAndCamera() async {
        // When
        await sut.viewDidLoad()

        // Then
        XCTAssertTrue(mockInteractor.setUploadUrlsCalled, "Should configure upload URLs in interactor")
        XCTAssertTrue(mockView.setupCameraCalled, "Should setup camera in view")
        XCTAssertTrue(mockView.updateComposeUICalled, "Should update initial UI state")
        XCTAssertEqual(mockInteractor.lastFrontUploadUrl, "https://example.com/front")
        XCTAssertEqual(mockInteractor.lastReverseUploadUrl, "https://example.com/reverse")
    }

    func testViewDidLoad_withMissingFrontUrl_showsError() async {
        // Given
        mockRouter.frontUploadUrl = nil

        // When
        await sut.viewDidLoad()

        // Then
        XCTAssertTrue(mockView.showErrorCalled, "Should show error when front URL is missing")
        XCTAssertTrue(mockView.lastErrorMessage?.contains("front upload URL") ?? false)
        XCTAssertFalse(mockInteractor.setUploadUrlsCalled, "Should not configure interactor")
        XCTAssertFalse(mockView.setupCameraCalled, "Should not setup camera")
    }

    func testViewDidLoad_withSingleSidedDocument_configuresInteractorAndCamera() async {
        // Given - Single-sided document (like passport) with only front URL
        mockRouter.reverseUploadUrl = nil

        // When
        await sut.viewDidLoad()

        // Then
        XCTAssertFalse(mockView.showErrorCalled, "Should NOT show error for single-sided documents")
        XCTAssertTrue(mockInteractor.setUploadUrlsCalled, "Should configure interactor")
        XCTAssertTrue(mockView.setupCameraCalled, "Should setup camera")
        XCTAssertEqual(mockInteractor.lastFrontUploadUrl, "https://example.com/front")
        XCTAssertNil(mockInteractor.lastReverseUploadUrl, "Reverse URL should be nil for single-sided")
    }

    func testViewWillDisappear_stopsCamera() async {
        // When
        await sut.viewWillDisappear()

        // Then
        XCTAssertTrue(mockView.stopCameraCalled, "Should stop camera when view disappears")
    }

    // MARK: - Photo Capture Tests

    func testPhotoCaptured_frontSide_uploadsAndUpdatesUI() async {
        // Given
        let photoData = Data([0x01, 0x02, 0x03, 0x04])

        // When
        await sut.photoCaptured(photoData: photoData)

        // Then
        XCTAssertTrue(mockView.updateComposeUICalled, "Should update UI")
        XCTAssertEqual(mockView.lastSide, .front, "Should be on front side")
        XCTAssertEqual(mockView.lastFrontPhotoStatus, .loading, "Front photo should be loading")
        XCTAssertTrue(mockInteractor.uploadPhotoCalled, "Should upload photo")
        XCTAssertEqual(mockInteractor.lastPhotoSide, .front, "Should upload front side")
        XCTAssertEqual(mockInteractor.lastPhotoData?.count, 4)
    }

    func testPhotoCaptured_frontSide_withCountryAndDocumentType_evaluatesImageOnFirstAttempt() async {
        // Given
        ValidationConfig.shared.setValidation(.document(Document().setCountry("PE").setDocumentType("national-id")))
        let photoData = Data([0x01, 0x02, 0x03, 0x04])

        // When
        await sut.photoCaptured(photoData: photoData)

        // Then
        XCTAssertTrue(mockInteractor.evaluateImageCalled, "Should evaluate image when config is available")
        XCTAssertFalse(mockInteractor.uploadPhotoCalled, "Should not upload until evaluation succeeds")
        XCTAssertEqual(mockInteractor.lastEvaluateSide, .front)
        XCTAssertEqual(mockInteractor.lastEvaluateCountry, "PE")
        XCTAssertEqual(mockInteractor.lastEvaluateDocumentType, "national-id")
        XCTAssertEqual(mockInteractor.lastEvaluateValidationId, "test-validation-id")
    }

    func testEvaluationFailure_incrementsAttempts_routesToFeedback_andThirdCaptureUploadsDirectly() async {
        // Given
        ValidationConfig.shared.setValidation(.document(Document().setCountry("PE").setDocumentType("national-id")))
        let photoData = Data([0x01, 0x02, 0x03, 0x04])

        // 1st capture -> evaluate
        await sut.photoCaptured(photoData: photoData)
        XCTAssertTrue(mockInteractor.evaluateImageCalled)

        // When: evaluation fails with FACE_NOT_FOUND
        await sut.imageEvaluationFailed(side: .front, previewData: photoData, reason: "FACE_NOT_FOUND")

        // Then: routes to feedback with mapped scenario and retriesLeft 2
        XCTAssertTrue(mockRouter.navigateToDocumentFeedbackCalled)
        XCTAssertEqual(mockRouter.lastFeedbackScenario, .faceNotFound)
        XCTAssertEqual(mockRouter.lastFeedbackRetriesLeft, 2)

        // 2nd capture -> evaluate again
        mockInteractor.reset()
        mockRouter.reset()
        await sut.photoCaptured(photoData: photoData)
        XCTAssertTrue(mockInteractor.evaluateImageCalled)

        // When: evaluation fails again
        await sut.imageEvaluationFailed(side: .front, previewData: photoData, reason: "BLURRY_IMAGE")

        // Then: retriesLeft 1
        XCTAssertTrue(mockRouter.navigateToDocumentFeedbackCalled)
        XCTAssertEqual(mockRouter.lastFeedbackScenario, .blurryImage)
        XCTAssertEqual(mockRouter.lastFeedbackRetriesLeft, 1)

        // 3rd capture -> should bypass evaluation and upload directly
        mockInteractor.reset()
        mockRouter.reset()
        await sut.photoCaptured(photoData: photoData)
        XCTAssertFalse(mockInteractor.evaluateImageCalled)
        XCTAssertTrue(mockInteractor.uploadPhotoCalled)
    }

    func testPhotoCaptured_backSide_uploadsAndUpdatesUI() async {
        // Given - Upload front photo first to transition to back side
        let frontData = Data([0x01, 0x02])
        await sut.photoCaptured(photoData: frontData)

        // Complete front upload (triggers rotation)
        let frontTask = Task { await sut.photoUploadCompleted(side: .front) }
        try? await Task.sleep(nanoseconds: 10_000_000)
        mockTimeProvider.resumeAllSleeps()
        await frontTask.value

        mockView.reset()
        mockInteractor.reset()

        let backData = Data([0x03, 0x04])

        // When
        await sut.photoCaptured(photoData: backData)

        // Then
        XCTAssertTrue(mockView.updateComposeUICalled, "Should update UI")
        XCTAssertEqual(mockView.lastSide, .back, "Should be on back side")
        XCTAssertEqual(mockView.lastBackPhotoStatus, .loading, "Back photo should be loading")
        XCTAssertTrue(mockInteractor.uploadPhotoCalled, "Should upload photo")
        XCTAssertEqual(mockInteractor.lastPhotoSide, .back, "Should upload back side")
    }

    func testPhotoCaptured_emptyData_showsError() async {
        // Given
        let emptyData = Data()

        // When
        await sut.photoCaptured(photoData: emptyData)

        // Then
        XCTAssertTrue(mockView.showErrorCalled, "Should show error for empty data")
        XCTAssertTrue(mockView.lastErrorMessage?.contains("empty") ?? false)
        XCTAssertFalse(mockInteractor.uploadPhotoCalled, "Should not upload empty data")
    }

    func testPhotoCaptured_whileUploading_ignoresNewCapture() async {
        // Given - Start first upload
        let firstData = Data([0x01, 0x02])
        await sut.photoCaptured(photoData: firstData)
        XCTAssertTrue(mockInteractor.uploadPhotoCalled, "First upload should start")

        mockInteractor.reset()

        // When - Try to capture again while uploading
        let secondData = Data([0x03, 0x04])
        await sut.photoCaptured(photoData: secondData)

        // Then
        XCTAssertFalse(mockInteractor.uploadPhotoCalled, "Should ignore new capture while uploading")
    }

    // MARK: - Event Handling Tests

    func testHandleCaptureEvent_helpRequested_showsHelpDialog() async {
        // Given
        let event = DocumentAutoCaptureEvent.helpRequested

        // When
        await sut.handleCaptureEvent(event)

        // Then
        XCTAssertTrue(mockView.updateComposeUICalled)
        XCTAssertEqual(mockView.lastShowHelpDialog, true)
    }

    func testHandleCaptureEvent_helpDismissed_hidesHelpDialog() async {
        // Given
        await sut.handleCaptureEvent(.helpRequested)

        // When
        await sut.handleCaptureEvent(.helpDismissed)

        // Then
        XCTAssertTrue(mockView.updateComposeUICalled)
        XCTAssertEqual(mockView.lastShowHelpDialog, false)
    }

    func testHandleCaptureEvent_switchToManualMode_updatesFeedbackType() async {
        // Given
        let event = DocumentAutoCaptureEvent.switchToManualMode

        // When
        await sut.handleCaptureEvent(event)

        // Then
        XCTAssertTrue(mockView.updateComposeUICalled)
        XCTAssertEqual(mockView.lastFeedbackType, .scanningManual)
    }

    func testHandleCaptureEvent_manualCaptureRequested_triggersTakePicture() async {
        // Given
        let event = DocumentAutoCaptureEvent.manualCaptureRequested

        // When
        await sut.handleCaptureEvent(event)

        // Then
        XCTAssertTrue(mockView.takePictureCalled)
    }

    // MARK: - Upload Completion Tests

    func testPhotoUploadCompleted_frontSide_transitionsToBackWithRotation() async {
        // Given - Capture front photo first (two-sided document)
        await sut.photoCaptured(photoData: Data([0x01, 0x02]))
        mockView.reset()

        // When - Call upload completed
        // This will trigger updateUI (animation start) -> sleep -> updateUI (animation end)
        let task = Task { await sut.photoUploadCompleted(side: .front) }

        // Wait a tiny bit for the task to reach the sleep point
        try? await Task.sleep(nanoseconds: 10_000_000)

        // Then - Verify animation started (before sleep resumes)
        XCTAssertTrue(mockView.updateComposeUICalled, "Should update UI")
        XCTAssertEqual(mockView.lastFrontPhotoStatus, .success, "Front photo should be success")
        XCTAssertTrue(mockView.lastShowRotationAnimation ?? false, "Should show rotation animation")

        // Resume the sleep in presenter
        mockTimeProvider.resumeAllSleeps()
        await task.value

        // Then - Verify transition to back side after animation
        XCTAssertEqual(self.mockView.lastSide, .back, "Should transition to back side")
        XCTAssertEqual(self.mockView.lastFeedbackType, .scanning, "Should be in autocapture mode for back")
        XCTAssertFalse(self.mockView.lastShowRotationAnimation ?? true, "Animation should be complete")
    }

    // MARK: - Single-Sided Document Tests

    func testSingleSidedDocument_frontCompleted_navigatesToResult() async {
        // Given - Single-sided document (passport)
        mockRouter.reverseUploadUrl = nil
        await sut.viewDidLoad()
        await sut.photoCaptured(photoData: Data([0x01, 0x02]))
        mockView.reset()
        mockRouter.reset()

        // When
        let task = Task { await sut.photoUploadCompleted(side: .front) }

        // Wait a bit for execution to reach sleep
        try? await Task.sleep(nanoseconds: 10_000_000)

        // Then - Initial state
        XCTAssertTrue(mockView.updateComposeUICalled, "Should update UI")
        XCTAssertEqual(mockView.lastFrontPhotoStatus, .success, "Front photo should be success")
        XCTAssertFalse(mockView.lastShowRotationAnimation ?? false, "Should NOT show rotation animation")

        // Resume delay before navigation
        mockTimeProvider.resumeAllSleeps()
        await task.value

        // Verify navigation
        XCTAssertTrue(self.mockView.stopCameraCalled, "Should stop camera")
        XCTAssertTrue(self.mockRouter.navigateToResultCalled, "Should navigate to result")
        XCTAssertEqual(self.mockRouter.lastNavigatedValidationId, "test-validation-id")
    }

    func testSingleSidedDocument_doesNotTransitionToBackSide() async {
        // Given - Single-sided document
        mockRouter.reverseUploadUrl = nil
        await sut.viewDidLoad()
        await sut.photoCaptured(photoData: Data([0x01, 0x02]))
        mockView.reset()

        // When
        let task = Task { await sut.photoUploadCompleted(side: .front) }

        // Resume navigation delay immediately
        try? await Task.sleep(nanoseconds: 10_000_000)
        mockTimeProvider.resumeAllSleeps()
        await task.value

        // Then - Verify NO transition to back side
        XCTAssertFalse(mockView.lastShowRotationAnimation ?? false, "Should NOT show rotation animation")
        XCTAssertNotEqual(self.mockView.lastSide, .back, "Should NOT transition to back side")
    }

    func testTwoSidedDocument_frontCompleted_transitionsToBackSide() async {
        // Given - Two-sided document (has both URLs)
        XCTAssertNotNil(mockRouter.reverseUploadUrl, "Should have reverse URL for two-sided doc")
        await sut.viewDidLoad()
        await sut.photoCaptured(photoData: Data([0x01, 0x02]))
        mockView.reset()
        mockRouter.reset()

        // When
        let task = Task { await sut.photoUploadCompleted(side: .front) }

        // Wait a bit
        try? await Task.sleep(nanoseconds: 10_000_000)

        // Then - Verify transition to back side
        XCTAssertTrue(mockView.lastShowRotationAnimation ?? false, "Should show rotation animation")
        XCTAssertFalse(mockRouter.navigateToResultCalled, "Should NOT navigate to result yet")

        // Resume animation sleep
        mockTimeProvider.resumeAllSleeps()
        await task.value

        XCTAssertEqual(self.mockView.lastSide, .back, "Should transition to back side")
    }

    func testPhotoUploadCompleted_backSide_stopsCameraAndNavigatesToResult() async {
        // Given - Complete front photo and transition to back
        await sut.photoCaptured(photoData: Data([0x01, 0x02]))

        // Complete front upload
        let frontTask = Task { await sut.photoUploadCompleted(side: .front) }
        try? await Task.sleep(nanoseconds: 10_000_000)
        mockTimeProvider.resumeAllSleeps()
        await frontTask.value

        // Capture back photo
        await sut.photoCaptured(photoData: Data([0x03, 0x04]))
        mockView.reset()
        mockInteractor.reset()

        // When
        let backTask = Task { await sut.photoUploadCompleted(side: .back) }
        try? await Task.sleep(nanoseconds: 10_000_000)

        // Then - Initial state
        XCTAssertTrue(mockView.updateComposeUICalled, "Should update UI")
        XCTAssertEqual(mockView.lastBackPhotoStatus, .success, "Back photo should be success")

        // Resume navigation delay
        mockTimeProvider.resumeAllSleeps()
        await backTask.value

        XCTAssertTrue(mockView.stopCameraCalled, "Should stop camera")
        XCTAssertTrue(mockRouter.navigateToResultCalled, "Should navigate to result")
        XCTAssertEqual(mockRouter.lastNavigatedValidationId, "test-validation-id")
        XCTAssertEqual(mockRouter.lastNavigatedLoadingType, .document)
    }

    // MARK: - Upload Failure Tests

    func testPhotoUploadFailed_frontSide_clearsStatusAndShowsError() async {
        // Given - Capture front photo
        await sut.photoCaptured(photoData: Data([0x01, 0x02]))
        mockView.reset()

        let error = TruoraException.sdk(SDKError(type: .uploadFailed, details: "Network error"))

        // When
        await sut.photoUploadFailed(side: .front, error: error)

        // Then
        XCTAssertTrue(mockView.updateComposeUICalled, "Should update UI")
        XCTAssertNil(mockView.lastFrontPhotoStatus, "Front photo status should be cleared")
        XCTAssertEqual(mockView.lastFeedbackType, .searching, "Should switch to autocapture mode")
        XCTAssertTrue(mockView.showErrorCalled, "Should show error")
        XCTAssertTrue(mockView.lastErrorMessage?.contains("Network error") ?? false)
    }

    func testPhotoUploadFailed_backSide_clearsStatusAndShowsError() async {
        // Given - Complete front and capture back photo
        await sut.photoCaptured(photoData: Data([0x01, 0x02]))

        // Start the upload completion in a separate task so we can resume the sleep
        let uploadTask = Task {
            await sut.photoUploadCompleted(side: .front)
        }

        // Wait a moment for the sleep to be registered, then resume it
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        mockTimeProvider.resumeAllSleeps()

        // Wait for the transition to complete
        await uploadTask.value

        await sut.photoCaptured(photoData: Data([0x03, 0x04]))
        mockView.reset()

        let error = TruoraException.sdk(SDKError(type: .uploadFailed, details: "Upload timeout"))

        // When
        await sut.photoUploadFailed(side: .back, error: error)

        // Then
        XCTAssertTrue(mockView.updateComposeUICalled, "Should update UI")
        XCTAssertNil(mockView.lastBackPhotoStatus, "Back photo status should be cleared")
        XCTAssertEqual(mockView.lastFeedbackType, .searching, "Should switch to autocapture mode")
        XCTAssertTrue(mockView.showErrorCalled, "Should show error")
        XCTAssertTrue(mockView.lastErrorMessage?.contains("Upload timeout") ?? false)
    }

    // MARK: - State Management Tests

    func testInitialState_startsInScanningMode() async {
        // When
        await sut.viewDidLoad()

        // Then
        XCTAssertTrue(mockView.updateComposeUICalled, "Should update UI")
        XCTAssertEqual(mockView.lastSide, .front, "Should start on front side")
        XCTAssertEqual(mockView.lastFeedbackType, .searching, "Should start in autocapture mode")
        XCTAssertFalse(mockView.lastShowHelpDialog ?? true, "Help dialog should be hidden")
        XCTAssertFalse(mockView.lastShowRotationAnimation ?? true, "No rotation animation initially")
    }

    func testRotationAnimation_timingAndStateTransition() async {
        // Given - Complete front photo
        await sut.photoCaptured(photoData: Data([0x01, 0x02]))

        // When
        let task = Task { await sut.photoUploadCompleted(side: .front) }

        // Wait a bit
        try? await Task.sleep(nanoseconds: 10_000_000)

        // Then - Verify animation starts
        XCTAssertTrue(mockView.lastShowRotationAnimation ?? false, "Animation should start")
        XCTAssertEqual(mockView.lastSide, .front, "Should still be on front during animation")

        // Wait for animation to complete
        mockTimeProvider.resumeAllSleeps()
        await task.value

        XCTAssertFalse(self.mockView.lastShowRotationAnimation ?? true, "Animation should be complete")
        XCTAssertEqual(self.mockView.lastSide, .back, "Should transition to back side")
    }
}

// swiftlint:enable type_body_length

// MARK: - Mock Classes

@MainActor private final class MockDocumentCaptureView: DocumentCapturePresenterToView {
    private(set) var setupCameraCalled = false
    private(set) var takePictureCalled = false
    private(set) var stopCameraCalled = false
    private(set) var pauseVideoCalled = false
    private(set) var pauseCameraCalled = false
    private(set) var updateComposeUICalled = false
    private(set) var showErrorCalled = false

    private(set) var lastErrorMessage: String?
    private(set) var lastSide: DocumentCaptureSide?
    private(set) var lastFeedbackType: DocumentFeedbackType?
    private(set) var lastShowHelpDialog: Bool?
    private(set) var lastShowRotationAnimation: Bool?
    private(set) var lastShowLoadingScreen: Bool?
    private(set) var lastFrontPhotoStatus: CaptureStatus?
    private(set) var lastBackPhotoStatus: CaptureStatus?
    private(set) var lastClearFrontPhoto: Bool = false
    private(set) var lastClearBackPhoto: Bool = false

    func setupCamera() {
        setupCameraCalled = true
    }

    func takePicture() {
        takePictureCalled = true
    }

    func stopCamera() {
        stopCameraCalled = true
    }

    func pauseVideo() {
        pauseVideoCalled = true
    }

    func pauseCamera() {
        pauseCameraCalled = true
    }

    func updateComposeUI(
        side: DocumentCaptureSide,
        feedbackType: DocumentFeedbackType,
        showHelpDialog: Bool,
        showRotationAnimation: Bool,
        showLoadingScreen: Bool,
        frontPhotoData: Data?,
        frontPhotoStatus: CaptureStatus?,
        backPhotoData: Data?,
        backPhotoStatus: CaptureStatus?,
        clearFrontPhoto: Bool,
        clearBackPhoto: Bool
    ) {
        updateComposeUICalled = true
        lastSide = side
        lastFeedbackType = feedbackType
        lastShowHelpDialog = showHelpDialog
        lastShowRotationAnimation = showRotationAnimation
        lastShowLoadingScreen = showLoadingScreen
        lastFrontPhotoStatus = frontPhotoStatus
        lastBackPhotoStatus = backPhotoStatus
        lastClearFrontPhoto = clearFrontPhoto
        lastClearBackPhoto = clearBackPhoto
    }

    func showError(_ message: String) {
        showErrorCalled = true
        lastErrorMessage = message
    }

    func reset() {
        setupCameraCalled = false
        takePictureCalled = false
        stopCameraCalled = false
        pauseVideoCalled = false
        pauseCameraCalled = false
        updateComposeUICalled = false
        showErrorCalled = false
        lastErrorMessage = nil
    }
}

@MainActor private final class MockDocumentCaptureInteractor: DocumentCapturePresenterToInteractor {
    private(set) var setUploadUrlsCalled = false
    private(set) var uploadPhotoCalled = false
    private(set) var evaluateImageCalled = false

    private(set) var lastFrontUploadUrl: String?
    private(set) var lastReverseUploadUrl: String?
    private(set) var lastPhotoSide: DocumentCaptureSide?
    private(set) var lastPhotoData: Data?

    private(set) var lastEvaluateSide: DocumentCaptureSide?
    private(set) var lastEvaluatePhotoData: Data?
    private(set) var lastEvaluateCountry: String?
    private(set) var lastEvaluateDocumentType: String?
    private(set) var lastEvaluateValidationId: String?

    func setUploadUrls(frontUploadUrl: String, reverseUploadUrl: String?) {
        setUploadUrlsCalled = true
        lastFrontUploadUrl = frontUploadUrl
        lastReverseUploadUrl = reverseUploadUrl
    }

    func uploadPhoto(side: DocumentCaptureSide, photoData: Data) {
        uploadPhotoCalled = true
        lastPhotoSide = side
        lastPhotoData = photoData
    }

    func evaluateImage(
        side: DocumentCaptureSide,
        photoData: Data,
        country: String,
        documentType: String,
        validationId: String
    ) {
        evaluateImageCalled = true
        lastEvaluateSide = side
        lastEvaluatePhotoData = photoData
        lastEvaluateCountry = country
        lastEvaluateDocumentType = documentType
        lastEvaluateValidationId = validationId
    }

    func reset() {
        uploadPhotoCalled = false
        evaluateImageCalled = false
        lastPhotoSide = nil
        lastPhotoData = nil
        lastEvaluateSide = nil
        lastEvaluatePhotoData = nil
        lastEvaluateCountry = nil
        lastEvaluateDocumentType = nil
        lastEvaluateValidationId = nil
    }
}

@MainActor private final class MockDocumentCaptureRouter: ValidationRouter {
    var navigateToResultCalled = false
    var lastNavigatedValidationId: String?
    var lastNavigatedLoadingType: ResultLoadingType?
    var navigateToResultExpectation: XCTestExpectation?

    var navigateToDocumentFeedbackCalled = false
    var lastFeedbackScenario: FeedbackScenario?
    var lastFeedbackRetriesLeft: Int?

    override func navigateToResult(validationId: String, loadingType: ResultLoadingType = .face) throws {
        navigateToResultCalled = true
        lastNavigatedValidationId = validationId
        lastNavigatedLoadingType = loadingType
        navigateToResultExpectation?.fulfill()
    }

    override func navigateToDocumentFeedback(
        feedback: FeedbackScenario,
        capturedImageData: Data?,
        retriesLeft: Int
    ) throws {
        _ = capturedImageData
        navigateToDocumentFeedbackCalled = true
        lastFeedbackScenario = feedback
        lastFeedbackRetriesLeft = retriesLeft
    }

    func reset() {
        navigateToResultCalled = false
        lastNavigatedValidationId = nil
        lastNavigatedLoadingType = nil
        navigateToResultExpectation = nil

        navigateToDocumentFeedbackCalled = false
        lastFeedbackScenario = nil
        lastFeedbackRetriesLeft = nil
    }
}
