//
//  DocumentCapturePresenterTests.swift
//  TruoraValidationsSDKTests
//
//  Created by Truora on 26/12/25.
//

import TruoraShared
import XCTest
@testable import TruoraValidationsSDK

// swiftlint:disable type_body_length

/// Tests for DocumentCapturePresenter following VIPER architecture
/// Verifies photo capture flow, upload coordination, and state management
final class DocumentCapturePresenterTests: XCTestCase {
    // MARK: - Properties

    private var sut: DocumentCapturePresenter!
    private var mockView: MockDocumentCaptureView!
    private var mockInteractor: MockDocumentCaptureInteractor!
    private var mockRouter: MockDocumentCaptureRouter!

    // MARK: - Lifecycle

    override func setUp() {
        super.setUp()
        mockView = MockDocumentCaptureView()
        mockInteractor = MockDocumentCaptureInteractor()
        let navController = UINavigationController()
        mockRouter = MockDocumentCaptureRouter(navigationController: navController)
        mockRouter.frontUploadUrl = "https://example.com/front"
        mockRouter.reverseUploadUrl = "https://example.com/reverse"

        sut = DocumentCapturePresenter(
            view: mockView,
            interactor: mockInteractor,
            router: mockRouter,
            validationId: "test-validation-id"
        )
    }

    override func tearDown() {
        sut = nil
        mockView = nil
        mockInteractor = nil
        mockRouter = nil
        ValidationConfig.shared.reset()
        super.tearDown()
    }

    // MARK: - View Lifecycle Tests

    func testViewDidLoad_withValidUrls_configuresInteractorAndCamera() {
        // When
        sut.viewDidLoad()

        // Then
        XCTAssertTrue(mockInteractor.setUploadUrlsCalled, "Should configure upload URLs in interactor")
        XCTAssertTrue(mockView.setupCameraCalled, "Should setup camera in view")
        XCTAssertTrue(mockView.updateComposeUICalled, "Should update initial UI state")
        XCTAssertEqual(mockInteractor.lastFrontUploadUrl, "https://example.com/front")
        XCTAssertEqual(mockInteractor.lastReverseUploadUrl, "https://example.com/reverse")
    }

    func testViewDidLoad_withMissingFrontUrl_showsError() {
        // Given
        mockRouter.frontUploadUrl = nil

        // When
        sut.viewDidLoad()

        // Then
        XCTAssertTrue(mockView.showErrorCalled, "Should show error when front URL is missing")
        XCTAssertTrue(mockView.lastErrorMessage?.contains("front upload URL") ?? false)
        XCTAssertFalse(mockInteractor.setUploadUrlsCalled, "Should not configure interactor")
        XCTAssertFalse(mockView.setupCameraCalled, "Should not setup camera")
    }

    func testViewDidLoad_withSingleSidedDocument_configuresInteractorAndCamera() {
        // Given - Single-sided document (like passport) with only front URL
        mockRouter.reverseUploadUrl = nil

        // When
        sut.viewDidLoad()

        // Then
        XCTAssertFalse(mockView.showErrorCalled, "Should NOT show error for single-sided documents")
        XCTAssertTrue(mockInteractor.setUploadUrlsCalled, "Should configure interactor")
        XCTAssertTrue(mockView.setupCameraCalled, "Should setup camera")
        XCTAssertEqual(mockInteractor.lastFrontUploadUrl, "https://example.com/front")
        XCTAssertNil(mockInteractor.lastReverseUploadUrl, "Reverse URL should be nil for single-sided")
    }

    func testViewWillDisappear_stopsCamera() {
        // When
        sut.viewWillDisappear()

        // Then
        XCTAssertTrue(mockView.stopCameraCalled, "Should stop camera when view disappears")
    }

    // MARK: - Photo Capture Tests

    func testPhotoCaptured_frontSide_uploadsAndUpdatesUI() {
        // Given
        let photoData = Data([0x01, 0x02, 0x03, 0x04])

        // When
        sut.photoCaptured(photoData: photoData)

        // Then
        XCTAssertTrue(mockView.updateComposeUICalled, "Should update UI")
        XCTAssertEqual(mockView.lastSide, .front, "Should be on front side")
        XCTAssertEqual(mockView.lastFrontPhotoStatus, .loading, "Front photo should be loading")
        XCTAssertTrue(mockInteractor.uploadPhotoCalled, "Should upload photo")
        XCTAssertEqual(mockInteractor.lastPhotoSide, .front, "Should upload front side")
        XCTAssertEqual(mockInteractor.lastPhotoData?.count, 4)
    }

