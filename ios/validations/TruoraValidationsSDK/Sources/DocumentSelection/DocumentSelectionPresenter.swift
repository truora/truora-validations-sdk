//
//  DocumentSelectionPresenter.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 07/01/26.
//

import AVFoundation
import Foundation

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

    private var selectedCountry: NativeCountry?
    private var selectedDocument: NativeDocumentType?

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

    private func preflightCameraPermission() async {
        let status = cameraPermissionChecker.authorizationStatus()
        switch status {
        case .authorized:
            isCameraAuthorized = true
        case .notDetermined:
            cameraPermissionChecker.requestAccess { [weak self] granted in
                guard let self else { return }
                self.isCameraAuthorized = granted
                if !granted {
                    Task {
                        await self.view?.displayCameraPermissionAlert()
                    }
                }
            }
        default:
            isCameraAuthorized = false
            await view?.displayCameraPermissionAlert()
        }
    }

    private func clearErrorsIfNeeded() async {
        await view?.setErrors(isCountryError: false, isDocumentError: false)
    }
}

extension DocumentSelectionPresenter: DocumentSelectionViewToPresenter {
    func viewDidLoad() async {
        interactor?.fetchSupportedCountries()
        await preflightCameraPermission()
        await checkForPreConfiguredCountry()
    }

    private func checkForPreConfiguredCountry() async {
        let documentConfig = ValidationConfig.shared.documentConfig
        let preConfiguredCountry = documentConfig.country

        if !preConfiguredCountry.isEmpty,
           let country = NativeCountry(rawValue: preConfiguredCountry.lowercased()) {
            selectedCountry = country
            await view?.setCountryLocked(true)
            await view?.updateSelection(selectedCountry: country, selectedDocument: nil)
        }
    }

    func countrySelected(_ country: NativeCountry) async {
        selectedCountry = country
        // Reset document selection on country change.
        selectedDocument = nil
        await view?.updateSelection(selectedCountry: selectedCountry, selectedDocument: selectedDocument)
        await clearErrorsIfNeeded()
    }

    func documentSelected(_ document: NativeDocumentType) async {
        selectedDocument = document
        await view?.updateSelection(selectedCountry: selectedCountry, selectedDocument: selectedDocument)
        await clearErrorsIfNeeded()
    }

    func continueTapped() async {
        let isCountryValid = selectedCountry != nil
        let isDocumentValid = selectedDocument != nil
        await view?.setErrors(isCountryError: !isCountryValid, isDocumentError: !isDocumentValid)

        guard isCountryValid, isDocumentValid else {
            return
        }

        guard isCameraAuthorized else {
            await view?.displayCameraPermissionAlert()
            return
        }

        guard let router, let selectedCountry, let selectedDocument else {
            return
        }

        let documentConfig = Document()
            .setCountry(selectedCountry.rawValue)
            .setDocumentType(selectedDocument.rawValue)
        ValidationConfig.shared.setValidation(.document(documentConfig))

        do {
            try await router.navigateToDocumentIntro()
        } catch {
            // Routing error is not recoverable from here; surface actionable alert anyway.
            await view?.displayCameraPermissionAlert()
        }
    }

    func cancelTapped() async {
        await router?.handleCancellation()
    }
}

extension DocumentSelectionPresenter: DocumentSelectionInteractorToPresenter {
    func didLoadCountries(_ countries: [NativeCountry]) async {
        await view?.setCountries(countries)
    }
}
