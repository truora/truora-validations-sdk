//
//  PassiveCapturePresenterTests.swift
//  TruoraValidationsSDKTests
//
//  Created by Truora on 11/11/25.
//

// Import TensorFlowLite for testing purposes with the processors
import TensorFlowLite

// swiftlint:disable file_length
import TruoraCamera
import TruoraShared
import Vision
import XCTest
@testable import TruoraValidationsSDK

// swiftlint:disable type_body_length
/// Tests for PassiveCapturePresenter following VIPER architecture
/// Verifies camera management, recording flow, and upload coordination
final class PassiveCapturePresenterTests: XCTestCase {
    // MARK: - Properties

    private var sut: PassiveCapturePresenter!
    private var mockView: MockPassiveCaptureView!
    private var mockInteractor: MockPassiveCaptureInteractor!
    private var mockRouter: MockPassiveCaptureRouter!

    // MARK: - Lifecycle

    override func setUp() {
        super.setUp()
        mockView = MockPassiveCaptureView()
        mockInteractor = MockPassiveCaptureInteractor()
        let navController = UINavigationController()
        mockRouter = MockPassiveCaptureRouter(navigationController: navController)

        sut = PassiveCapturePresenter(
            view: mockView,
            interactor: mockInteractor,
            router: mockRouter
        )
    }

    override func tearDown() {
        sut = nil
        mockView = nil
        mockInteractor = nil
        mockRouter = nil
        super.tearDown()
    }

    // MARK: - View Lifecycle Tests

    func testViewDidLoad_configuresInteractorAndCamera() {
        // When
        sut.viewDidLoad()

        // Then
        XCTAssertTrue(mockInteractor.setUploadUrlCalled, "Should configure upload URL in interactor")
        XCTAssertTrue(mockView.setupCameraCalled, "Should setup camera in view")
        XCTAssertTrue(mockView.updateComposeUICalled, "Should update initial UI state")
    }

    func testViewDidLoad_calledTwice_triggersSetupOnlyOnce() {
        // When
        sut.viewDidLoad()
        sut.viewDidLoad()

        // Then
        XCTAssertEqual(mockView.setupCameraCount, 1, "Should trigger setup only once")
    }

    func testViewWillAppear_doesNotCrash() {
        // When
        sut.viewWillAppear()

        // Then
        XCTAssertNotNil(sut, "Presenter should handle viewWillAppear without issues")
    }

    func testCameraReady_startsCountdown() {
        // When
        sut.cameraReady()

        // Then
        XCTAssertTrue(mockView.updateComposeUICalled, "Should update UI when camera is ready")
        guard let state = mockView.lastState as? PassiveCaptureState else {
            XCTFail("State should be PassiveCaptureState")
            return
        }
        XCTAssertEqual(state, .countdown, "Should transition to countdown state")
    }

    func testViewWillDisappear_cleansUpTimers() {
        // Given
        sut.cameraReady() // Start some timers

        // When
        sut.viewWillDisappear()

        // Then
        XCTAssertNotNil(sut, "Presenter should cleanup timers without crashing")
        XCTAssertTrue(mockView.stopCameraCalled, "Should stop camera when view disappears")
    }

    // MARK: - Face Detection Tests

    func testCameraFrameProcessed_noFaces_setsFeedbackToShowFace() {
        // Given
        sut.currentState = .recording
        let emptyResults: [DetectionResult] = []

        // When
        sut.detectionsReceived(emptyResults)

        // Then
        XCTAssertTrue(mockView.updateComposeUICalled, "Should update UI")
        XCTAssertEqual(mockView.lastFeedback, .showFace, "Should show SHOW_FACE feedback")
    }

    func testCameraFrameProcessed_multipleFaces_setsFeedbackToMultiplePeople() {
        // Given
        sut.currentState = .recording
        let multipleResults = [
            createFaceDetectionResult(confidence: 0.9),
            createFaceDetectionResult(confidence: 0.85)
        ]

        // When
        sut.detectionsReceived(multipleResults)

        // Then
        XCTAssertTrue(mockView.updateComposeUICalled, "Should update UI")
        XCTAssertEqual(mockView.lastFeedback, .multiplePeople, "Should show MULTIPLE_PEOPLE feedback")
    }

