//
//  DocumentCaptureProtocols.swift
//  validations
//
//  Created by Truora on 26/12/25.
//

import Foundation
import TruoraCamera
import TruoraShared
import UIKit

protocol DocumentCapturePresenterToView: AnyObject {
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
        backPhotoStatus: CaptureStatus?
    )

    func showError(_ message: String)
}

protocol DocumentCaptureViewToPresenter: AnyObject {
    func viewDidLoad()
    func viewWillAppear()
    func viewWillDisappear()
    func cameraReady()

    func photoCaptured(photoData: Data)
    func detectionsReceived(_ results: [DetectionResult])
    func handleCaptureEvent(_ event: DocumentAutoCaptureEvent)
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
    func photoUploadCompleted(side: DocumentCaptureSide)
    func photoUploadFailed(side: DocumentCaptureSide, error: ValidationError)

    func imageEvaluationStarted(side: DocumentCaptureSide, previewData: Data)
    func imageEvaluationSucceeded(side: DocumentCaptureSide, previewData: Data)
    func imageEvaluationFailed(side: DocumentCaptureSide, previewData: Data, reason: String?)
    func imageEvaluationErrored(side: DocumentCaptureSide, error: ValidationError)
}