    func testPhotoCaptured_frontSide_withCountryAndDocumentType_evaluatesImageOnFirstAttempt() {
        // Given
        ValidationConfig.shared.setValidation(.document(Document().setCountry("PE").setDocumentType("national-id")))
        let photoData = Data([0x01, 0x02, 0x03, 0x04])

        // When
        sut.photoCaptured(photoData: photoData)

        // Then
        XCTAssertTrue(mockInteractor.evaluateImageCalled, "Should evaluate image when config is available")
        XCTAssertFalse(mockInteractor.uploadPhotoCalled, "Should not upload until evaluation succeeds")
        XCTAssertEqual(mockInteractor.lastEvaluateSide, .front)
        XCTAssertEqual(mockInteractor.lastEvaluateCountry, "PE")
        XCTAssertEqual(mockInteractor.lastEvaluateDocumentType, "national-id")
        XCTAssertEqual(mockInteractor.lastEvaluateValidationId, "test-validation-id")
    }

    func testEvaluationFailure_incrementsAttempts_routesToFeedback_andThirdCaptureUploadsDirectly() throws {
        // Given
        ValidationConfig.shared.setValidation(.document(Document().setCountry("PE").setDocumentType("national-id")))
        let photoData = Data([0x01, 0x02, 0x03, 0x04])

        // 1st capture -> evaluate
        sut.photoCaptured(photoData: photoData)
        XCTAssertTrue(mockInteractor.evaluateImageCalled)

        // When: evaluation fails with FACE_NOT_FOUND
        sut.imageEvaluationFailed(side: .front, previewData: photoData, reason: "FACE_NOT_FOUND")

        // Then: routes to feedback with mapped scenario and retriesLeft 2
        XCTAssertTrue(mockRouter.navigateToDocumentFeedbackCalled)
        XCTAssertEqual(mockRouter.lastFeedbackScenario, .faceNotFound)
        XCTAssertEqual(mockRouter.lastFeedbackRetriesLeft, 2)

        // 2nd capture -> evaluate again
        mockInteractor.reset()
        mockRouter.reset()
        sut.photoCaptured(photoData: photoData)
        XCTAssertTrue(mockInteractor.evaluateImageCalled)

        // When: evaluation fails again
        sut.imageEvaluationFailed(side: .front, previewData: photoData, reason: "BLURRY_IMAGE")

        // Then: retriesLeft 1
        XCTAssertTrue(mockRouter.navigateToDocumentFeedbackCalled)
        XCTAssertEqual(mockRouter.lastFeedbackScenario, .blurryImage)
        XCTAssertEqual(mockRouter.lastFeedbackRetriesLeft, 1)

        // 3rd capture -> should bypass evaluation and upload directly
        mockInteractor.reset()
        mockRouter.reset()
        sut.photoCaptured(photoData: photoData)
        XCTAssertFalse(mockInteractor.evaluateImageCalled)
        XCTAssertTrue(mockInteractor.uploadPhotoCalled)
    }

    func testPhotoCaptured_backSide_uploadsAndUpdatesUI() {
        // Given - Upload front photo first to transition to back side
        let frontData = Data([0x01, 0x02])
        sut.photoCaptured(photoData: frontData)
        sut.photoUploadCompleted(side: .front)

        // Wait for rotation animation
        let expectation = self.expectation(description: "Wait for rotation")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 2.5)

        mockView.reset()
        mockInteractor.reset()

        let backData = Data([0x03, 0x04])

        // When
        sut.photoCaptured(photoData: backData)

