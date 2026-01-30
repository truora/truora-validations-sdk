//
//  PassiveCaptureProtocols.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 30/10/25.
//

import Foundation
import TruoraCamera
import UIKit

/// Protocol for updating the passive capture view.
/// Implementations should ensure UI updates are performed on the main thread.
@MainActor protocol PassiveCapturePresenterToView: AnyObject {
    func setupCamera()
    func startRecording()
    func stopRecording()
    func stopCamera()
    func pauseCamera()
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
}

protocol PassiveCaptureViewToPresenter: AnyObject {
    func viewDidLoad() async
    func viewWillAppear() async
    func viewWillDisappear() async
    func cameraReady() async
    func cameraPermissionDenied() async
    func videoRecordingCompleted(videoData: Data) async
    func lastFrameCaptured(frameData: Data) async
    func detectionsReceived(_ results: [DetectionResult]) async
    func handleCaptureEvent(_ event: PassiveCaptureEvent) async
}

protocol PassiveCapturePresenterToInteractor: AnyObject {
    func setUploadUrl(_ uploadUrl: String?)
    func uploadVideo(_ videoData: Data)
}

protocol PassiveCaptureInteractorToPresenter: AnyObject {
    func videoUploadCompleted(validationId: String) async
    func videoUploadFailed(_ error: TruoraException) async
}
