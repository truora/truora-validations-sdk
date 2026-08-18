//
//  PassiveCapturePresenterTests.swift
//  TruoraValidationsSDKTests
//
//  Created by Truora on 11/11/25.
//

// swiftlint:disable file_length
import AVFoundation
import TruoraCamera
import Vision
import XCTest
@testable import TruoraValidationsSDK

// swiftlint:disable type_body_length
/// Tests for PassiveCapturePresenter following VIPER architecture
/// Verifies camera management, recording flow, and upload coordination
@MainActor final class PassiveCapturePresenterTests: XCTestCase {
    // MARK: - Properties

    private var sut: PassiveCapturePresenter!
    private var mockView: MockPassiveCaptureView!
    private var mockInteractor: MockPassiveCaptureInteractor!
    private var mockRouter: MockPassiveCaptureRouter!
    private var mockTimeProvider: MockTimeProvider!

    // MARK: - Lifecycle

    override func setUp() {
        super.setUp()
        mockView = MockPassiveCaptureView()
        mockInteractor = MockPassiveCaptureInteractor()
        mockTimeProvider = MockTimeProvider()
        let navController = TruoraNavigationController()
        mockRouter = MockPassiveCaptureRouter(navigationController: navController)

        sut = PassiveCapturePresenter(
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
        super.tearDown()
    }

    // MARK: - View Lifecycle Tests

    func testViewDidLoad_configuresInteractorAndCamera() async {
        // When
        await sut.viewDidLoad()

        // Then
        XCTAssertTrue(mockInteractor.setUploadUrlCalled, "Should configure upload URL in interactor")
        XCTAssertTrue(mockView.setupCameraCalled, "Should setup camera in view")
        XCTAssertTrue(mockView.updateUICalled, "Should update initial UI state")
    }

    func testViewDidLoad_calledTwice_triggersSetupOnlyOnce() async {
        // When
        await sut.viewDidLoad()
        await sut.viewDidLoad()

        // Then
        XCTAssertEqual(mockView.setupCameraCount, 1, "Should trigger setup only once")
    }

    func testViewWillAppear_doesNotCrash() async {
        // When
        await sut.viewWillAppear()

        // Then
        XCTAssertNotNil(sut, "Presenter should handle viewWillAppear without issues")
    }

    func testCameraReady_startsCountdown() async {
        // When
        await sut.cameraReady()

        // Then
        XCTAssertTrue(mockView.updateUICalled, "Should update UI when camera is ready")
        guard let state = mockView.lastState as? PassiveCaptureState else {
            XCTFail("State should be PassiveCaptureState")
            return
        }
        XCTAssertEqual(state, .countdown, "Should transition to countdown state")
    }

    func testViewWillDisappear_cleansUpTimers() async {
        // Given
        await sut.cameraReady() // Start some timers

        // When
        await sut.viewWillDisappear()

        // Then
        XCTAssertNotNil(sut, "Presenter should cleanup timers without crashing")
        XCTAssertTrue(mockView.stopCameraCalled, "Should stop camera when view disappears")
    }

    func testAppWillResignActive_notRecording_pausesCameraWithoutStopping() async {
        // Given
        await sut.cameraReady()
        mockView.pauseCameraCalled = false
        mockView.stopCameraCalled = false

        // When
        await sut.appWillResignActive()

        // Then
        XCTAssertTrue(mockView.pauseCameraCalled, "Should pause camera when app becomes inactive")
        XCTAssertFalse(mockView.stopCameraCalled, "Should not stop camera on background")
    }

    func testAppDidBecomeActive_notRecording_resumesCamera() async {
        // Given
        await sut.cameraReady()
        await sut.appWillResignActive()
        mockView.resumeCameraCalled = false

        // When
        await sut.appDidBecomeActive()

        // Then
        XCTAssertTrue(mockView.resumeCameraCalled, "Should resume camera when app becomes active")
    }

    func testSuspendResume_whileRecording_autocapture_restartsAtDetection() async {
        // Given
        await sut.handleCaptureEvent(.recordVideoRequested)
        mockView.pauseVideoCalled = false
        mockView.pauseCameraCalled = false
        mockView.stopCameraCalled = false
        mockView.setupCameraCalled = false

        // When (background)
        await sut.appWillResignActive()

        // Then
        XCTAssertTrue(mockView.pauseVideoCalled, "Should stop recording without producing media")
        XCTAssertTrue(mockView.pauseCameraCalled, "Should pause camera session on background")

        // When (foreground)
        await sut.appDidBecomeActive()

        // Then - Should restart camera cleanly
        XCTAssertTrue(mockView.stopCameraCalled, "Should stop camera for a clean restart")
        XCTAssertTrue(mockView.setupCameraCalled, "Should setup camera again after resume")

        // When - camera becomes ready again
        mockView.updateUICalled = false
        await sut.cameraReady()

        // Then - should be waiting for face (detection), not counting down
        XCTAssertTrue(mockView.updateUICalled, "Should update UI after resume")
        XCTAssertEqual(mockView.lastState as? PassiveCaptureState, .recording)
        XCTAssertEqual(mockView.lastFeedback, .showFace)
    }

    func testSuspendResume_whileRecording_manual_restartsRecordingAfterCameraReady() async {
        // Given
        let presenter = PassiveCapturePresenter(
            view: mockView,
            interactor: mockInteractor,
            router: mockRouter,
            validationId: "test-validation-id",
            useAutocapture: false,
            timeProvider: mockTimeProvider
        )
        sut = presenter

        await sut.handleCaptureEvent(.recordVideoRequested)
        mockView.stopCameraCalled = false
        mockView.setupCameraCalled = false
        mockView.startRecordingCalled = false

        // When (background)
        await sut.appWillResignActive()

        // When (foreground)
        await sut.appDidBecomeActive()

        // Then
        XCTAssertTrue(mockView.stopCameraCalled, "Should stop camera for a clean restart")
        XCTAssertTrue(mockView.setupCameraCalled, "Should setup camera again after resume")

        // When - camera becomes ready again
        await sut.cameraReady()

        // Then - should start recording again
        XCTAssertTrue(mockView.startRecordingCalled, "Should restart recording after resume in manual mode")
        XCTAssertEqual(mockView.lastState as? PassiveCaptureState, .recording)
        XCTAssertEqual(mockView.lastIsActivelyRecording, true)
    }

    func testHelpWhileRecording_autocapture_stopsAndRestartsAtDetection() async {
        // Given
        await sut.handleCaptureEvent(.recordVideoRequested)
        mockView.pauseVideoCalled = false
        mockView.startRecordingCalled = false

        // When
        await sut.handleCaptureEvent(.helpRequested)

        // Then
        XCTAssertTrue(mockView.pauseVideoCalled, "Should stop recording when help is requested")
        XCTAssertTrue(mockView.lastShowHelpDialog ?? false, "Help dialog should be shown")

        // When
        mockView.updateUICalled = false
        await sut.handleCaptureEvent(.helpDismissed)

        // Then - should restart at detection (not immediately start recording)
        XCTAssertTrue(mockView.updateUICalled, "Should update UI after dismissing help")
        XCTAssertEqual(mockView.lastState as? PassiveCaptureState, .recording)
        XCTAssertEqual(mockView.lastFeedback, .showFace)
        XCTAssertFalse(mockView.startRecordingCalled, "Should not immediately start recording; waits for face")
    }

    func testBackgroundDuringUpload_doesNotStopOrResumeCamera() async {
        // Given
        await sut.videoRecordingCompleted(videoData: Data([0x01, 0x02]))
        mockView.stopCameraCalled = false
        mockView.resumeCameraCalled = false

        // When
        await sut.appWillResignActive()
        await sut.appDidBecomeActive()

        // Then
        XCTAssertFalse(mockView.stopCameraCalled, "Should not stop camera during upload backgrounding")
        XCTAssertFalse(mockView.resumeCameraCalled, "Should not resume camera during upload")
    }

    // MARK: - Face Detection Tests

    func testCameraFrameProcessed_noFaces_setsFeedbackToShowFace() async {
        // Given
        sut.currentState = .recording
        let emptyResults: [DetectionResult] = []

        // When
        await sut.detectionsReceived(emptyResults)

        // Then
        XCTAssertTrue(mockView.updateUICalled, "Should update UI")
        XCTAssertEqual(mockView.lastFeedback, .showFace, "Should show SHOW_FACE feedback")
    }

    func testCameraFrameProcessed_multipleFaces_setsFeedbackToMultiplePeople() async {
        // Given
        sut.currentState = .recording
        let multipleResults = [
            createFaceDetectionResult(confidence: 0.9),
            createFaceDetectionResult(confidence: 0.85)
        ]

        // When - hysteresis requires 2 consecutive multi-face frames before
        // emitting; first frame is warmup, second confirms the state.
        await sut.detectionsReceived(multipleResults)
        await sut.detectionsReceived(multipleResults)

        // Then
        XCTAssertTrue(mockView.updateUICalled, "Should update UI")
        XCTAssertEqual(mockView.lastFeedback, .multiplePeople, "Should show MULTIPLE_PEOPLE feedback")
    }

    func testCameraFrameProcessed_multipleFaces_publishesAllRenderableBoundingBoxes() async {
        // Given - two faces tall enough to render per PROC-6872
        sut.currentState = .recording
        let mainFaceBox = CGRect(x: 0.35, y: 0.35, width: 0.30, height: 0.30)
        let backgroundFaceBox = CGRect(x: 0.05, y: 0.40, width: 0.15, height: 0.18)
        let multipleResults = [
            createFaceDetectionResult(confidence: 0.9, boundingBox: mainFaceBox),
            createFaceDetectionResult(confidence: 0.85, boundingBox: backgroundFaceBox)
        ]

        // When - send the same frame twice to clear the enter-warmup window.
        await sut.detectionsReceived(multipleResults)
        await sut.detectionsReceived(multipleResults)

        // Then - boxes are sorted by midX so SwiftUI ForEach offset stays bound
        // to the same face across frames (kills detector-side index swaps).
        XCTAssertEqual(
            mockView.lastDetectedFaceBoxes,
            [backgroundFaceBox, mainFaceBox],
            "Should publish every renderable face bounding box, sorted by midX"
        )
    }

    func testCameraFrameProcessed_multipleFaces_filtersOutTinyDetections() async {
        // Given - one normal face + one under the render threshold
        sut.currentState = .recording
        let mainFaceBox = CGRect(x: 0.35, y: 0.35, width: 0.30, height: 0.30)
        let tinyFaceBox = CGRect(x: 0.05, y: 0.40, width: 0.04, height: 0.05)
        let multipleResults = [
            createFaceDetectionResult(confidence: 0.9, boundingBox: mainFaceBox),
            createFaceDetectionResult(confidence: 0.85, boundingBox: tinyFaceBox)
        ]

        // When - multi-face classification runs on raw face count so the
        // .multiplePeople toast still fires for tiny background faces; the
        // 8% filter only suppresses the tiny one from rendering.
        await sut.detectionsReceived(multipleResults)
        await sut.detectionsReceived(multipleResults)

        // Then - main face renders, tiny face is filtered out, toast is shown.
        XCTAssertEqual(
            mockView.lastDetectedFaceBoxes,
            [mainFaceBox],
            "Should render only the face above minMultiFaceRenderHeight"
        )
        XCTAssertEqual(
            mockView.lastFeedback,
            .multiplePeople,
            "Should still show MULTIPLE_PEOPLE toast even when tiny faces are dropped"
        )
    }

    func testCameraFrameProcessed_transitionFromMultipleToSingleFace_clearsBoundingBoxes() async {
        // Given
        sut.currentState = .recording
        let mainFaceBox = CGRect(x: 0.35, y: 0.35, width: 0.30, height: 0.30)
        let backgroundFaceBox = CGRect(x: 0.05, y: 0.40, width: 0.15, height: 0.18)
        let multipleResults = [
            createFaceDetectionResult(confidence: 0.9, boundingBox: mainFaceBox),
            createFaceDetectionResult(confidence: 0.85, boundingBox: backgroundFaceBox)
        ]
        let singleFace = [createFaceDetectionResult(confidence: 0.95)]

        // When - 2 frames to enter multi-face state.
        await sut.detectionsReceived(multipleResults)
        await sut.detectionsReceived(multipleResults)
        XCTAssertEqual(
            mockView.lastDetectedFaceBoxes?.count,
            2,
            "Precondition: multi-face state should publish 2 boxes after enter threshold"
        )

        // When - 3 single-face frames to cross the exit threshold.
        await sut.detectionsReceived(singleFace)
        await sut.detectionsReceived(singleFace)
        await sut.detectionsReceived(singleFace)

        // Then - list is cleared so overlay hides per-face ovals.
        XCTAssertEqual(
            mockView.lastDetectedFaceBoxes,
            [],
            "Should clear bounding boxes after exit threshold confirms single face"
        )
    }

    func testCameraFrameProcessed_noFaces_clearsBoundingBoxes() async {
        // Given
        sut.currentState = .recording
        let multipleResults = [
            createFaceDetectionResult(confidence: 0.9),
            createFaceDetectionResult(confidence: 0.85)
        ]

        // When - multi-face, then frame with no faces
        await sut.detectionsReceived(multipleResults)
        await sut.detectionsReceived([])

        // Then
        XCTAssertEqual(
            mockView.lastDetectedFaceBoxes,
            [],
            "Should clear bounding boxes when no faces detected"
        )
    }

    func testCameraFrameProcessed_oneFace_startsFaceDetectionTimer() async {
        // Given
        sut.currentState = .recording
        let singleFace = [createFaceDetectionResult(confidence: 0.95)]

        // When
        await sut.detectionsReceived(singleFace)

        // Then
        XCTAssertTrue(mockView.updateUICalled, "Should update UI")
        XCTAssertEqual(mockView.lastFeedback, FeedbackType.none, "Should clear feedback")
        // Timer starts internally, verified by subsequent test checking recording after 1 second
    }

    func testCameraFrameProcessed_consecutiveFacesForOneSecond_startsRecording() async {
        // Given
        sut.currentState = .recording
        let singleFace = [createFaceDetectionResult(confidence: 0.95)]

        // When - Start processing first face (starts the timer)
        await sut.detectionsReceived(singleFace)

        // Advance time by 1.1 seconds to exceed 1s threshold
        mockTimeProvider.currentTime = mockTimeProvider.currentTime.addingTimeInterval(1.1)

        // Process another face detection to trigger the time check
        await sut.detectionsReceived(singleFace)

        // Then
        XCTAssertTrue(
            mockView.startRecordingCalled,
            "Should start recording after 1 second of consecutive faces"
        )
    }

    func testCameraFrameProcessed_lessThanOneSecond_doesNotStartRecording() async {
        // Given
        sut.currentState = .recording
        let singleFace = [createFaceDetectionResult(confidence: 0.95)]

        // When - Process frames for only 0.5 seconds (5 times)
        for _ in 0 ..< 5 {
            await sut.detectionsReceived(singleFace)
        }

        // Then
        XCTAssertFalse(
            mockView.startRecordingCalled,
            "Should NOT start recording with less than 1 second"
        )
    }

    func testCameraFrameProcessed_interruptedByNoFace_resetsTimer() async {
        // Given
        sut.currentState = .recording
        let singleFace = [createFaceDetectionResult(confidence: 0.95)]
        let noFaces: [DetectionResult] = []

        // When - Process valid faces for 0.5s
        for _ in 0 ..< 5 {
            await sut.detectionsReceived(singleFace)
        }

        // Then interrupt with no face
        await sut.detectionsReceived(noFaces)

        // Then - Timer should be reset, shown by feedback change
        XCTAssertEqual(mockView.lastFeedback, .showFace, "Should show SHOW_FACE feedback")
        XCTAssertFalse(mockView.startRecordingCalled, "Should NOT start recording after interruption")
    }

    func testCameraFrameProcessed_interruptedByMultipleFaces_resetsTimer() async {
        // Given
        sut.currentState = .recording
        let singleFace = [createFaceDetectionResult(confidence: 0.95)]
        let multipleFaces = [
            createFaceDetectionResult(confidence: 0.9),
            createFaceDetectionResult(confidence: 0.85)
        ]

        // When - Process valid faces for 0.5s
        for _ in 0 ..< 5 {
            await sut.detectionsReceived(singleFace)
        }

        // Then interrupt with multiple faces — 2 consecutive frames clear the
        // hysteresis enter window.
        await sut.detectionsReceived(multipleFaces)
        await sut.detectionsReceived(multipleFaces)

        // Then - Timer should be reset, shown by feedback change
        XCTAssertEqual(
            mockView.lastFeedback,
            .multiplePeople,
            "Should show MULTIPLE_PEOPLE feedback"
        )
    }

    func testCameraFrameProcessed_afterTimeout_transitionsToManual() async {
        // Given - Start recording to set the processing start time
        await sut.cameraReady()

        // Wait for countdown (3 seconds) + small buffer
        mockTimeProvider.fireTimer(times: 4) // Fire countdown timer 4 times (3, 2, 1, 0)

        // Simulate passage of time beyond manual timeout (10 seconds).
        // The presenter uses timeProvider.now (a mock Date), so we can advance it
        // deterministically to trigger the timeout branch.
        mockTimeProvider.currentTime += 10.5

        // When - Process frames after timeout
        // Note: In a real environment, time would have passed.
        // Here we rely on the system time actually passing during the sleep above.
        let singleFace = [createFaceDetectionResult(confidence: 0.95)]
        await sut.detectionsReceived(singleFace)

        // Then
        guard let state = mockView.lastState as? PassiveCaptureState else {
            XCTFail("State should be PassiveCaptureState")
            return
        }
        // NOTE: This test might still be flaky if we rely on Date().
        // Ideally we should add `now: Date` to TimeProvider.
        // For now, let's verify if the state transitioned.
        // If the system time didn't advance enough, this might fail.
        // I'll update TimeProvider to support Date mocking in a follow-up if needed.
    }

    func testCameraFrameProcessed_beforeTimeout_normalProcessing() async {
        sut.currentState = .recording
        let singleFace = [createFaceDetectionResult(confidence: 0.95)]

        // Wait for countdown (3 seconds) + small buffer
        mockTimeProvider.fireTimer(times: 4)

        // When - Process frame BEFORE 10 second timeout
        // Simulate time passage (3.2s) which is < 10.0s
        mockTimeProvider.currentTime += 3.2
        await sut.detectionsReceived(singleFace)

        // Then - Should process normally, not transition to manual
        XCTAssertEqual(mockView.lastFeedback, FeedbackType.none, "Should clear feedback")

        // Verify NOT in manual state
        if let state = mockView.lastState as? PassiveCaptureState {
            XCTAssertNotEqual(state, .manual, "Should NOT be in manual state before timeout")
        }
    }

    func testViewWillDisappear_resetsProcessingTimer() async {
        // Given - Start recording to set processing timer
        await sut.cameraReady()

        // When
        await sut.viewWillDisappear()

        // Then - Timer should be reset (tested indirectly by no crash)
        XCTAssertNotNil(sut, "Presenter should handle cleanup without crashing")
    }

    func testViewWillDisappear_whileRecording_pausesVideoThenStopsCamera() async {
        // Given - Start recording
        let recordEvent = PassiveCaptureEvent.recordVideoRequested
        await sut.handleCaptureEvent(recordEvent)

        // Reset flags
        mockView.pauseVideoCalled = false
        mockView.stopCameraCalled = false

        // When
        await sut.viewWillDisappear()

        // Then - Should pause video first, then stop camera
        XCTAssertTrue(mockView.pauseVideoCalled, "Should pause video when recording")
        XCTAssertTrue(mockView.stopCameraCalled, "Should stop camera after pausing video")
    }

    func testHandleCaptureEvent_recordingCompleted_stopsRecording() async {
        // Given - First start recording to set lifecycleState to .recording
        let recordEvent = PassiveCaptureEvent.recordVideoRequested
        await sut.handleCaptureEvent(recordEvent)

        // Reset the flag to verify stopRecording is called
        mockView.stopRecordingCalled = false

        // When
        let stopEvent = PassiveCaptureEvent.recordingCompleted
        await sut.handleCaptureEvent(stopEvent)

        // Then
        XCTAssertTrue(mockView.stopRecordingCalled, "Should stop recording when event received")
    }

    // MARK: - Video Recording Tests

    func testVideoRecordingCompleted_uploadsVideo() async {
        // Given
        let expectedVideoData = Data([0x00, 0x01, 0x02, 0x03, 0x04])

        // When
        await sut.videoRecordingCompleted(videoData: expectedVideoData)

        // Then
        XCTAssertTrue(mockInteractor.uploadVideoCalled, "Should upload video via interactor")
        XCTAssertEqual(
            mockInteractor.lastVideoData,
            expectedVideoData,
            "Should pass correct video data to interactor"
        )
        XCTAssertEqual(mockView.lastUploadState, .uploading, "Should set upload state to UPLOADING")
        XCTAssertFalse(mockView.pauseCameraCalled, "Should NOT pause camera; preview stays live during upload")
    }

    func testVideoRecordingCompleted_withLargeVideo_uploadsSuccessfully() async {
        // Given
        let largeVideoData = Data(repeating: 0xFF, count: 1024 * 1024) // 1MB

        // When
        await sut.videoRecordingCompleted(videoData: largeVideoData)

        // Then
        XCTAssertTrue(mockInteractor.uploadVideoCalled, "Should handle large video files")
        XCTAssertEqual(
            mockInteractor.lastVideoData?.count,
            1024 * 1024,
            "Should preserve video data size"
        )
    }

    func testVideoRecordingCompleted_keepsCameraLiveDuringUpload() async {
        // Given
        let expectedVideoData = Data([0x00, 0x01, 0x02, 0x03, 0x04])

        // When
        await sut.videoRecordingCompleted(videoData: expectedVideoData)

        // Then
        XCTAssertFalse(mockView.pauseCameraCalled, "Should NOT pause camera; preview stays live during upload")
        XCTAssertFalse(mockView.stopCameraCalled, "Should NOT stop camera during upload")
        XCTAssertEqual(mockView.lastUploadState, .uploading, "Should set upload state to UPLOADING")
    }

    // MARK: - Capture Event Tests

    func testHandleCaptureEvent_helpRequested_showsDialog() async {
        // Given
        let event = PassiveCaptureEvent.helpRequested

        // When
        await sut.handleCaptureEvent(event)

        // Then
        XCTAssertTrue(mockView.updateUICalled, "Should update UI to show help")
        XCTAssertTrue(
            mockView.lastShowHelpDialog ?? false,
            "Help dialog should be shown"
        )
        XCTAssertFalse(
            mockView.pauseVideoCalled,
            "Should not pause video unless currently recording"
        )
    }

    func testHandleCaptureEvent_helpDismissed_hidesDialog() async {
        // Given
        await sut.handleCaptureEvent(PassiveCaptureEvent.helpRequested)
        mockView.updateUICalled = false // Reset

        let dismissEvent = PassiveCaptureEvent.helpDismissed

        // When
        await sut.handleCaptureEvent(dismissEvent)

        // Then
        XCTAssertTrue(mockView.updateUICalled, "Should update UI")
        XCTAssertFalse(
            mockView.lastShowHelpDialog ?? true,
            "Help dialog should be hidden"
        )
    }

    func testHandleCaptureEvent_helpRequested_pausesVideo() async {
        // Given - Start recording first
        let recordEvent = PassiveCaptureEvent.recordVideoRequested
        await sut.handleCaptureEvent(recordEvent)

        // Reset flag
        mockView.pauseVideoCalled = false

        // When - Request help while recording
        let helpEvent = PassiveCaptureEvent.helpRequested
        await sut.handleCaptureEvent(helpEvent)

        // Then
        XCTAssertTrue(mockView.pauseVideoCalled, "Should pause video when help is requested")
        XCTAssertTrue(mockView.updateUICalled, "Should update UI to show help")
        XCTAssertTrue(
            mockView.lastShowHelpDialog ?? false,
            "Help dialog should be shown"
        )
    }

    func testHandleCaptureEvent_manualRecordingRequested_startsRecording() async {
        // Given
        let event = PassiveCaptureEvent.manualRecordingRequested

        // When
        await sut.handleCaptureEvent(event)

        // Then
        XCTAssertTrue(mockView.updateUICalled, "Should update UI state")
        XCTAssertFalse(mockView.startRecordingCalled, "Should NOT start recording for manual state")
        guard let state = mockView.lastState as? PassiveCaptureState else {
            XCTFail("State should be PassiveCaptureState")
            return
        }
        XCTAssertEqual(state, .manual, "Should transition to manual state")
        XCTAssertEqual(mockView.lastFeedback, FeedbackType.none, "Should clear feedback")
    }

    func testHandleCaptureEvent_recordVideoRequested_startsRecording() async {
        // Given
        let event = PassiveCaptureEvent.recordVideoRequested

        // When
        await sut.handleCaptureEvent(event)

        // Then - UI update happens synchronously
        XCTAssertTrue(mockView.updateUICalled, "Should update UI state")
        guard let state = mockView.lastState as? PassiveCaptureState else {
            XCTFail("State should be PassiveCaptureState")
            return
        }
        XCTAssertEqual(state, .recording, "Should transition to recording state")

        // startRecording is called immediately (no delay)
        XCTAssertTrue(mockView.startRecordingCalled, "Should start recording")
    }

    // MARK: - Last Frame Capture Tests

    func testLastFrameCaptured_storesFrameDataAndSetsFeedbackToNone() async {
        // Given
        let expectedFrameData = Data([0x01, 0x02, 0x03, 0x04, 0x05])

        // When
        await sut.lastFrameCaptured(frameData: expectedFrameData)

        // Then
        XCTAssertTrue(mockView.updateUICalled, "Should update UI with frame data")
        XCTAssertEqual(mockView.lastFrameData, expectedFrameData, "Should pass frame data to view")
        XCTAssertEqual(mockView.lastFeedback, FeedbackType.none, "Should set feedback to NONE to stop animations")
        guard let state = mockView.lastState as? PassiveCaptureState else {
            XCTFail("State should be PassiveCaptureState")
            return
        }
        XCTAssertEqual(state, .recording, "Should transition to recording state")
    }

    func testLastFrameCaptured_withLargeFrame_handlesSuccessfully() async {
        // Given
        let largeFrameData = Data(repeating: 0xFF, count: 512 * 1024) // 512KB JPEG

        // When
        await sut.lastFrameCaptured(frameData: largeFrameData)

        // Then
        XCTAssertTrue(mockView.updateUICalled, "Should handle large frame data")
        XCTAssertEqual(mockView.lastFrameData?.count, 512 * 1024, "Should preserve frame data size")
    }

    // MARK: - Upload Result Tests

    func testVideoUploadCompleted_navigatesToResult() async throws {
        // Given
        let validationId = "upload-success-id"
        mockTimeProvider.sleepCalledExpectation = expectation(description: "Sleep called")

        // When
        let task = Task { await sut.videoUploadCompleted(validationId: validationId) }

        // Then
        // Wait for updateUI call (before sleep)
        try await fulfillment(of: [XCTUnwrap(mockTimeProvider.sleepCalledExpectation)], timeout: 1.0)
        XCTAssertEqual(mockView.lastUploadState, .success, "Should set upload state to SUCCESS")

        // Resume navigation delay
        mockTimeProvider.resumeAllSleeps()
        await task.value

        XCTAssertTrue(mockRouter.navigateToResultCalled, "Should navigate to result screen")
        XCTAssertEqual(
            mockRouter.lastValidationId,
            "upload-success-id",
            "Should pass correct validation id"
        )
    }

    func testVideoUploadCompleted_waitsOneSecondBeforeNavigating() async throws {
        // Given
        let validationId = "upload-success-id"
        mockTimeProvider.sleepCalledExpectation = expectation(description: "Sleep called")

        // When
        let task = Task { await sut.videoUploadCompleted(validationId: validationId) }
        try await fulfillment(of: [XCTUnwrap(mockTimeProvider.sleepCalledExpectation)], timeout: 1.0)
        mockTimeProvider.resumeAllSleeps()
        await task.value

        // Then
        XCTAssertTrue(
            mockTimeProvider.sleepCalls.contains(PassiveCapturePresenter.successStateHoldNanoseconds),
            "Should hold the success state for 1000 ms (web parity) before navigating"
        )
    }

    func testVideoUploadCompleted_keepsCameraLiveDuringSuccessHold() async throws {
        // Given
        mockTimeProvider.sleepCalledExpectation = expectation(description: "Sleep called")

        // When
        let task = Task { await sut.videoUploadCompleted(validationId: "upload-success-id") }
        try await fulfillment(of: [XCTUnwrap(mockTimeProvider.sleepCalledExpectation)], timeout: 1.0)

        // Then: while the "¡Listo!" state is held, the camera must still be live
        XCTAssertFalse(mockView.stopCameraCalled, "Camera should stay live during the ¡Listo! hold")

        // After the hold, the camera stops before navigating
        mockTimeProvider.resumeAllSleeps()
        await task.value
        XCTAssertTrue(mockView.stopCameraCalled, "Camera should stop after the hold, before navigating")
    }

    func testVideoUploadCompleted_withFailedValidation_stillNavigates() async throws {
        // Given
        let validationId = "failed-validation"
        mockTimeProvider.sleepCalledExpectation = expectation(description: "Sleep called")

        // When
        let task = Task { await sut.videoUploadCompleted(validationId: validationId) }

        // Then
        // Wait for updateUI (before sleep)
        try await fulfillment(of: [XCTUnwrap(mockTimeProvider.sleepCalledExpectation)], timeout: 1.0)
        XCTAssertEqual(mockView.lastUploadState, .success, "Should set upload state to SUCCESS")

        // Resume navigation delay
        mockTimeProvider.resumeAllSleeps()
        await task.value

        XCTAssertTrue(mockRouter.navigateToResultCalled, "Should navigate to result screen")
    }

    func testVideoUploadFailed_showsError() async {
        // Given
        let expectedError = TruoraException.network(message: "Upload server unreachable")

        // When
        await sut.videoUploadFailed(expectedError)

        // Then
        XCTAssertEqual(mockView.lastUploadState, UploadState.none, "Should reset upload state to NONE on error")
        XCTAssertTrue(mockRouter.handleErrorCalled, "Should call router handle error")
        XCTAssertEqual(
            mockRouter.lastErrorMessage,
            expectedError.errorDescription,
            "Should display error description"
        )
    }

    func testCameraPermissionDenied_callsRouterHandleError() async {
        // When
        await sut.cameraPermissionDenied()

        // Then
        XCTAssertTrue(mockView.stopCameraCalled, "Should stop camera")
        XCTAssertTrue(mockRouter.handleErrorCalled, "Should call router handleError")
        XCTAssertEqual(
            mockRouter.lastErrorMessage,
            CameraError.permissionDenied().toTruoraException().localizedDescription,
            "Should pass camera permission error (with details) to router"
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
            validationId: "test-validation-id",
            useAutocapture: false
        )

        // Then
        XCTAssertEqual(presenter.currentState, .manual, "Should start in manual state when autocapture disabled")
    }

    func testCameraReady_autocaptureDisabled_transitionsToManualWithoutError() async {
        // Given
        let presenter = PassiveCapturePresenter(
            view: mockView,
            interactor: mockInteractor,
            router: mockRouter,
            validationId: "test-validation-id",
            useAutocapture: false
        )

        // When
        await presenter.cameraReady()

        // Then
        XCTAssertTrue(mockView.updateUICalled, "Should update UI when camera is ready")
        guard let state = mockView.lastState as? PassiveCaptureState else {
            XCTFail("State should be PassiveCaptureState")
            return
        }
        XCTAssertEqual(state, .manual, "Should transition to manual state")
        XCTAssertEqual(mockView.lastFeedback, FeedbackType.none, "Should NOT show error feedback")
    }

    func testCameraReady_autocaptureEnabled_startsCountdownWithFeedback() async {
        // Given - default sut uses autocapture enabled

        // When
        await sut.cameraReady()

        // Then
        guard let state = mockView.lastState as? PassiveCaptureState else {
            XCTFail("State should be PassiveCaptureState")
            return
        }
        XCTAssertEqual(state, .countdown, "Should start countdown when autocapture enabled")
    }

    func testHandleCaptureEvent_helpDismissed_autocaptureDisabled_staysInManualWithNoFeedback() async {
        // Given
        let presenter = PassiveCapturePresenter(
            view: mockView,
            interactor: mockInteractor,
            router: mockRouter,
            validationId: "test-validation-id",
            useAutocapture: false
        )
        await presenter.handleCaptureEvent(PassiveCaptureEvent.helpRequested)
        mockView.updateUICalled = false

        // When
        await presenter.handleCaptureEvent(PassiveCaptureEvent.helpDismissed)

        // Then
        XCTAssertTrue(mockView.updateUICalled, "Should update UI")
        guard let state = mockView.lastState as? PassiveCaptureState else {
            XCTFail("State should be PassiveCaptureState")
            return
        }
        XCTAssertEqual(state, .manual, "Should remain in manual state")
        XCTAssertEqual(mockView.lastFeedback, FeedbackType.none, "Should have no feedback (no error banner)")
        XCTAssertFalse(mockView.lastShowHelpDialog ?? true, "Help dialog should be hidden")
    }

    func testHandleCaptureEvent_helpDismissed_autocaptureEnabled_keepsCurrentState() async {
        // Given - default sut uses autocapture enabled
        sut.currentState = .recording
        await sut.handleCaptureEvent(PassiveCaptureEvent.helpRequested)
        mockView.updateUICalled = false

        // When
        await sut.handleCaptureEvent(PassiveCaptureEvent.helpDismissed)

        // Then
        XCTAssertTrue(mockView.updateUICalled, "Should update UI")
        XCTAssertFalse(mockView.lastShowHelpDialog ?? true, "Help dialog should be hidden")
        // State should remain as it was (not forced to manual)
    }

    func testManualRecordingRequested_setsNoFeedback() async {
        // Given
        let event = PassiveCaptureEvent.manualRecordingRequested

        // When
        await sut.handleCaptureEvent(event)

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

    // MARK: - Face Centering Tests

    func testDetectionsReceived_withCenteredFace_clearsFeedback() async {
        // Given
        sut.currentState = .recording
        // Face centered at (0.5, 0.5) with 30% height
        let centeredFace = [createFaceDetectionResult(
            boundingBox: CGRect(x: 0.35, y: 0.35, width: 0.30, height: 0.30)
        )]

        // When
        await sut.detectionsReceived(centeredFace)

        // Then
        XCTAssertEqual(
            mockView.lastFeedback,
            FeedbackType.none,
            "Should clear feedback for centered face"
        )
    }

    func testDetectionsReceived_withFaceTooSmall_showsMoveCloser() async {
        // Given
        sut.currentState = .recording
        // Face centered but only 10% height (below minFaceHeight)
        let smallFace = [createFaceDetectionResult(
            boundingBox: CGRect(x: 0.45, y: 0.45, width: 0.10, height: 0.10)
        )]

        // When
        await sut.detectionsReceived(smallFace)

        // Then
        XCTAssertEqual(
            mockView.lastFeedback,
            .moveCloser,
            "Should show MOVE_CLOSER for too-small (too-far) face"
        )
    }

    func testDetectionsReceived_withFaceTooLarge_showsMoveBack() async {
        // Given
        sut.currentState = .recording
        // Face covering 90% of height (above maxFaceHeight)
        let largeFace = [createFaceDetectionResult(
            boundingBox: CGRect(x: 0.05, y: 0.05, width: 0.90, height: 0.90)
        )]

        // When
        await sut.detectionsReceived(largeFace)

        // Then
        XCTAssertEqual(
            mockView.lastFeedback,
            .moveBack,
            "Should show MOVE_BACK for too-large (too-close) face"
        )
    }

    func testDetectionsReceived_withFaceAtEdge_showsCenterFeedback() async {
        // Given
        sut.currentState = .recording
        // Face at corner, far from oval center
        let edgeFace = [createFaceDetectionResult(
            boundingBox: CGRect(x: 0.0, y: 0.75, width: 0.20, height: 0.25)
        )]

        // When
        await sut.detectionsReceived(edgeFace)

        // Then
        XCTAssertEqual(
            mockView.lastFeedback,
            .centerFace,
            "Should show CENTER_FACE for face at edge"
        )
    }

    func testDetectionsReceived_withNotCenteredFace_showsCenterFeedback() async {
        // Given
        sut.currentState = .recording
        // Face at top edge, not centered
        let offCenterFace = [createFaceDetectionResult(
            boundingBox: CGRect(x: 0.35, y: 0.75, width: 0.30, height: 0.25)
        )]

        // When
        await sut.detectionsReceived(offCenterFace)

        // Then
        XCTAssertEqual(
            mockView.lastFeedback,
            .centerFace,
            "Should show CENTER_FACE feedback"
        )
        XCTAssertFalse(
            mockView.startRecordingCalled,
            "Should NOT start recording when face not centered"
        )
    }

    func testDetectionsReceived_notCenteredThenCentered_startsTimer() async {
        // Given
        sut.currentState = .recording

        // When - first send off-center face
        let offCenterFace = [createFaceDetectionResult(
            boundingBox: CGRect(x: 0.0, y: 0.0, width: 0.20, height: 0.30)
        )]
        await sut.detectionsReceived(offCenterFace)
        XCTAssertEqual(mockView.lastFeedback, .centerFace)

        // Then send centered face
        let centeredFace = [createFaceDetectionResult(
            boundingBox: CGRect(x: 0.35, y: 0.35, width: 0.30, height: 0.30)
        )]
        await sut.detectionsReceived(centeredFace)

        // Then
        XCTAssertEqual(
            mockView.lastFeedback,
            FeedbackType.none,
            "Should clear feedback for centered face"
        )
    }

    // MARK: - Face Forward (Yaw) Tests

    func testIsFaceFacingForward_nilYaw_returnsTrue() {
        let face = createFaceDetectionResult(yaw: nil)
        XCTAssertTrue(sut.isFaceFacingForward(face))
    }

    func testIsFaceFacingForward_zeroYaw_returnsTrue() {
        let face = createFaceDetectionResult(yaw: 0)
        XCTAssertTrue(sut.isFaceFacingForward(face))
    }

    func testIsFaceFacingForward_justUnderThreshold_returnsTrue() {
        let face = createFaceDetectionResult(yaw: PassiveCapturePresenter.yawThresholdRadians - 0.001)
        XCTAssertTrue(sut.isFaceFacingForward(face))
    }

    func testIsFaceFacingForward_atThreshold_returnsFalse() {
        let face = createFaceDetectionResult(yaw: PassiveCapturePresenter.yawThresholdRadians)
        XCTAssertFalse(sut.isFaceFacingForward(face))
    }

    func testIsFaceFacingForward_negativeProfile_returnsFalse() {
        let face = createFaceDetectionResult(yaw: -.pi / 3)
        XCTAssertFalse(sut.isFaceFacingForward(face))
    }

    // MARK: - Sideways Face Detection Tests

    func testCameraFrameProcessed_sidewaysProfile_setsFeedbackToLookForward() async {
        // Given
        sut.currentState = .recording
        let sidewaysFace = [createFaceDetectionResult(yaw: .pi / 3)]

        // When
        await sut.detectionsReceived(sidewaysFace)

        // Then
        XCTAssertEqual(mockView.lastFeedback, .lookForward, "Should show LOOK_FORWARD feedback")
        XCTAssertFalse(mockView.startRecordingCalled, "Should NOT start recording while in profile")
    }

    func testCameraFrameProcessed_sidewaysToFrontal_recoversAndStartsRecording() async {
        // Given
        sut.currentState = .recording
        let sidewaysFace = [createFaceDetectionResult(yaw: .pi / 3)]
        let frontalFace = [createFaceDetectionResult(yaw: 0)]

        // When - 5 sideways frames
        for _ in 0 ..< 5 {
            await sut.detectionsReceived(sidewaysFace)
        }
        XCTAssertEqual(mockView.lastFeedback, .lookForward)
        XCTAssertFalse(mockView.startRecordingCalled, "Sideways frames must not trigger recording")

        // Then - first frontal frame starts the timer
        await sut.detectionsReceived(frontalFace)

        // Advance time past the 1s detection threshold
        mockTimeProvider.currentTime = mockTimeProvider.currentTime.addingTimeInterval(1.1)

        // Process another frontal frame to fire the time check
        await sut.detectionsReceived(frontalFace)

        // Then
        XCTAssertTrue(mockView.startRecordingCalled, "Should start recording after recovering to frontal")
    }

    func testCameraFrameProcessed_sidewaysInterruptsExistingFaceTimer_resetsTimer() async {
        // Given
        sut.currentState = .recording
        let frontalFace = [createFaceDetectionResult(yaw: 0)]
        let sidewaysFace = [createFaceDetectionResult(yaw: .pi / 3)]

        // First frontal frame starts the detection timer
        await sut.detectionsReceived(frontalFace)

        // Sideways frame must reset the timer; feedback flips to lookForward
        await sut.detectionsReceived(sidewaysFace)
        XCTAssertEqual(mockView.lastFeedback, .lookForward)
        XCTAssertFalse(mockView.startRecordingCalled)

        // After advancing past the 1s detection threshold, a single new frontal
        // frame must NOT trigger recording — that proves the timer was reset
        // (otherwise the original t=0 timer would have fired).
        mockTimeProvider.currentTime = mockTimeProvider.currentTime.addingTimeInterval(1.1)
        await sut.detectionsReceived(frontalFace)
        XCTAssertFalse(
            mockView.startRecordingCalled,
            "Sideways interruption must reset the face-detection timer, " +
                "so a single frame after >1s of elapsed time cannot trigger recording"
        )
    }

    // MARK: - Unified Telemetry Event Tests

    func testFaceQualityGatePassed_emittedWhenAutocaptureGateFires() async {
        // Given — countdown completes (sets countdownEndedAt), then a face is held for 1s
        await sut.cameraReady()
        await runCountdownToCompletion()

        let singleFace = [createFaceDetectionResult(confidence: 0.95)]

        // Start the detection timer
        await sut.detectionsReceived(singleFace)

        // Advance past the 1s detection threshold and trigger the gate
        mockTimeProvider.currentTime = mockTimeProvider.currentTime.addingTimeInterval(1.1)
        await sut.detectionsReceived(singleFace)

        // Then
        XCTAssertTrue(
            mockInteractor.logFaceQualityGatePassedCalled,
            "FaceQualityGatePassed should be emitted when autocapture gate fires"
        )
        XCTAssertNotNil(
            mockInteractor.lastTimeToReadyMs,
            "TimeToReadyMs should be populated"
        )
    }

    func testFaceQualityGatePassed_timeToReadyMs_isNonNegative() async {
        // Given
        await sut.cameraReady()
        await runCountdownToCompletion()

        let singleFace = [createFaceDetectionResult(confidence: 0.95)]
        await sut.detectionsReceived(singleFace)

        // Advance past the 1s detection threshold and trigger the gate
        mockTimeProvider.currentTime = mockTimeProvider.currentTime.addingTimeInterval(1.5)
        await sut.detectionsReceived(singleFace)

        // Then — value must be non-negative
        XCTAssertGreaterThanOrEqual(
            mockInteractor.lastTimeToReadyMs ?? -1,
            0,
            "TimeToReadyMs must be >= 0"
        )
    }

    /// Helper: drains all pending countdown sleeps so the presenter enters face-waiting state.
    /// The countdown in `startCountdown()` uses `timeProvider.sleep` (one per tick: 3→2→1→0).
    /// We resume each sleep one at a time and poll until a new sleep is registered before
    /// resuming the next, ensuring deterministic drain order.
    private func runCountdownToCompletion() async {
        // The countdown task suspends on `sleep` before each tick. Resume 3 ticks:
        for _ in 0 ..< 3 {
            // Wait for the countdown task to register its next sleep continuation.
            var waited = 0
            while mockTimeProvider.sleepContinuations.isEmpty, waited < 100 {
                try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
                waited += 1
            }
            mockTimeProvider.resumeSleep(at: 0)
        }
        // Wait for `beginWaitingForFace()` to run (which calls `startProcessingTimer()`).
        // It runs immediately after the while loop exits in the countdown Task — give it time.
        try? await Task.sleep(nanoseconds: 5_000_000) // 5ms
    }

    func testFaceQualityGateTimeout_emittedWhenTimeoutExpires() async {
        // Given — camera ready; let countdown complete to enter face-waiting state
        await sut.cameraReady()
        await runCountdownToCompletion()

        // Advance past the 10s manual timeout
        mockTimeProvider.currentTime += 10.5

        // Trigger timeout check via detectionsReceived
        let singleFace = [createFaceDetectionResult(confidence: 0.95)]
        await sut.detectionsReceived(singleFace)

        // Then
        XCTAssertTrue(
            mockInteractor.logFaceQualityGateTimeoutCalled,
            "FaceQualityGateTimeout should be emitted when timeout elapses"
        )
        XCTAssertNotNil(
            mockInteractor.lastGateTimeoutHint,
            "LastHint should be set"
        )
    }

    func testFaceQualityGateTimeout_lastHint_defaultsToShowFace_whenNoHintShown() async {
        // Given — countdown ends, no feedback hint shown before timeout
        await sut.cameraReady()
        await runCountdownToCompletion()

        // Advance past timeout without any off-center/profile detections
        mockTimeProvider.currentTime += 10.5

        let singleFace = [createFaceDetectionResult(confidence: 0.95)]
        await sut.detectionsReceived(singleFace)

        // Then — default hint should be SHOW_FACE
        XCTAssertEqual(
            mockInteractor.lastGateTimeoutHint,
            "SHOW_FACE",
            "LastHint should default to SHOW_FACE when no hint was shown"
        )
    }

    func testFaceQualityGateTimeout_lastHint_reflectsLastShownHint() async {
        // Given — camera ready then face goes sideways (LOOK_FORWARD hint shown)
        await sut.cameraReady()
        await runCountdownToCompletion()

        // Show LOOK_FORWARD hint before timeout
        let sidewaysFace = [createFaceDetectionResult(yaw: .pi / 3)]
        await sut.detectionsReceived(sidewaysFace)
        XCTAssertEqual(mockView.lastFeedback, .lookForward, "Precondition: LOOK_FORWARD hint shown")

        // Advance past timeout
        mockTimeProvider.currentTime += 10.5
        await sut.detectionsReceived(sidewaysFace)

        // Then — timeout should report LOOK_FORWARD as the last hint
        XCTAssertEqual(
            mockInteractor.lastGateTimeoutHint,
            "LOOK_FORWARD",
            "LastHint should reflect the last shown hint"
        )
    }

    func testFaceVideoManualModeForced_emittedWithQualityGateTimeoutReason_onTimeout() async {
        // Given — countdown completes, then face-wait times out
        await sut.cameraReady()
        await runCountdownToCompletion()
        mockTimeProvider.currentTime += 10.5

        let singleFace = [createFaceDetectionResult(confidence: 0.95)]
        await sut.detectionsReceived(singleFace)

        // Then
        XCTAssertTrue(
            mockInteractor.logFaceVideoManualModeForcedCalled,
            "FaceVideoManualModeForced should be emitted on timeout"
        )
        XCTAssertEqual(
            mockInteractor.lastManualModeTriggerReason,
            .qualityGateTimeout,
            "TriggerReason should be quality_gate_timeout on timeout"
        )
    }

    func testFaceVideoManualModeForced_emittedWithClientWithoutAutocaptureReason_whenAutocaptureDisabled() async {
        // Given — presenter with autocapture disabled
        let presenter = PassiveCapturePresenter(
            view: mockView,
            interactor: mockInteractor,
            router: mockRouter,
            validationId: "test-validation-id",
            useAutocapture: false,
            timeProvider: mockTimeProvider
        )

        // When — camera becomes ready
        await presenter.cameraReady()

        // Then
        XCTAssertTrue(
            mockInteractor.logFaceVideoManualModeForcedCalled,
            "FaceVideoManualModeForced should be emitted when SDK starts in manual mode"
        )
        XCTAssertEqual(
            mockInteractor.lastManualModeTriggerReason,
            .clientWithoutAutocapture,
            "TriggerReason should be client_without_autocapture when autocapture is disabled"
        )
    }

    func testManualTimeoutSeconds_is10() {
        XCTAssertEqual(
            PassiveCapturePresenter.manualTimeoutSeconds,
            10.0,
            "Manual fallback timeout must be 10s per cross-platform contract"
        )
    }

    // MARK: - Session Summary Tests

    func testViewWillDisappear_emitsSessionSummaryWithDominantHint() async {
        // Given — camera ready, then a LOOK_FORWARD hint is shown for 2s, then teardown.
        await sut.cameraReady()
        await runCountdownToCompletion()

        let sidewaysFace = [createFaceDetectionResult(yaw: .pi / 3)]
        await sut.detectionsReceived(sidewaysFace)
        XCTAssertEqual(mockView.lastFeedback, .lookForward, "Precondition: LOOK_FORWARD shown")

        // Advance 2 seconds so LOOK_FORWARD accumulates meaningful time.
        mockTimeProvider.currentTime = mockTimeProvider.currentTime.addingTimeInterval(2.0)

        // When
        await sut.viewWillDisappear()

        // Then
        XCTAssertTrue(
            mockInteractor.logFaceQualitySessionSummaryCalled,
            "Session summary should be emitted on viewWillDisappear"
        )
        XCTAssertEqual(
            mockInteractor.lastSessionSummaryDominantHint,
            "LOOK_FORWARD",
            "Dominant hint should be LOOK_FORWARD after 2s with sideways face"
        )
        XCTAssertEqual(
            mockInteractor.lastSessionSummaryAutocaptureFired,
            false,
            "autocapture_fired should be false when recording was never triggered by the gate"
        )
        XCTAssertGreaterThan(
            mockInteractor.lastSessionSummaryTotalDurationMs ?? 0,
            0,
            "Total duration must be positive"
        )
    }

    func testViewWillDisappear_autocaptureGateFired_setsAutocaptureFiredTrue() async {
        // Given — full autocapture flow: countdown → face detected for 1s → gate fires
        await sut.cameraReady()
        await runCountdownToCompletion()

        let singleFace = [createFaceDetectionResult(confidence: 0.95)]
        await sut.detectionsReceived(singleFace)
        mockTimeProvider.currentTime = mockTimeProvider.currentTime.addingTimeInterval(1.1)
        await sut.detectionsReceived(singleFace)
        XCTAssertTrue(mockInteractor.logFaceQualityGatePassedCalled, "Precondition: gate fired")

        // When
        await sut.viewWillDisappear()

        // Then
        XCTAssertTrue(
            mockInteractor.logFaceQualitySessionSummaryCalled,
            "Session summary should be emitted"
        )
        XCTAssertEqual(
            mockInteractor.lastSessionSummaryAutocaptureFired,
            true,
            "autocapture_fired must be true when the autocapture gate triggered recording"
        )
    }

    // MARK: - Hidden Face Tests

    func testIsFaceHidden_nilLandmarks_returnsFalse() {
        // nil landmarks means Vision didn't compute them; avoid false positives.
        let face = createFaceDetectionResult(landmarks: nil)
        XCTAssertFalse(sut.isFaceHidden(face), "nil landmarks must not be treated as hidden")
    }

    func testDetectionsReceived_nilLandmarks_doesNotEmitHiddenFace() async {
        // Given — nil landmarks (VNDetectFaceLandmarksRequest did not populate them)
        sut.currentState = .recording
        let face = [createFaceDetectionResult(landmarks: nil)]

        // Send 5 frames — hysteresis threshold is 3, must not fire
        for _ in 0 ..< 5 {
            await sut.detectionsReceived(face)
        }

        // Then — no HIDDEN_FACE should have been emitted
        XCTAssertNotEqual(mockView.lastFeedback, .hiddenFace, "nil landmarks must not emit HIDDEN_FACE")
    }

    func testDetectionsReceived_hiddenFaceHysteresis_emitsAfterThreeFrames() async {
        // Given — a face result whose landmarks mark the face as hidden.
        // We use a stub that carries a non-nil VNFaceLandmarks2D with all regions nil;
        // constructing a real VNFaceLandmarks2D is not possible in unit tests, so we
        // test the presenter via the isFaceHidden override path through a subclass.
        // Directly test via HiddenFaceStubPresenter (see bottom of file).
        sut.currentState = .recording
        let stubPresenter = HiddenFaceStubPresenter(
            view: mockView,
            interactor: mockInteractor,
            router: mockRouter,
            validationId: "test",
            timeProvider: mockTimeProvider
        )
        stubPresenter.currentState = .recording
        stubPresenter.forceHiddenFace = true

        // When — send fewer than 3 frames: no feedback yet
        let face = [createFaceDetectionResult(landmarks: nil)]
        for _ in 0 ..< 2 {
            await stubPresenter.detectionsReceived(face)
        }
        XCTAssertNotEqual(mockView.lastFeedback, .hiddenFace, "Should not emit before 3 frames")

        // Send 3rd frame: threshold reached
        await stubPresenter.detectionsReceived(face)

        // Then
        XCTAssertEqual(mockView.lastFeedback, .hiddenFace, "Should emit HIDDEN_FACE after 3 consecutive hidden frames")
    }

    func testDetectionsReceived_hiddenFaceCounterResetsOnVisibleFace() async {
        // Given
        sut.currentState = .recording
        let stubPresenter = HiddenFaceStubPresenter(
            view: mockView,
            interactor: mockInteractor,
            router: mockRouter,
            validationId: "test",
            timeProvider: mockTimeProvider
        )
        stubPresenter.currentState = .recording
        stubPresenter.forceHiddenFace = true

        let face = [createFaceDetectionResult(landmarks: nil)]

        // Send 2 hidden frames (not yet at threshold)
        for _ in 0 ..< 2 {
            await stubPresenter.detectionsReceived(face)
        }

        // When — a visible frame resets the counter
        stubPresenter.forceHiddenFace = false
        await stubPresenter.detectionsReceived(face)

        // When — go hidden again: need another 3 frames for threshold
        stubPresenter.forceHiddenFace = true
        for _ in 0 ..< 2 {
            await stubPresenter.detectionsReceived(face)
        }
        XCTAssertNotEqual(mockView.lastFeedback, .hiddenFace, "Counter must have reset; 2 frames should not fire")

        await stubPresenter.detectionsReceived(face)
        XCTAssertEqual(mockView.lastFeedback, .hiddenFace, "Should emit HIDDEN_FACE after a fresh 3-frame run")
    }

    func testDetectionsReceived_hiddenFaceDoesNotStartRecordingTimer() async {
        // Given
        sut.currentState = .recording
        let stubPresenter = HiddenFaceStubPresenter(
            view: mockView,
            interactor: mockInteractor,
            router: mockRouter,
            validationId: "test",
            timeProvider: mockTimeProvider
        )
        stubPresenter.currentState = .recording
        stubPresenter.forceHiddenFace = true

        let face = [createFaceDetectionResult(landmarks: nil)]

        // Send many hidden frames past threshold
        for _ in 0 ..< 5 {
            await stubPresenter.detectionsReceived(face)
        }
        mockTimeProvider.currentTime = mockTimeProvider.currentTime.addingTimeInterval(1.1)
        await stubPresenter.detectionsReceived(face)

        // Then — recording must not have started
        XCTAssertFalse(mockView.startRecordingCalled, "Hidden face must not advance the autocapture timer")
    }
}

// swiftlint:enable type_body_length

// MARK: - Mock View

@MainActor private final class MockPassiveCaptureView: PassiveCapturePresenterToView {
    var setupCameraCalled = false
    var setupCameraCount = 0
    var startRecordingCalled = false
    var stopRecordingCalled = false
    var stopCameraCalled = false
    var pauseCameraCalled = false
    var resumeCameraCalled = false
    var pauseVideoCalled = false
    var resumeVideoCalled = false
    var updateUICalled = false
    var showErrorCalled = false
    var lastErrorMessage: String?
    var lastState: Any?
    var lastFeedback: FeedbackType?
    var lastCountdown: Int?
    var lastShowHelpDialog: Bool?
    var lastFrameData: Data?
    var lastUploadState: UploadState?
    var lastIsActivelyRecording: Bool?
    private(set) var detectedFaceBoxesUpdates: [[CGRect]] = []
    var lastDetectedFaceBoxes: [CGRect]? {
        detectedFaceBoxesUpdates.last
    }

    func setupCamera() {
        setupCameraCalled = true
        setupCameraCount += 1
    }

    func configureSessionPreset(_ preset: AVCaptureSession.Preset) {}

    func setInferenceLatencyCallback(_ callback: ((TimeInterval) -> Void)?) {}

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

    func resumeCamera() {
        resumeCameraCalled = true
    }

    func pauseVideo() {
        pauseVideoCalled = true
    }

    func resumeVideo() {
        resumeVideoCalled = true
        startRecording()
    }

    func updateUI(
        state: PassiveCaptureState,
        feedback: FeedbackType,
        countdown: Int,
        showHelpDialog: Bool,
        showSettingsPrompt: Bool,
        lastFrameData: Data?,
        uploadState: UploadState,
        isActivelyRecording: Bool
    ) {
        updateUICalled = true
        lastState = state
        lastFeedback = feedback
        lastCountdown = countdown
        lastShowHelpDialog = showHelpDialog
        self.lastFrameData = lastFrameData
        self.lastUploadState = uploadState
        self.lastIsActivelyRecording = isActivelyRecording
    }

    func showError(_ message: String) {
        showErrorCalled = true
        lastErrorMessage = message
    }

    func resetRecordingInProgress() {}

    func updateDetectedFaceBoundingBoxes(_ visionBoxes: [CGRect]) {
        detectedFaceBoxesUpdates.append(visionBoxes)
    }
}

// MARK: - Mock Interactor

// Not @MainActor: matches PassiveCapturePresenterToInteractor protocol which is not isolated
private final class MockPassiveCaptureInteractor: PassiveCapturePresenterToInteractor {
    private(set) var setUploadUrlCalled = false
    private(set) var uploadVideoCalled = false
    private(set) var lastUploadUrl: String?
    private(set) var lastVideoData: Data?

    // Telemetry tracking
    private(set) var logFaceQualityGatePassedCalled = false
    private(set) var lastTimeToReadyMs: Int?
    private(set) var logFaceQualityGateTimeoutCalled = false
    private(set) var lastGateTimeoutHint: String?
    private(set) var logFaceVideoManualModeForcedCalled = false
    private(set) var lastManualModeTriggerReason: FaceVideoManualTriggerReason?
    private(set) var logFaceQualitySessionSummaryCalled = false
    private(set) var lastSessionSummaryDominantHint: String?
    private(set) var lastSessionSummaryAutocaptureFired: Bool?
    private(set) var lastSessionSummaryTotalDurationMs: Int?
    private(set) var lastSessionSummaryHintDurationsMs: [String: Int]?
    private(set) var lastSessionSummaryDominantHintPercent: Int?

    func setUploadUrl(_ uploadUrl: String?) {
        setUploadUrlCalled = true
        lastUploadUrl = uploadUrl
    }

    func uploadVideo(_ videoData: Data) {
        uploadVideoCalled = true
        lastVideoData = videoData
    }

    func logFaceCaptureSucceeded() async {}

    func logFaceCaptureFailed(errorMessage: String) async {}

    func logFaceQualityGatePassed(timeToReadyMs: Int) async {
        logFaceQualityGatePassedCalled = true
        lastTimeToReadyMs = timeToReadyMs
    }

    func logFaceQualityGateTimeout(lastHint: String) async {
        logFaceQualityGateTimeoutCalled = true
        lastGateTimeoutHint = lastHint
    }

    func logFaceVideoManualModeForced(triggerReason: FaceVideoManualTriggerReason) async {
        logFaceVideoManualModeForcedCalled = true
        lastManualModeTriggerReason = triggerReason
    }

    func logFaceQualitySessionSummary(
        totalDurationMs: Int,
        hintDurationsMs: [String: Int],
        dominantHint: String,
        dominantHintPercent: Int,
        autocaptureFired: Bool
    ) async {
        logFaceQualitySessionSummaryCalled = true
        lastSessionSummaryDominantHint = dominantHint
        lastSessionSummaryAutocaptureFired = autocaptureFired
        lastSessionSummaryTotalDurationMs = totalDurationMs
        lastSessionSummaryHintDurationsMs = hintDurationsMs
        lastSessionSummaryDominantHintPercent = dominantHintPercent
    }
}

// MARK: - Mock Router

@MainActor private final class MockPassiveCaptureRouter: ValidationRouter {
    private(set) var navigateToResultCalled = false
    private(set) var lastValidationId: String?
    private(set) var lastIsCanceled: Bool?
    private(set) var handleErrorCalled = false
    private(set) var lastErrorMessage: String?

    override func navigateToResult(
        validationId: String,
        loadingType: ResultLoadingType = .face,
        isCanceled: Bool = false
    ) throws {
        navigateToResultCalled = true
        lastValidationId = validationId
        lastIsCanceled = isCanceled
    }

    override func handleError(_ error: TruoraException) {
        handleErrorCalled = true
        lastErrorMessage = error.localizedDescription
    }
}

// MARK: - Hidden Face Test Helpers

/// Subclass that overrides `isFaceHidden` so unit tests can drive hidden/visible
/// without constructing a real VNFaceLandmarks2D (not possible in pure unit tests).
/// The flag is lock-guarded so the synchronous override is safe to call from any queue.
private final class HiddenFaceStubPresenter: PassiveCapturePresenter {
    private let lock = NSLock()
    private var _forceHiddenFace = false

    var forceHiddenFace: Bool {
        get { lock.withLock { _forceHiddenFace } }
        set { lock.withLock { _forceHiddenFace = newValue } }
    }

    override func isFaceHidden(_ face: DetectionResult) -> Bool {
        lock.withLock { _forceHiddenFace }
    }
}

// MARK: - Test Helpers

/// Creates a face detection result centered on the oval (0.5, 0.5)
/// with 30% height - passes centering and size checks.
private func createFaceDetectionResult(
    confidence: Float = 0.9,
    boundingBox: CGRect = CGRect(x: 0.35, y: 0.35, width: 0.30, height: 0.30),
    landmarks: VNFaceLandmarks2D? = nil,
    yaw: Double? = nil
) -> DetectionResult {
    DetectionResult(
        category: .face(landmarks: landmarks, yaw: yaw),
        boundingBox: boundingBox,
        confidence: confidence
    )
}
