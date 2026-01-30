//
//  DocumentSelectionProtocols.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 07/01/26.
//

import Foundation

// MARK: - Presenter to View

/// Protocol for updating the document selection view.
/// Implementations should ensure UI updates are performed on the main thread.
@MainActor protocol DocumentSelectionPresenterToView: AnyObject {
    func setCountries(_ countries: [NativeCountry])
    func updateSelection(selectedCountry: NativeCountry?, selectedDocument: NativeDocumentType?)
    func setCountryLocked(_ isLocked: Bool)
    func setErrors(isCountryError: Bool, isDocumentError: Bool)
    func setLoading(_ isLoading: Bool)
    func displayCameraPermissionAlert()
}

// MARK: - View to Presenter

protocol DocumentSelectionViewToPresenter: AnyObject {
    func viewDidLoad() async
    func countrySelected(_ country: NativeCountry) async
    func documentSelected(_ document: NativeDocumentType) async
    func continueTapped() async
    func cancelTapped() async
}

// MARK: - Presenter to Interactor

protocol DocumentSelectionPresenterToInteractor: AnyObject {
    func fetchSupportedCountries()
}

// MARK: - Interactor to Presenter

protocol DocumentSelectionInteractorToPresenter: AnyObject {
    func didLoadCountries(_ countries: [NativeCountry]) async
}