        // Then
        XCTAssertTrue(mockView.updateComposeUICalled, "Should update UI")
        XCTAssertEqual(mockView.lastSide, .back, "Should be on back side")
        XCTAssertEqual(mockView.lastBackPhotoStatus, .loading, "Back photo should be loading")
        XCTAssertTrue(mockInteractor.uploadPhotoCalled, "Should upload photo")
        XCTAssertEqual(mockInteractor.lastPhotoSide, .back, "Should upload back side")
    }

    func testPhotoCaptured_emptyData_showsError() {
        // Given
        let emptyData = Data()

        // When
        sut.photoCaptured(photoData: emptyData)

        // Then
        XCTAssertTrue(mockView.showErrorCalled, "Should show error for empty data")
        XCTAssertTrue(mockView.lastErrorMessage?.contains("empty") ?? false)
        XCTAssertFalse(mockInteractor.uploadPhotoCalled, "Should not upload empty data")
    }

    func testPhotoCaptured_whileUploading_ignoresNewCapture() {
        // Given - Start first upload
        let firstData = Data([0x01, 0x02])
        sut.photoCaptured(photoData: firstData)
        XCTAssertTrue(mockInteractor.uploadPhotoCalled, "First upload should start")

        mockInteractor.reset()

        // When - Try to capture again while uploading
        let secondData = Data([0x03, 0x04])
        sut.photoCaptured(photoData: secondData)

        // Then
        XCTAssertFalse(mockInteractor.uploadPhotoCalled, "Should ignore new capture while uploading")
    }

    // MARK: - Event Handling Tests

    func testHandleCaptureEvent_helpRequested_showsHelpDialog() {
        // Given
        let event = DocumentAutoCaptureEventHelpRequested()

        // When
        sut.handleCaptureEvent(event)

        // Then
        XCTAssertTrue(mockView.updateComposeUICalled, "Should update UI")
        XCTAssertTrue(mockView.lastShowHelpDialog ?? false, "Should show help dialog")
    }

    func testHandleCaptureEvent_helpDismissed_hidesHelpDialog() {
        // Given - First show help
        sut.handleCaptureEvent(DocumentAutoCaptureEventHelpRequested())
        mockView.reset()

        // When
        sut.handleCaptureEvent(DocumentAutoCaptureEventHelpDismissed())

        // Then
        XCTAssertTrue(mockView.updateComposeUICalled, "Should update UI")
        XCTAssertFalse(mockView.lastShowHelpDialog ?? true, "Should hide help dialog")
    }

    func testHandleCaptureEvent_switchToManualMode_changesFeedbackType() {
        // Given
        let event = DocumentAutoCaptureEventSwitchToManualMode()

        // When
        sut.handleCaptureEvent(event)

        // Then
        XCTAssertTrue(mockView.updateComposeUICalled, "Should update UI")
        XCTAssertEqual(mockView.lastFeedbackType, .scanningManual, "Should switch to manual mode")
        XCTAssertFalse(mockView.lastShowHelpDialog ?? true, "Should hide help dialog")
        XCTAssertFalse(mockView.takePictureCalled, "Should NOT take picture automatically")
    }

    func testHandleCaptureEvent_manualCaptureRequested_takesPhoto() {
        // Given
        let event = DocumentAutoCaptureEventManualCaptureRequested()

        // When
        sut.handleCaptureEvent(event)

        // Then
        XCTAssertTrue(mockView.takePictureCalled, "Should trigger photo capture")
    }

    // MARK: - Upload Completion Tests

    func testPhotoUploadCompleted_frontSide_transitionsToBackWithRotation() {
        // Given - Capture front photo first (two-sided document)
        sut.photoCaptured(photoData: Data([0x01, 0x02]))
        mockView.reset()

        // When
        sut.photoUploadCompleted(side: .front)

        // Then
        XCTAssertTrue(mockView.updateComposeUICalled, "Should update UI")
        XCTAssertEqual(mockView.lastFrontPhotoStatus, .success, "Front photo should be success")
        XCTAssertTrue(mockView.lastShowRotationAnimation ?? false, "Should show rotation animation")

        // Verify transition to back side after animation
        let expectation = self.expectation(description: "Wait for rotation animation")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            XCTAssertEqual(self.mockView.lastSide, .back, "Should transition to back side")
            XCTAssertEqual(self.mockView.lastFeedbackType, .scanningManual, "Should be in manual mode for back")
            XCTAssertFalse(self.mockView.lastShowRotationAnimation ?? true, "Animation should be complete")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 2.5)
    }

    // MARK: - Single-Sided Document Tests

    func testSingleSidedDocument_frontCompleted_navigatesToResult() {
        // Given - Single-sided document (passport)
        mockRouter.reverseUploadUrl = nil
        sut.viewDidLoad()
        sut.photoCaptured(photoData: Data([0x01, 0x02]))
        mockView.reset()
        mockRouter.reset()

        // When
        sut.photoUploadCompleted(side: .front)

        // Then
        XCTAssertTrue(mockView.updateComposeUICalled, "Should update UI")
        XCTAssertEqual(mockView.lastFrontPhotoStatus, .success, "Front photo should be success")
        XCTAssertFalse(mockView.lastShowRotationAnimation ?? false, "Should NOT show rotation animation")

        // Verify navigation to result after delay
        let expectation = self.expectation(description: "Wait for navigation")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            XCTAssertTrue(self.mockView.stopCameraCalled, "Should stop camera")
            XCTAssertTrue(self.mockRouter.navigateToResultCalled, "Should navigate to result")
            XCTAssertEqual(self.mockRouter.lastNavigatedValidationId, "test-validation-id")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.5)
    }

    func testSingleSidedDocument_doesNotTransitionToBackSide() {
        // Given - Single-sided document
        mockRouter.reverseUploadUrl = nil
        sut.viewDidLoad()
        sut.photoCaptured(photoData: Data([0x01, 0x02]))
        mockView.reset()

        // When
        sut.photoUploadCompleted(side: .front)

        // Then - Verify NO transition to back side
        XCTAssertFalse(mockView.lastShowRotationAnimation ?? false, "Should NOT show rotation animation")

        let expectation = self.expectation(description: "Wait to verify no back transition")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            XCTAssertNotEqual(self.mockView.lastSide, .back, "Should NOT transition to back side")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 2.5)
    }

    func testTwoSidedDocument_frontCompleted_transitionsToBackSide() {
        // Given - Two-sided document (has both URLs)
        XCTAssertNotNil(mockRouter.reverseUploadUrl, "Should have reverse URL for two-sided doc")
        sut.viewDidLoad()
        sut.photoCaptured(photoData: Data([0x01, 0x02]))
        mockView.reset()
        mockRouter.reset()

        // When
        sut.photoUploadCompleted(side: .front)

        // Then - Verify transition to back side
        XCTAssertTrue(mockView.lastShowRotationAnimation ?? false, "Should show rotation animation")
        XCTAssertFalse(mockRouter.navigateToResultCalled, "Should NOT navigate to result yet")

        let expectation = self.expectation(description: "Wait for back transition")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            XCTAssertEqual(self.mockView.lastSide, .back, "Should transition to back side")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 2.5)
    }

    func testPhotoUploadCompleted_backSide_stopsCameraAndNavigatesToResult() {
        // Given - Complete front photo and transition to back
        sut.photoCaptured(photoData: Data([0x01, 0x02]))
        sut.photoUploadCompleted(side: .front)

        // Wait for rotation
        let rotationExpectation = self.expectation(description: "Wait for rotation")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            rotationExpectation.fulfill()
        }
        waitForExpectations(timeout: 2.5)

        // Capture back photo
        sut.photoCaptured(photoData: Data([0x03, 0x04]))
        mockView.reset()
        mockInteractor.reset()

        // When
        sut.photoUploadCompleted(side: .back)

        // Then
        XCTAssertTrue(mockView.updateComposeUICalled, "Should update UI")
        XCTAssertEqual(mockView.lastBackPhotoStatus, .success, "Back photo should be success")
        XCTAssertTrue(mockView.stopCameraCalled, "Should stop camera")

        // Navigation is async (dispatched), so wait for it.
        let navigationExpectation = self.expectation(description: "Wait for navigation to result")
        mockRouter.navigateToResultExpectation = navigationExpectation
        waitForExpectations(timeout: 1.5)

        XCTAssertTrue(mockRouter.navigateToResultCalled, "Should navigate to result")
        XCTAssertEqual(mockRouter.lastNavigatedValidationId, "test-validation-id")
        XCTAssertEqual(mockRouter.lastNavigatedLoadingType, .document)
    }

    // MARK: - Upload Failure Tests

    func testPhotoUploadFailed_frontSide_clearsStatusAndShowsError() {
        // Given - Capture front photo
        sut.photoCaptured(photoData: Data([0x01, 0x02]))
        mockView.reset()

        let error = ValidationError.uploadFailed("Network error")

        // When
        sut.photoUploadFailed(side: .front, error: error)

        // Then
        XCTAssertTrue(mockView.updateComposeUICalled, "Should update UI")
        XCTAssertNil(mockView.lastFrontPhotoStatus, "Front photo status should be cleared")
        XCTAssertEqual(mockView.lastFeedbackType, .scanningManual, "Should switch to manual mode")
        XCTAssertTrue(mockView.showErrorCalled, "Should show error")
        XCTAssertTrue(mockView.lastErrorMessage?.contains("Network error") ?? false)
    }

    func testPhotoUploadFailed_backSide_clearsStatusAndShowsError() {
        // Given - Complete front and capture back photo
        sut.photoCaptured(photoData: Data([0x01, 0x02]))
        sut.photoUploadCompleted(side: .front)

        let expectation = self.expectation(description: "Wait for rotation")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 2.5)

        sut.photoCaptured(photoData: Data([0x03, 0x04]))
        mockView.reset()

        let error = ValidationError.uploadFailed("Upload timeout")

        // When
        sut.photoUploadFailed(side: .back, error: error)

        // Then
        XCTAssertTrue(mockView.updateComposeUICalled, "Should update UI")
        XCTAssertNil(mockView.lastBackPhotoStatus, "Back photo status should be cleared")
        XCTAssertEqual(mockView.lastFeedbackType, .scanningManual, "Should switch to manual mode")
        XCTAssertTrue(mockView.showErrorCalled, "Should show error")
        XCTAssertTrue(mockView.lastErrorMessage?.contains("Upload timeout") ?? false)
    }

    // MARK: - State Management Tests

    func testInitialState_startsInScanningMode() {
        // When
        sut.viewDidLoad()

        // Then
        XCTAssertTrue(mockView.updateComposeUICalled, "Should update UI")
        XCTAssertEqual(mockView.lastSide, .front, "Should start on front side")
        XCTAssertEqual(mockView.lastFeedbackType, .scanning, "Should start in autocapture mode")
        XCTAssertFalse(mockView.lastShowHelpDialog ?? true, "Help dialog should be hidden")
        XCTAssertFalse(mockView.lastShowRotationAnimation ?? true, "No rotation animation initially")
    }

    func testRotationAnimation_timingAndStateTransition() {
        // Given - Complete front photo
        sut.photoCaptured(photoData: Data([0x01, 0x02]))

        // When
        sut.photoUploadCompleted(side: .front)

        // Then - Verify animation starts
        XCTAssertTrue(mockView.lastShowRotationAnimation ?? false, "Animation should start")
        XCTAssertEqual(mockView.lastSide, .front, "Should still be on front during animation")

        // Wait for animation to complete (1.8 seconds)
        let expectation = self.expectation(description: "Wait for animation completion")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            XCTAssertFalse(self.mockView.lastShowRotationAnimation ?? true, "Animation should be complete")
            XCTAssertEqual(self.mockView.lastSide, .back, "Should transition to back side")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 2.5)
    }

    // MARK: - Manual Mode Timer Tests (comment to run tests faster)

    func testManualModeTimer_activatesAfter10SecondsOnFrontSide() {
        // Given
        sut.viewDidLoad()
        mockView.reset()

        // When - Wait for 10 seconds
        let expectation = self.expectation(description: "Wait for manual mode timer")
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.5) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 11.0)

        // Then
        XCTAssertTrue(mockView.updateComposeUICalled, "Should update UI when timer fires")
        XCTAssertEqual(mockView.lastFeedbackType, .scanningManual, "Should switch to manual mode")
    }

    func testManualModeTimer_activatesAfter10SecondsOnBackSide() {
        // Given - Complete front side to transition to back
        sut.viewDidLoad()
        sut.photoCaptured(photoData: Data([0x01, 0x02]))
        sut.photoUploadCompleted(side: .front)

        // Wait for rotation animation to complete
        let rotationExpectation = self.expectation(description: "Wait for rotation")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            rotationExpectation.fulfill()
        }
        waitForExpectations(timeout: 2.5)

        mockView.reset()

        // When - Wait for 10 seconds on back side
        let timerExpectation = self.expectation(description: "Wait for manual mode timer on back")
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.5) {
            timerExpectation.fulfill()
        }
        waitForExpectations(timeout: 11.0)

        // Then
        XCTAssertTrue(mockView.updateComposeUICalled, "Should update UI when timer fires")
        XCTAssertEqual(mockView.lastFeedbackType, .scanningManual, "Should switch to manual mode on back side")
        XCTAssertEqual(mockView.lastSide, .back, "Should still be on back side")
    }

    func testManualModeTimer_cancelledWhenPhotoCaptured() {
        // Given
        sut.viewDidLoad()

        // When - Capture photo before timer fires (at 5 seconds)
        let expectation = self.expectation(description: "Wait 5 seconds then capture")
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            self.mockView.reset()
            self.sut.photoCaptured(photoData: Data([0x01, 0x02]))
            expectation.fulfill()
        }
        waitForExpectations(timeout: 5.5)

        // Then - Wait another 6 seconds (total 11, past timer deadline)
        let verifyExpectation = self.expectation(description: "Verify timer was cancelled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
            verifyExpectation.fulfill()
        }
        waitForExpectations(timeout: 6.5)

        // Timer should not have fired because it was cancelled
        XCTAssertNotEqual(mockView.lastFeedbackType, .scanningManual, "Should NOT switch to manual mode after capture")
        XCTAssertEqual(mockView.lastFeedbackType, .scanning, "Should be in scanning mode after capture")
    }

    func testManualModeTimer_cancelledWhenViewDisappears() {
        // Given
        sut.viewDidLoad()

        // When - View disappears before timer fires (at 5 seconds)
        let expectation = self.expectation(description: "Wait 5 seconds then disappear")
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            self.mockView.reset()
            self.sut.viewWillDisappear()
            expectation.fulfill()
        }
        waitForExpectations(timeout: 5.5)

        // Then - Wait another 6 seconds (total 11, past timer deadline)
        let verifyExpectation = self.expectation(description: "Verify timer was cancelled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
            verifyExpectation.fulfill()
        }
        waitForExpectations(timeout: 6.5)

        // Timer should not have fired because it was cancelled
        XCTAssertFalse(mockView.updateComposeUICalled, "Should NOT update UI after view disappears")
    }

    func testManualModeTimer_frontTimerCancelledWhenTransitioningToBackSide() {
        // Given
        sut.viewDidLoad()

        // When - Complete front side before timer fires (at 5 seconds)
        let expectation = self.expectation(description: "Wait 5 seconds then complete front")
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            self.sut.photoCaptured(photoData: Data([0x01, 0x02]))
            self.sut.photoUploadCompleted(side: .front)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 5.5)

        // Wait for rotation animation
        let rotationExpectation = self.expectation(description: "Wait for rotation")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            rotationExpectation.fulfill()
        }
        waitForExpectations(timeout: 2.5)

        mockView.reset()

        // Then - Wait another 4 seconds (total 11, past original timer deadline)
        let verifyExpectation = self.expectation(description: "Verify front timer was cancelled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            verifyExpectation.fulfill()
        }
        waitForExpectations(timeout: 4.5)

        // Front timer should have been cancelled, but back timer hasn't fired yet (only 6 seconds on back)
        XCTAssertEqual(mockView.lastSide, .back, "Should be on back side")
        XCTAssertEqual(
            mockView.lastFeedbackType,
            .scanningManual,
            "Should still be in manual mode (set during transition)"
        )
    }
}

