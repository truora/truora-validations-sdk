//
//  DocumentSelectionProtocols.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 07/01/26.
//

import Foundation

// MARK: - Document Image State

/// Tracks the fetch-then-download lifecycle of a remote document example image.
enum DocumentImageState: Equatable {
    case loading
    case loaded(URL)
    case unavailable

    /// Stable key for SwiftUI's `.id()` to force view recreation on state change.
    var id: String {
        switch self {
        case .loading: "loading"
        case .loaded(let url): "loaded-\(url.absoluteString)"
        case .unavailable: "unavailable"
        }
    }
}

// MARK: - Presenter to View

/// Protocol for updating the document selection view.
/// Implementations should ensure UI updates are performed on the main thread.
@MainActor protocol DocumentSelectionPresenterToView: AnyObject {
    func setCountries(_ countries: [NativeCountry])
    func updateSelection(selectedCountry: NativeCountry?, selectedDocument: NativeDocumentType?)
    func setCountryLocked(_ isLocked: Bool)
    func setDocumentLocked(_ isLocked: Bool)
    func setErrors(isCountryError: Bool, isDocumentError: Bool)
    func setLoading(_ isLoading: Bool)
    func displayCameraPermissionAlert()
    func setSelectionFixed(_ isFixed: Bool)
    func setDocumentImageState(_ state: DocumentImageState)
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
    func logViewRendered() async
    func logContinueButtonClicked(selectedCountry: NativeCountry?, selectedDocument: NativeDocumentType?) async
    func logCancelButtonClicked() async
    func createValidation(accountId: String) async throws -> NativeValidationCreateResponse
    func fetchDocumentExample(country: String, documentType: String) async -> URL?
}

// MARK: - Interactor to Presenter

protocol DocumentSelectionInteractorToPresenter: AnyObject {
    func didLoadCountries(_ countries: [NativeCountry]) async
}
