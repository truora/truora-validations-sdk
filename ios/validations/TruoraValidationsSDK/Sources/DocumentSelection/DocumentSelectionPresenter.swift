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
    private var isSelectionFixed: Bool = false

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
            await logCameraPermissionGranted()
        case .notDetermined:
            cameraPermissionChecker.requestAccess { [weak self] granted in
                guard let self else { return }
                self.isCameraAuthorized = granted
                if granted {
                    Task {
                        await self.logCameraPermissionGranted()
                    }
                } else {
                    Task {
                        await self.handleCameraPermissionDenied()
                    }
                }
            }
        default:
            isCameraAuthorized = false
            await handleCameraPermissionDenied()
        }
    }

    private func logCameraPermissionGranted() async {
        guard let logger = try? TruoraLoggerImplementation.shared else {
            return
        }
        await logger.logCamera(
            eventName: "camera_permissions_granted",
            level: .info,
            errorMessage: nil,
            retention: .oneWeek,
            metadata: ["selected_camera": "back"]
        )
    }

    private func clearErrorsIfNeeded() async {
        await view?.setErrors(isCountryError: false, isDocumentError: false)
    }

    private func handleCameraPermissionDenied() async {
        debugLog("❌ DocumentSelectionPresenter: Camera permission denied")
        let error = TruoraException.sdk(SDKError(type: .cameraPermissionError))
        await router?.handleError(error)
    }
}

extension DocumentSelectionPresenter: DocumentSelectionViewToPresenter {
    func viewDidLoad() async {
        // Log view rendered
        await interactor?.logViewRendered()

        interactor?.fetchSupportedCountries()
        await preflightCameraPermission()
        await checkForPreConfiguredValues()
    }

    private func checkForPreConfiguredValues() async {
        let documentConfig = ValidationConfig.shared.documentConfig

        // Check for pre-configured country (allowedCountries has priority over country)
        if let countryCode = documentConfig.effectivePreselectedCountry,
           let country = NativeCountry(rawValue: countryCode.lowercased()) {
            selectedCountry = country
            await view?.setCountryLocked(true)
        }

        // Check for pre-configured document type (allowedDocumentTypes has priority over documentType)
        if let docType = documentConfig.effectivePreselectedDocumentType,
           let document = NativeDocumentType(rawValue: docType.lowercased()) {
            selectedDocument = document
            await view?.setDocumentLocked(true)
        } else {
            await checkForSingleAvailableDocumentType()
        }

        await view?.updateSelection(selectedCountry: selectedCountry, selectedDocument: selectedDocument)

        if let country = selectedCountry, let document = selectedDocument,
           isDocumentLocked() {
            isSelectionFixed = true
            await view?.setSelectionFixed(true)

            let url = await interactor?.fetchDocumentExample(
                country: country.rawValue,
                documentType: document.rawValue
            )
            if let url {
                await view?.setDocumentImageState(.loaded(url))
            } else {
                await view?.setDocumentImageState(.unavailable)
            }
        }
    }

    private func isDocumentLocked() -> Bool {
        let documentConfig = ValidationConfig.shared.documentConfig
        if documentConfig.effectivePreselectedDocumentType != nil {
            return true
        }
        guard let country = selectedCountry else { return false }
        let allowedDocTypes = documentConfig.allowedDocumentTypesList
        let available: [NativeDocumentType] = allowedDocTypes.isEmpty
            ? country.documentTypes
            : country.documentTypes.filter { docType in
                allowedDocTypes.contains { $0.lowercased() == docType.rawValue }
            }
        return available.count == 1
    }

    private func checkForSingleAvailableDocumentType() async {
        let documentConfig = ValidationConfig.shared.documentConfig
        let allowedDocTypes = documentConfig.allowedDocumentTypesList

        guard let country = selectedCountry else { return }

        let countryDocTypes = country.documentTypes
        let availableTypes: [NativeDocumentType] = if allowedDocTypes.isEmpty {
            countryDocTypes
        } else {
            countryDocTypes.filter { docType in
                allowedDocTypes.contains { $0.lowercased() == docType.rawValue }
            }
        }

        if availableTypes.count == 1, let singleType = availableTypes.first {
            selectedDocument = singleType
            await view?.setDocumentLocked(true)
        }
    }

    func countrySelected(_ country: NativeCountry) async {
        selectedCountry = country
        // Reset document selection on country change.
        selectedDocument = nil
        await view?.setDocumentLocked(false)

        // Check if there's only one available document type for the new country
        await checkForSingleAvailableDocumentType()

        await view?.updateSelection(selectedCountry: selectedCountry, selectedDocument: selectedDocument)
        await clearErrorsIfNeeded()
    }

    func documentSelected(_ document: NativeDocumentType) async {
        selectedDocument = document
        await view?.updateSelection(selectedCountry: selectedCountry, selectedDocument: selectedDocument)
        await clearErrorsIfNeeded()
    }

    func continueTapped() async {
        // Log continue button clicked
        await interactor?.logContinueButtonClicked(
            selectedCountry: selectedCountry,
            selectedDocument: selectedDocument
        )

        let isCountryValid = selectedCountry != nil
        let isDocumentValid = selectedDocument != nil
        await view?.setErrors(isCountryError: !isCountryValid, isDocumentError: !isDocumentValid)

        guard isCountryValid, isDocumentValid else {
            return
        }

        guard isCameraAuthorized else {
            await handleCameraPermissionDenied()
            return
        }

        guard let router, let selectedCountry, let selectedDocument else {
            return
        }

        let documentConfig = ValidationConfig.shared.documentConfig
            .setCountry(selectedCountry.rawValue)
            .applyRuntimeDocumentType(selectedDocument.rawValue)

        do {
            try ValidationConfig.shared.setValidation(.document(documentConfig))

            if isSelectionFixed {
                await navigateToCaptureDirect(router: router)
            } else {
                try await router.navigateToDocumentIntro()
            }
        } catch {
            // Routing error is not recoverable from here; surface actionable alert anyway.
            await view?.displayCameraPermissionAlert()
        }
    }

    private func navigateToCaptureDirect(router: ValidationRouter) async {
        guard let accountId = ValidationConfig.shared.accountId else {
            await router.handleError(.sdk(SDKError(type: .invalidConfiguration, details: "Missing account ID")))
            return
        }

        await view?.setLoading(true)
        do {
            guard let response = try await interactor?.createValidation(accountId: accountId) else {
                await view?.setLoading(false)
                return
            }

            let validationId = response.validationId
            ValidationConfig.shared.updateValidationId(validationId)

            guard let frontUploadUrl = response.instructions?.frontUrl,
                  !frontUploadUrl.isEmpty else {
                await view?.setLoading(false)
                await router.handleError(.sdk(SDKError(type: .internalError, details: "Missing front upload URL")))
                return
            }

            await view?.setLoading(false)
            try await router.navigateToDocumentCapture(
                validationId: validationId,
                frontUploadUrl: frontUploadUrl,
                reverseUploadUrl: response.instructions?.reverseUrl
            )
        } catch {
            await view?.setLoading(false)
            await router.handleError(
                error as? TruoraException
                    ?? .network(message: "Validation creation failed: \(error.localizedDescription)")
            )
        }
    }

    func cancelTapped() async {
        // Log cancel button clicked
        await interactor?.logCancelButtonClicked()

        await router?.handleCancellation(loadingType: .document)
    }
}

extension DocumentSelectionPresenter: DocumentSelectionInteractorToPresenter {
    func didLoadCountries(_ countries: [NativeCountry]) async {
        await view?.setCountries(countries)
    }
}