// swiftlint:enable type_body_length

// MARK: - Mock Classes

private final class MockDocumentCaptureView: DocumentCapturePresenterToView {
    private(set) var setupCameraCalled = false
    private(set) var takePictureCalled = false
    private(set) var stopCameraCalled = false
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

    func setupCamera() {
        setupCameraCalled = true
    }

    func takePicture() {
        takePictureCalled = true
    }

    func stopCamera() {
        stopCameraCalled = true
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
        backPhotoStatus: CaptureStatus?
    ) {
        updateComposeUICalled = true
        lastSide = side
        lastFeedbackType = feedbackType
        lastShowHelpDialog = showHelpDialog
        lastShowRotationAnimation = showRotationAnimation
        lastShowLoadingScreen = showLoadingScreen
        lastFrontPhotoStatus = frontPhotoStatus
        lastBackPhotoStatus = backPhotoStatus
    }

    func showError(_ message: String) {
        showErrorCalled = true
        lastErrorMessage = message
    }

    func reset() {
        setupCameraCalled = false
        takePictureCalled = false
        stopCameraCalled = false
        updateComposeUICalled = false
        showErrorCalled = false
        lastErrorMessage = nil
    }
}

private final class MockDocumentCaptureInteractor: DocumentCapturePresenterToInteractor {
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

private final class MockDocumentCaptureRouter: ValidationRouter {
    var navigateToResultCalled = false
    var lastNavigatedValidationId: String?
    var lastNavigatedLoadingType: LoadingType?
    var navigateToResultExpectation: XCTestExpectation?

    var navigateToDocumentFeedbackCalled = false
    var lastFeedbackScenario: FeedbackScenario?
    var lastFeedbackRetriesLeft: Int?

    override func navigateToResult(validationId: String, loadingType: LoadingType = .face) throws {
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
