//
//  DocumentSelectionProtocols.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 07/01/26.
//

import Foundation
import TruoraShared

// MARK: - Presenter to View

protocol DocumentSelectionPresenterToView: AnyObject {
    func setCountries(_ countries: [TruoraCountry])
    func updateSelection(selectedCountry: TruoraCountry?, selectedDocument: TruoraDocumentType?)
    func setErrors(isCountryError: Bool, isDocumentError: Bool)
    func setLoading(_ isLoading: Bool)
    func displayCameraPermissionAlert()
}

// MARK: - View to Presenter

protocol DocumentSelectionViewToPresenter: AnyObject {
    func viewDidLoad()
    func countrySelected(_ country: TruoraCountry)
    func documentSelected(_ document: TruoraDocumentType)
    func continueTapped()
    func cancelTapped()
}

// MARK: - Presenter to Interactor

protocol DocumentSelectionPresenterToInteractor: AnyObject {
    func fetchSupportedCountries()
}

// MARK: - Interactor to Presenter

protocol DocumentSelectionInteractorToPresenter: AnyObject {
    func didLoadCountries(_ countries: [TruoraCountry])
}
