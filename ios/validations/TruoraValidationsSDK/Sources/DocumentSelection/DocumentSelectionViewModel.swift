//
//  DocumentSelectionViewModel.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 07/01/26.
//

import Foundation

/// ViewModel for the document selection screen.
/// Uses @Published properties which automatically notify SwiftUI on the main thread.
@MainActor final class DocumentSelectionViewModel: ObservableObject {
    @Published var countries: [NativeCountry] = []
    @Published var selectedCountry: NativeCountry?
    @Published var selectedDocument: NativeDocumentType?

    @Published var isCountryError: Bool = false
    @Published var isDocumentError: Bool = false
    @Published var isLoading: Bool = false

    @Published var showCameraPermissionAlert: Bool = false

    /// When true, the country was pre-configured and cannot be changed by the user
    @Published var isCountryLocked: Bool = false

    /// When true, the document type was pre-configured and cannot be changed by the user
    @Published var isDocumentLocked: Bool = false

    /// Tracks if country dropdown is expanded (for overlay rendering outside ScrollView)
    @Published var isCountryDropdownExpanded: Bool = false

    /// Tracks if document type dropdown is expanded
    @Published var isDocumentDropdownExpanded: Bool = false

    /// True when both country and document are pre-configured
    @Published var isSelectionFixed: Bool = false

    /// State of the remote document example image for the unified screen
    @Published var documentImageState: DocumentImageState = .loading

    var presenter: DocumentSelectionViewToPresenter?
    private var didLoadOnce: Bool = false

    func onAppear() {
        guard !didLoadOnce else { return }
        didLoadOnce = true
        Task { await presenter?.viewDidLoad() }
    }

    var availableDocuments: [NativeDocumentType] {
        guard let country = selectedCountry else { return [] }

        let countryDocTypes = country.documentTypes
        let documentConfig = ValidationConfig.shared.documentConfig
        let allowedDocTypes = documentConfig.allowedDocumentTypesList

        if allowedDocTypes.isEmpty {
            return countryDocTypes
        }

        return countryDocTypes.filter { docType in
            allowedDocTypes.contains { $0.lowercased() == docType.rawValue }
        }
    }
}

// MARK: - DocumentSelectionPresenterToView

extension DocumentSelectionViewModel: DocumentSelectionPresenterToView {
    func setCountries(_ countries: [NativeCountry]) {
        self.countries = countries
    }

    func updateSelection(selectedCountry: NativeCountry?, selectedDocument: NativeDocumentType?) {
        self.selectedCountry = selectedCountry
        self.selectedDocument = selectedDocument
    }

    func setCountryLocked(_ isLocked: Bool) {
        self.isCountryLocked = isLocked
    }

    func setDocumentLocked(_ isLocked: Bool) {
        self.isDocumentLocked = isLocked
    }

    func setErrors(isCountryError: Bool, isDocumentError: Bool) {
        self.isCountryError = isCountryError
        self.isDocumentError = isDocumentError
    }

    func setLoading(_ isLoading: Bool) {
        self.isLoading = isLoading
    }

    func displayCameraPermissionAlert() {
        showCameraPermissionAlert = true
    }

    func setSelectionFixed(_ isFixed: Bool) {
        self.isSelectionFixed = isFixed
    }

    func setDocumentImageState(_ state: DocumentImageState) {
        self.documentImageState = state
    }
}
