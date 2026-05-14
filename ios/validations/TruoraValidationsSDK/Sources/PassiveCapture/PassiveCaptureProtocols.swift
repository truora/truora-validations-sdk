//
//  PassiveCaptureProtocols.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 30/10/25.
//

import AVFoundation
import Foundation
import TruoraCamera
import UIKit

/// Protocol for updating the passive capture view.
/// Implementations should ensure UI updates are performed on the main thread.
@MainActor protocol PassiveCapturePresenterToView: AnyObject {
    func setupCamera()
    func configureSessionPreset(_ preset: AVCaptureSession.Preset)
    func setInferenceLatencyCallback(_ callback: ((TimeInterval) -> Void)?)
    func startRecording()
    func stopRecording()
    func stopCamera()
    func pauseCamera()
    func resumeCamera()
    func pauseVideo()
    func resumeVideo()
    func updateUI(
        state: PassiveCaptureState,
        feedback: FeedbackType,
        countdown: Int,
        showHelpDialog: Bool,
        showSettingsPrompt: Bool,
        lastFrameData: Data?,
        uploadState: UploadState
    )
    func showError(_ message: String)

    /// Resets the recording in progress flag, re-enabling the record button
    func resetRecordingInProgress()

    /// Publishes the list of face bounding boxes in Vision-normalized space
    /// (bottom-left origin) for the overlay to render per-face ovals.
    /// Pass an empty array to clear the overlay.
    func updateDetectedFaceBoundingBoxes(_ visionBoxes: [CGRect])
}

protocol PassiveCaptureViewToPresenter: AnyObject {
    func viewDidLoad() async
    func viewWillAppear() async
    func viewWillDisappear() async
    func appWillResignActive() async
    func appDidBecomeActive() async
    func cameraReady() async
    func cameraPermissionDenied() async
    func videoRecordingCompleted(videoData: Data) async
    func lastFrameCaptured(frameData: Data) async
    func detectionsReceived(_ results: [DetectionResult]) async
    func handleCaptureEvent(_ event: PassiveCaptureEvent) async
    func cameraError(_ errorMessage: String) async
}

protocol PassiveCapturePresenterToInteractor: AnyObject {
    func setUploadUrl(_ uploadUrl: String?)
    func uploadVideo(_ videoData: Data)
    func logFaceCaptureSucceeded() async
    func logFaceCaptureFailed(errorMessage: String) async
}

protocol PassiveCaptureInteractorToPresenter: AnyObject {
    func videoUploadCompleted(validationId: String) async
    func videoUploadFailed(_ error: TruoraException) async
}
