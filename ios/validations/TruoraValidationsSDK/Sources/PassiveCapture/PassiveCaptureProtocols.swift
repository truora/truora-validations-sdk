//
//  PassiveCaptureProtocols.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 30/10/25.
//

import Foundation
import TruoraCamera
import TruoraShared
import UIKit

protocol PassiveCapturePresenterToView: AnyObject {
    func setupCamera()
    func startRecording()
    func stopRecording()
    func stopCamera()
    func pauseCamera()
    func pauseVideo()
    func resumeVideo()
    func updateComposeUI(
        state: PassiveCaptureState,
        feedback: FeedbackType,
        countdown: Int32,
        showHelpDialog: Bool,
        showSettingsPrompt: Bool,
        lastFrameData: Data?,
        uploadState: UploadState
    )
    func showError(_ message: String)
}

protocol PassiveCaptureViewToPresenter: AnyObject {
    func viewDidLoad()
    func viewWillAppear()
    func viewWillDisappear()
    func cameraReady()
    func cameraPermissionDenied()
    func videoRecordingCompleted(videoData: Data)
    func lastFrameCaptured(frameData: Data)
    func detectionsReceived(_ results: [DetectionResult])
    func handleCaptureEvent(_ event: PassiveCaptureEvent)
}

protocol PassiveCapturePresenterToInteractor: AnyObject {
    func setUploadUrl(_ uploadUrl: String?)
    func uploadVideo(_ videoData: Data)
}

protocol PassiveCaptureInteractorToPresenter: AnyObject {
    func videoUploadCompleted(validationId: String)
    func videoUploadFailed(_ error: ValidationError)
}
