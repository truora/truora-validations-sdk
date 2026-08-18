//
//  DocumentCaptureProtocols.swift
//  validations
//
//  Created by Truora on 26/12/25.
//

import AVFoundation
import Foundation
import TruoraCamera
import UIKit

/// Protocol for updating the document capture view.
/// Implementations should ensure UI updates are performed on the main thread.
@MainActor protocol DocumentCapturePresenterToView: AnyObject {
    func setupCamera()
    func configureSessionPreset(_ preset: AVCaptureSession.Preset)
    func setInferenceLatencyCallback(_ callback: ((TimeInterval) -> Void)?)
    func takePicture()
    func pauseVideo()
    func stopCamera()
    func pauseCamera()
    func resumeCamera()

    func updateComposeUI(
        side: DocumentCaptureSide,
        feedbackType: DocumentFeedbackType,
        showHelpDialog: Bool,
        showRotationAnimation: Bool,
        showLoadingScreen: Bool,
        uploadState: UploadState,
        frontPhotoData: Data?,
        frontPhotoStatus: CaptureStatus?,
        backPhotoData: Data?,
        backPhotoStatus: CaptureStatus?,
        clearFrontPhoto: Bool,
        clearBackPhoto: Bool,
        audioInstruction: TruoraAudioInstruction?
    )

    func showError(_ message: String)

    /// Resets the capture in progress flag, re-enabling the capture button
    func resetCaptureInProgress()
}

protocol DocumentCaptureViewToPresenter: AnyObject {
    func viewDidLoad() async
    func viewWillAppear() async
    func viewDidBecomeVisible() async
    func viewWillDisappear() async
    func appWillResignActive() async
    func appDidBecomeActive() async
    func cameraReady() async

    func photoCaptured(photoData: Data) async
    func detectionsReceived(_ results: [DetectionResult]) async
    func handleCaptureEvent(_ event: DocumentAutoCaptureEvent) async

    // Native UI actions
    func manualCaptureTapped() async
    func cancelTapped() async
    func retryTapped() async

    /// Called when autocapture becomes unavailable (e.g., ML model fails).
    /// Silently transitions to manual capture without user interaction.
    func switchToManualCapture() async

    /// Called when a camera error occurs (e.g., session failure).
    func cameraError(_ errorMessage: String) async

    /// Called when camera permission is denied. Returns error to caller immediately.
    func cameraPermissionDenied() async
}

protocol DocumentCapturePresenterToInteractor: AnyObject {
    func setUploadUrls(frontUploadUrl: String, reverseUploadUrl: String?)
    func uploadPhoto(side: DocumentCaptureSide, photoData: Data)
    func evaluateImage(
        side: DocumentCaptureSide,
        photoData: Data,
        country: String,
        documentType: String,
        validationId: String
    )
    func logDocCaptureSucceeded(side: DocumentCaptureSide, validationId: String) async
    func logDocCaptureFailed(side: DocumentCaptureSide, validationId: String, errorMessage: String) async
    func logDocFeedbackSucceeded(validationId: String, result: String, reason: String?) async
    func logDocFeedbackFailed(validationId: String, errorMessage: String) async
}

protocol DocumentCaptureInteractorToPresenter: AnyObject {
    func photoUploadCompleted(side: DocumentCaptureSide) async
    func photoUploadFailed(side: DocumentCaptureSide, error: TruoraException) async

    func imageEvaluationStarted(side: DocumentCaptureSide, previewData: Data) async
    func imageEvaluationSucceeded(side: DocumentCaptureSide, previewData: Data) async
    func imageEvaluationFailed(side: DocumentCaptureSide, previewData: Data, reason: String?) async
    func imageEvaluationErrored(side: DocumentCaptureSide, error: TruoraException) async
}