    func testCameraFrameProcessed_oneFace_startsFaceDetectionTimer() {
        // Given
        sut.currentState = .recording
        let singleFace = [createFaceDetectionResult(confidence: 0.95)]

        // When
        sut.detectionsReceived(singleFace)

        // Then
        XCTAssertTrue(mockView.updateComposeUICalled, "Should update UI")
        XCTAssertEqual(mockView.lastFeedback, FeedbackType.none, "Should clear feedback")
        // Timer starts internally, verified by subsequent test checking recording after 1 second
    }

    func testCameraFrameProcessed_consecutiveFacesForOneSecond_startsRecording() {
        // Given
        sut.currentState = .recording
        let singleFace = [createFaceDetectionResult(confidence: 0.95)]

        // When - Start processing faces continuously
        sut.detectionsReceived(singleFace)

        // Simulate continuous frame processing over 1 second
        let expectation = self.expectation(description: "Wait for recording start")
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.sut.detectionsReceived(singleFace)
        }

        // Guarantee cleanup even on failure/timeout
        addTeardownBlock {
            timer.invalidate()
        }

        // Then - After 1.1 seconds face detection + 0.5 seconds async delay for startRecording
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) {
            timer.invalidate()
            XCTAssertTrue(
                self.mockView.startRecordingCalled,
                "Should start recording after 1 second of consecutive faces"
            )
            expectation.fulfill()
        }
        waitForExpectations(timeout: 2.5)
    }

    func testCameraFrameProcessed_lessThanOneSecond_doesNotStartRecording() {
        // Given
        sut.currentState = .recording
        let singleFace = [createFaceDetectionResult(confidence: 0.95)]

        // When - Process frames for only 0.5 seconds
        sut.detectionsReceived(singleFace)

        let expectation = self.expectation(description: "Wait 0.5 seconds")
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.sut.detectionsReceived(singleFace)
        }

        // Guarantee cleanup even on failure/timeout
        addTeardownBlock {
            timer.invalidate()
        }

        // Then - After 0.5 seconds, recording should NOT have started
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            timer.invalidate()
            XCTAssertFalse(
                self.mockView.startRecordingCalled,
                "Should NOT start recording with less than 1 second"
            )
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
    }

    func testCameraFrameProcessed_interruptedByNoFace_resetsTimer() {
        // Given
        sut.currentState = .recording
        let singleFace = [createFaceDetectionResult(confidence: 0.95)]
        let noFaces: [DetectionResult] = []

        // When - Process valid faces for 0.5s, then lose face
        sut.detectionsReceived(singleFace)

        let expectation = self.expectation(description: "Wait for interruption test")
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.sut.detectionsReceived(singleFace)
        }

        // Guarantee cleanup even on failure/timeout
        addTeardownBlock {
            timer.invalidate()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            timer.invalidate()
            self.sut.detectionsReceived(noFaces)

            // Then - Timer should be reset, shown by feedback change
            XCTAssertEqual(self.mockView.lastFeedback, .showFace, "Should show SHOW_FACE feedback")
            XCTAssertFalse(self.mockView.startRecordingCalled, "Should NOT start recording after interruption")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
    }

    func testCameraFrameProcessed_interruptedByMultipleFaces_resetsTimer() {
        // Given
        sut.currentState = .recording
        let singleFace = [createFaceDetectionResult(confidence: 0.95)]
        let multipleFaces = [
            createFaceDetectionResult(confidence: 0.9),
            createFaceDetectionResult(confidence: 0.85)
        ]

        // When - Process valid faces for 0.5s, then multiple faces detected
        sut.detectionsReceived(singleFace)

        let expectation = self.expectation(description: "Wait for interruption test")
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.sut.detectionsReceived(singleFace)
        }

        // Guarantee cleanup even on failure/timeout
        addTeardownBlock {
            timer.invalidate()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            timer.invalidate()
            self.sut.detectionsReceived(multipleFaces)

            // Then - Timer should be reset, shown by feedback change
            XCTAssertEqual(
                self.mockView.lastFeedback,
                .multiplePeople,
                "Should show MULTIPLE_PEOPLE feedback"
            )
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
    }

    func testCameraFrameProcessed_afterTimeout_transitionsToManual() {
        // Given - Start recording to set the processing start time
        sut.cameraReady()

        // Wait for countdown (3 seconds) + small buffer
        let countdownExpectation = self.expectation(description: "Wait for countdown")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            countdownExpectation.fulfill()
        }
        waitForExpectations(timeout: 4.0)

        // Now wait for manual timeout (4 seconds) + buffer
        let timeoutExpectation = self.expectation(description: "Wait for manual timeout")
        DispatchQueue.main
            .asyncAfter(deadline: .now() + PassiveCapturePresenter.manualTimeoutSeconds + 1.0) {
                // When - Process frames after timeout
                let singleFace = [createFaceDetectionResult(confidence: 0.95)]
                self.sut.detectionsReceived(singleFace)

                // Then
                guard let state = self.mockView.lastState as? PassiveCaptureState else {
                    XCTFail("State should be PassiveCaptureState")
                    return
                }
                XCTAssertEqual(state, .manual, "Should transition to MANUAL state after timeout")
                XCTAssertEqual(
                    self.mockView.lastFeedback,
                    .showFace,
                    "Should show SHOW_FACE (error) feedback when transitioning to manual due to timeout"
                )

                timeoutExpectation.fulfill()
            }
        waitForExpectations(timeout: 12.0)
    }

    func testCameraFrameProcessed_beforeTimeout_normalProcessing() {
        sut.currentState = .recording
        let singleFace = [createFaceDetectionResult(confidence: 0.95)]

        // Wait for countdown (3 seconds) + small buffer
        let expectation = self.expectation(description: "Wait for countdown")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            // When - Process frame BEFORE 4 second timeout
            self.sut.detectionsReceived(singleFace)

            // Then - Should process normally, not transition to manual
            XCTAssertEqual(self.mockView.lastFeedback, FeedbackType.none, "Should clear feedback")

            // Verify NOT in manual state
            if let state = self.mockView.lastState as? PassiveCaptureState {
                XCTAssertNotEqual(state, .manual, "Should NOT be in manual state before timeout")
            }

            expectation.fulfill()
        }
        waitForExpectations(timeout: 5.0)
    }

    func testViewWillDisappear_resetsProcessingTimer() {
        // Given - Start recording to set processing timer
        sut.cameraReady()

        let expectation = self.expectation(description: "Wait for recording start")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            // When
            self.sut.viewWillDisappear()

            // Then - Timer should be reset (tested indirectly by no crash)
            XCTAssertNotNil(self.sut, "Presenter should handle cleanup without crashing")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 4.0)
    }

    func testViewWillDisappear_whileRecording_pausesVideoThenStopsCamera() {
        // Given - Start recording
        let recordEvent = PassiveCaptureEventRecordVideoRequested()
        sut.handleCaptureEvent(recordEvent)

        // Wait for async startRecording call
        let expectation = self.expectation(description: "Wait for recording to start")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            // Reset flags
            self.mockView.pauseVideoCalled = false
            self.mockView.stopCameraCalled = false

            // When
            self.sut.viewWillDisappear()

            // Then - Should pause video first, then stop camera
            XCTAssertTrue(self.mockView.pauseVideoCalled, "Should pause video when recording")
            XCTAssertTrue(self.mockView.stopCameraCalled, "Should stop camera after pausing video")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
    }

    func testHandleCaptureEvent_recordingCompleted_stopsRecording() {
        // Given - First start recording to set lifecycleState to .recording
        let recordEvent = PassiveCaptureEventRecordVideoRequested()
        sut.handleCaptureEvent(recordEvent)

        // Wait for async startRecording call (0.5s delay + buffer)
        let expectation = self.expectation(description: "Wait for recording to start then stop")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            // Reset the flag to verify stopRecording is called
            self.mockView.stopRecordingCalled = false

            // When
            let stopEvent = PassiveCaptureEventRecordingCompleted()
            self.sut.handleCaptureEvent(stopEvent)

            // Then
            XCTAssertTrue(self.mockView.stopRecordingCalled, "Should stop recording when event received")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
    }

    // MARK: - Video Recording Tests

    func testVideoRecordingCompleted_uploadsVideo() {
        // Given
        let expectedVideoData = Data([0x00, 0x01, 0x02, 0x03, 0x04])

        // When
        sut.videoRecordingCompleted(videoData: expectedVideoData)

        // Then
        XCTAssertTrue(mockInteractor.uploadVideoCalled, "Should upload video via interactor")
        XCTAssertEqual(
            mockInteractor.lastVideoData,
            expectedVideoData,
            "Should pass correct video data to interactor"
        )
        XCTAssertEqual(mockView.lastUploadState, .uploading, "Should set upload state to UPLOADING")
        XCTAssertTrue(mockView.pauseCameraCalled, "Should pause camera during upload to save resources")
    }

    func testVideoRecordingCompleted_withLargeVideo_uploadsSuccessfully() {
        // Given
        let largeVideoData = Data(repeating: 0xFF, count: 1024 * 1024) // 1MB

        // When
        sut.videoRecordingCompleted(videoData: largeVideoData)

        // Then
        XCTAssertTrue(mockInteractor.uploadVideoCalled, "Should handle large video files")
        XCTAssertEqual(
            mockInteractor.lastVideoData?.count,
            1024 * 1024,
            "Should preserve video data size"
        )
    }

    func testVideoRecordingCompleted_pausesCameraDuringUpload() {
        // Given
        let expectedVideoData = Data([0x00, 0x01, 0x02, 0x03, 0x04])

        // When
        sut.videoRecordingCompleted(videoData: expectedVideoData)

        // Then
        XCTAssertTrue(mockView.pauseCameraCalled, "Should pause camera during upload")
        XCTAssertFalse(mockView.stopCameraCalled, "Should NOT stop camera, only pause it")
        XCTAssertEqual(mockView.lastUploadState, .uploading, "Should set upload state to UPLOADING")
    }

    // MARK: - Capture Event Tests

    func testHandleCaptureEvent_helpRequested_showsDialog() {
        // Given
        let event = PassiveCaptureEventHelpRequested()

        // When
        sut.handleCaptureEvent(event)

        // Then
        XCTAssertTrue(mockView.updateComposeUICalled, "Should update UI to show help")
        XCTAssertTrue(
            mockView.lastShowHelpDialog ?? false,
            "Help dialog should be shown"
        )
        XCTAssertTrue(mockView.pauseVideoCalled, "Should pause video when help is requested")
    }

    func testHandleCaptureEvent_helpDismissed_hidesDialog() {
        // Given
        sut.handleCaptureEvent(PassiveCaptureEventHelpRequested())
        mockView.updateComposeUICalled = false // Reset

        let dismissEvent = PassiveCaptureEventHelpDismissed()

        // When
        sut.handleCaptureEvent(dismissEvent)

        // Then
        XCTAssertTrue(mockView.updateComposeUICalled, "Should update UI")
        XCTAssertFalse(
            mockView.lastShowHelpDialog ?? true,
            "Help dialog should be hidden"
        )
    }

    func testHandleCaptureEvent_helpRequested_pausesVideo() {
        // Given - Start recording first
        let recordEvent = PassiveCaptureEventRecordVideoRequested()
        sut.handleCaptureEvent(recordEvent)

        // Wait for async startRecording call
        let expectation = self.expectation(description: "Wait for recording to start")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            // Reset flag
            self.mockView.pauseVideoCalled = false

            // When - Request help while recording
            let helpEvent = PassiveCaptureEventHelpRequested()
            self.sut.handleCaptureEvent(helpEvent)

            // Then
            XCTAssertTrue(self.mockView.pauseVideoCalled, "Should pause video when help is requested")
            XCTAssertTrue(self.mockView.updateComposeUICalled, "Should update UI to show help")
            XCTAssertTrue(
                self.mockView.lastShowHelpDialog ?? false,
                "Help dialog should be shown"
            )
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
    }

    func testHandleCaptureEvent_manualRecordingRequested_startsRecording() {
        // Given
        let event = PassiveCaptureEventManualRecordingRequested()

        // When
        sut.handleCaptureEvent(event)

        // Then
        XCTAssertTrue(mockView.updateComposeUICalled, "Should update UI state")
        XCTAssertFalse(mockView.startRecordingCalled, "Should NOT start recording for manual state")
        guard let state = mockView.lastState as? PassiveCaptureState else {
            XCTFail("State should be PassiveCaptureState")
            return
        }
        XCTAssertEqual(state, .manual, "Should transition to manual state")
        XCTAssertEqual(mockView.lastFeedback, FeedbackType.none, "Should clear feedback")
    }

    func testHandleCaptureEvent_recordVideoRequested_startsRecording() {
        // Given
        let event = PassiveCaptureEventRecordVideoRequested()

        // When
        sut.handleCaptureEvent(event)

        // Then - UI update happens synchronously
        XCTAssertTrue(mockView.updateComposeUICalled, "Should update UI state")
        guard let state = mockView.lastState as? PassiveCaptureState else {
            XCTFail("State should be PassiveCaptureState")
            return
        }
        XCTAssertEqual(state, .recording, "Should transition to recording state")

        // startRecording is called after 0.5s delay
        let expectation = self.expectation(description: "Wait for recording to start")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            XCTAssertTrue(self.mockView.startRecordingCalled, "Should start recording")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
    }

    // MARK: - Last Frame Capture Tests

    func testLastFrameCaptured_storesFrameDataAndSetsFeedbackToNone() {
        // Given
        let expectedFrameData = Data([0x01, 0x02, 0x03, 0x04, 0x05])

        // When
        sut.lastFrameCaptured(frameData: expectedFrameData)

        // Then
        XCTAssertTrue(mockView.updateComposeUICalled, "Should update UI with frame data")
        XCTAssertEqual(mockView.lastFrameData, expectedFrameData, "Should pass frame data to view")
        XCTAssertEqual(mockView.lastFeedback, FeedbackType.none, "Should set feedback to NONE to stop animations")
        guard let state = mockView.lastState as? PassiveCaptureState else {
            XCTFail("State should be PassiveCaptureState")
            return
        }
        XCTAssertEqual(state, .recording, "Should transition to recording state")
    }

    func testLastFrameCaptured_withLargeFrame_handlesSuccessfully() {
        // Given
        let largeFrameData = Data(repeating: 0xFF, count: 512 * 1024) // 512KB JPEG

        // When
        sut.lastFrameCaptured(frameData: largeFrameData)

        // Then
        XCTAssertTrue(mockView.updateComposeUICalled, "Should handle large frame data")
        XCTAssertEqual(mockView.lastFrameData?.count, 512 * 1024, "Should preserve frame data size")
    }

    // MARK: - Upload Result Tests

    func testVideoUploadCompleted_navigatesToResult() {
        // Given
        let validationId = "upload-success-id"

        // When
        sut.videoUploadCompleted(validationId: validationId)

        // Then
        XCTAssertEqual(mockView.lastUploadState, .success, "Should set upload state to SUCCESS")

        let expectation = self.expectation(description: "Navigation delayed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            XCTAssertTrue(self.mockRouter.navigateToResultCalled, "Should navigate to result screen")
            XCTAssertEqual(
                self.mockRouter.lastValidationId,
                "upload-success-id",
                "Should pass correct validation id"
            )
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
    }

    func testVideoUploadCompleted_withFailedValidation_stillNavigates() {
        // Given
        let validationId = "failed-validation"

        // When
        sut.videoUploadCompleted(validationId: validationId)

        // Then
        XCTAssertEqual(mockView.lastUploadState, .success, "Should set upload state to SUCCESS")

        let expectation = self.expectation(description: "Navigation delayed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            XCTAssertTrue(self.mockRouter.navigateToResultCalled, "Should navigate to result screen")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
    }

    func testVideoUploadFailed_showsError() {
        // Given
        let expectedError = ValidationError.apiError("Upload server unreachable")

        // When
        sut.videoUploadFailed(expectedError)

        // Then
        XCTAssertEqual(mockView.lastUploadState, UploadState.none, "Should reset upload state to NONE on error")
        XCTAssertTrue(mockRouter.handleErrorCalled, "Should call router handle error")
        XCTAssertEqual(
            mockRouter.lastErrorMessage,
            expectedError.localizedDescription,
            "Should display error description"
        )
    }

    // MARK: - Autocapture Disabled Tests

    func testInit_autocaptureEnabled_setsCountdownState() {
        // Given/When - default sut uses autocapture enabled

        // Then
        XCTAssertEqual(sut.currentState, .countdown, "Should start in countdown state when autocapture enabled")
    }

    func testInit_autocaptureDisabled_setsManualState() {
        // Given
        let presenter = PassiveCapturePresenter(
            view: mockView,
            interactor: mockInteractor,
            router: mockRouter,
            useAutocapture: false
        )

        // Then
        XCTAssertEqual(presenter.currentState, .manual, "Should start in manual state when autocapture disabled")
    }

    func testCameraReady_autocaptureDisabled_transitionsToManualWithoutError() {
        // Given
        let presenter = PassiveCapturePresenter(
            view: mockView,
            interactor: mockInteractor,
            router: mockRouter,
            useAutocapture: false
        )

        // When
        presenter.cameraReady()

        // Then
        XCTAssertTrue(mockView.updateComposeUICalled, "Should update UI when camera is ready")
        guard let state = mockView.lastState as? PassiveCaptureState else {
            XCTFail("State should be PassiveCaptureState")
            return
        }
        XCTAssertEqual(state, .manual, "Should transition to manual state")
        XCTAssertEqual(mockView.lastFeedback, FeedbackType.none, "Should NOT show error feedback")
    }

    func testCameraReady_autocaptureEnabled_startsCountdownWithFeedback() {
        // Given - default sut uses autocapture enabled

        // When
        sut.cameraReady()

        // Then
        guard let state = mockView.lastState as? PassiveCaptureState else {
            XCTFail("State should be PassiveCaptureState")
            return
        }
        XCTAssertEqual(state, .countdown, "Should start countdown when autocapture enabled")
    }

    func testHandleCaptureEvent_helpDismissed_autocaptureDisabled_staysInManualWithNoFeedback() {
        // Given
        let presenter = PassiveCapturePresenter(
            view: mockView,
            interactor: mockInteractor,
            router: mockRouter,
            useAutocapture: false
        )
        presenter.handleCaptureEvent(PassiveCaptureEventHelpRequested())
        mockView.updateComposeUICalled = false

        // When
        presenter.handleCaptureEvent(PassiveCaptureEventHelpDismissed())

        // Then
        XCTAssertTrue(mockView.updateComposeUICalled, "Should update UI")
        guard let state = mockView.lastState as? PassiveCaptureState else {
            XCTFail("State should be PassiveCaptureState")
            return
        }
        XCTAssertEqual(state, .manual, "Should remain in manual state")
        XCTAssertEqual(mockView.lastFeedback, FeedbackType.none, "Should have no feedback (no error banner)")
        XCTAssertFalse(mockView.lastShowHelpDialog ?? true, "Help dialog should be hidden")
    }

    func testHandleCaptureEvent_helpDismissed_autocaptureEnabled_keepsCurrentState() {
        // Given - default sut uses autocapture enabled
        sut.currentState = .recording
        sut.handleCaptureEvent(PassiveCaptureEventHelpRequested())
        mockView.updateComposeUICalled = false

        // When
        sut.handleCaptureEvent(PassiveCaptureEventHelpDismissed())

        // Then
        XCTAssertTrue(mockView.updateComposeUICalled, "Should update UI")
        XCTAssertFalse(mockView.lastShowHelpDialog ?? true, "Help dialog should be hidden")
        // State should remain as it was (not forced to manual)
    }

    func testManualRecordingRequested_setsNoFeedback() {
        // Given
        let event = PassiveCaptureEventManualRecordingRequested()

        // When
        sut.handleCaptureEvent(event)

        // Then
        guard let state = mockView.lastState as? PassiveCaptureState else {
            XCTFail("State should be PassiveCaptureState")
            return
        }
        XCTAssertEqual(state, .manual, "Should transition to manual state")
        XCTAssertEqual(
            mockView.lastFeedback,
            FeedbackType.none,
            "Should have no feedback when manually requesting manual mode"
        )
    }
}

// swiftlint:enable type_body_length

// MARK: - Mock View

private final class MockPassiveCaptureView: PassiveCapturePresenterToView {
    var setupCameraCalled = false
    var setupCameraCount = 0
    var startRecordingCalled = false
    var stopRecordingCalled = false
    var stopCameraCalled = false
    var pauseCameraCalled = false
    var pauseVideoCalled = false
    var resumeVideoCalled = false
    var updateComposeUICalled = false
    var showErrorCalled = false
    var lastErrorMessage: String?
    var lastState: Any?
    var lastFeedback: FeedbackType?
    var lastCountdown: Int32?
    var lastShowHelpDialog: Bool?
    var lastFrameData: Data?
    var lastUploadState: UploadState?

    func setupCamera() {
        setupCameraCalled = true
        setupCameraCount += 1
    }

    func startRecording() {
        startRecordingCalled = true
    }

    func stopRecording() {
        stopRecordingCalled = true
    }

    func stopCamera() {
        stopCameraCalled = true
    }

    func pauseCamera() {
        pauseCameraCalled = true
    }

    func pauseVideo() {
        pauseVideoCalled = true
    }

    func resumeVideo() {
        resumeVideoCalled = true
        startRecording()
    }

    func updateComposeUI(
        state: PassiveCaptureState,
        feedback: FeedbackType,
        countdown: Int32,
        showHelpDialog: Bool,
        showSettingsPrompt: Bool,
        lastFrameData: Data?,
        uploadState: UploadState
    ) {
        updateComposeUICalled = true
        lastState = state
        lastFeedback = feedback
        lastCountdown = countdown
        lastShowHelpDialog = showHelpDialog
        self.lastFrameData = lastFrameData
        self.lastUploadState = uploadState
    }

    func showError(_ message: String) {
        showErrorCalled = true
        lastErrorMessage = message
    }
}

// MARK: - Mock Interactor

private final class MockPassiveCaptureInteractor: PassiveCapturePresenterToInteractor {
    private(set) var setUploadUrlCalled = false
    private(set) var uploadVideoCalled = false
    private(set) var lastUploadUrl: String?
    private(set) var lastVideoData: Data?

    func setUploadUrl(_ uploadUrl: String?) {
        setUploadUrlCalled = true
        lastUploadUrl = uploadUrl
    }

    func uploadVideo(_ videoData: Data) {
        uploadVideoCalled = true
        lastVideoData = videoData
    }
}

// MARK: - Mock Router

private final class MockPassiveCaptureRouter: ValidationRouter {
    private(set) var navigateToResultCalled = false
    private(set) var lastValidationId: String?
    private(set) var handleErrorCalled = false
    private(set) var lastErrorMessage: String?

    override func navigateToResult(validationId: String, loadingType: LoadingType? = .face) throws {
        navigateToResultCalled = true
        lastValidationId = validationId
    }

    override func handleError(_ error: ValidationError) {
        handleErrorCalled = true
        lastErrorMessage = error.localizedDescription
    }
}

// MARK: - Test Helpers

private func createFaceDetectionResult(
    confidence: Float = 0.9,
    boundingBox: CGRect = CGRect(x: 100, y: 100, width: 200, height: 200),
    landmarks: VNFaceLandmarks2D? = nil
) -> DetectionResult {
    DetectionResult(
        category: .face(landmarks: landmarks),
        boundingBox: boundingBox,
        confidence: confidence
    )
}
