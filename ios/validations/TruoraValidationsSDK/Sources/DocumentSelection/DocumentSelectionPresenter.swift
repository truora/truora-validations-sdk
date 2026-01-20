//
//  DocumentSelectionPresenter.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 07/01/26.
//

import AVFoundation
import Foundation
import TruoraShared

protocol CameraPermissionChecking {
    func authorizationStatus() -> AVAuthorizationStatus
    func requestAccess(completion: @escaping (Bool) -> Void)
}

struct DefaultCameraPermissionChecker: CameraPermissionChecking {
    func authorizationStatus() -> AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .video)
    }

    func requestAccess(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video, completionHandler: completion)
    }
}

final class DocumentSelectionPresenter {
    weak var view: DocumentSelectionPresenterToView?
    var interactor: DocumentSelectionPresenterToInteractor?
    weak var router: ValidationRouter?

    private var selectedCountry: TruoraCountry?
    private var selectedDocument: TruoraDocumentType?

    private var isCameraAuthorized: Bool = false
    private let cameraPermissionChecker: CameraPermissionChecking

    init(
        view: DocumentSelectionPresenterToView,
        interactor: DocumentSelectionPresenterToInteractor?,
        router: ValidationRouter,
        cameraPermissionChecker: CameraPermissionChecking = DefaultCameraPermissionChecker()
    ) {
        self.view = view
        self.interactor = interactor
        self.router = router
        self.cameraPermissionChecker = cameraPermissionChecker
    }

    private func preflightCameraPermission() {
        let status = cameraPermissionChecker.authorizationStatus()
        switch status {
        case .authorized:
            isCameraAuthorized = true
        case .notDetermined:
            cameraPermissionChecker.requestAccess { [weak self] granted in
                guard let self else { return }
                self.isCameraAuthorized = granted
                if !granted {
                    self.view?.displayCameraPermissionAlert()
                }
            }
        default:
            isCameraAuthorized = false
            view?.displayCameraPermissionAlert()
        }
    }

    private func clearErrorsIfNeeded() {
        view?.setErrors(isCountryError: false, isDocumentError: false)
    }
}

extension DocumentSelectionPresenter: DocumentSelectionViewToPresenter {
    func viewDidLoad() {
        interactor?.fetchSupportedCountries()
        preflightCameraPermission()
    }

    func countrySelected(_ country: TruoraCountry) {
        selectedCountry = country
        // Reset document selection on country change (KMP derives valid docs per country).
        selectedDocument = nil
        view?.updateSelection(selectedCountry: selectedCountry, selectedDocument: selectedDocument)
        clearErrorsIfNeeded()
    }

    func documentSelected(_ document: TruoraDocumentType) {
        selectedDocument = document
        view?.updateSelection(selectedCountry: selectedCountry, selectedDocument: selectedDocument)
        clearErrorsIfNeeded()
    }

    func continueTapped() {
        let isCountryValid = selectedCountry != nil
        let isDocumentValid = selectedDocument != nil
        view?.setErrors(isCountryError: !isCountryValid, isDocumentError: !isDocumentValid)

        guard isCountryValid, isDocumentValid else {
            return
        }

        guard isCameraAuthorized else {
            view?.displayCameraPermissionAlert()
            return
        }

        guard let router, let selectedCountry, let selectedDocument else {
            return
        }

        let documentConfig = Document()
            .setCountry(selectedCountry.id)
            .setDocumentType(selectedDocument.value)
        ValidationConfig.shared.setValidation(.document(documentConfig))

        do {
            try router.navigateToDocumentIntro()
        } catch {
            // Routing error is not recoverable from here; surface actionable alert anyway.
            view?.displayCameraPermissionAlert()
        }
    }

    func cancelTapped() {
        router?.handleCancellation()
    }
}

extension DocumentSelectionPresenter: DocumentSelectionInteractorToPresenter {
    func didLoadCountries(_ countries: [TruoraCountry]) {
        view?.setCountries(countries)
    }
}
