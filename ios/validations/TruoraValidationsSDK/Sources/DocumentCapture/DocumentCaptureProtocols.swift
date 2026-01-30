//
//  DocumentCaptureProtocols.swift
//  validations
//
//  Created by Truora on 26/12/25.
//

import Foundation
import TruoraCamera
import UIKit

/// Protocol for updating the document capture view.
/// Implementations should ensure UI updates are performed on the main thread.
@MainActor protocol DocumentCapturePresenterToView: AnyObject {
    func setupCamera()
    func takePicture()
    func pauseVideo()
    func stopCamera()
    func pauseCamera()

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
    )

    func showError(_ message: String)
}

protocol DocumentCaptureViewToPresenter: AnyObject {
    func viewDidLoad() async
    func viewWillAppear() async
    func viewWillDisappear() async
    func cameraReady() async

    func photoCaptured(photoData: Data) async
    func detectionsReceived(_ results: [DetectionResult]) async
    func handleCaptureEvent(_ event: DocumentAutoCaptureEvent) async

    // Native UI actions
    func manualCaptureTapped() async
    func cancelTapped() async
    func retryTapped() async
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
}

protocol DocumentCaptureInteractorToPresenter: AnyObject {
    func photoUploadCompleted(side: DocumentCaptureSide) async
    func photoUploadFailed(side: DocumentCaptureSide, error: TruoraException) async

    func imageEvaluationStarted(side: DocumentCaptureSide, previewData: Data) async
    func imageEvaluationSucceeded(side: DocumentCaptureSide, previewData: Data) async
    func imageEvaluationFailed(side: DocumentCaptureSide, previewData: Data, reason: String?) async
    func imageEvaluationErrored(side: DocumentCaptureSide, error: TruoraException) async
}
