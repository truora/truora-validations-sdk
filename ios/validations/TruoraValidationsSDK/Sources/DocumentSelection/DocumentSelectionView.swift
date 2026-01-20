//
//  DocumentSelectionView.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 07/01/26.
//

import SwiftUI
import TruoraShared
import UIKit

final class DocumentSelectionViewModel: ObservableObject {
    @Published var countries: [TruoraCountry] = []
    @Published var selectedCountry: TruoraCountry?
    @Published var selectedDocument: TruoraDocumentType?

    @Published var isCountryError: Bool = false
    @Published var isDocumentError: Bool = false
    @Published var isLoading: Bool = false

    @Published var showCameraPermissionAlert: Bool = false

    var presenter: DocumentSelectionViewToPresenter?
    private var didLoadOnce: Bool = false

    func onAppear() {
        guard !didLoadOnce else { return }
        didLoadOnce = true
        presenter?.viewDidLoad()
    }
}

extension DocumentSelectionViewModel: DocumentSelectionPresenterToView {
    func setCountries(_ countries: [TruoraCountry]) {
        DispatchQueue.main.async {
            self.countries = countries
        }
    }

    func updateSelection(selectedCountry: TruoraCountry?, selectedDocument: TruoraDocumentType?) {
        DispatchQueue.main.async {
            self.selectedCountry = selectedCountry
            self.selectedDocument = selectedDocument
        }
    }

    func setErrors(isCountryError: Bool, isDocumentError: Bool) {
        DispatchQueue.main.async {
            self.isCountryError = isCountryError
            self.isDocumentError = isDocumentError
        }
    }

    func setLoading(_ isLoading: Bool) {
        DispatchQueue.main.async {
            self.isLoading = isLoading
        }
    }

    func displayCameraPermissionAlert() {
        DispatchQueue.main.async {
            self.showCameraPermissionAlert = true
        }
    }
}

// MARK: - Compose UI Integration

struct ComposeDocumentSelectionWrapper: UIViewControllerRepresentable {
    let countries: [TruoraCountry]
    let selectedCountry: TruoraCountry?
    let selectedDocument: TruoraDocumentType?
    let isCountryError: Bool
    let isDocumentError: Bool
    let isLoading: Bool

    let onCountrySelected: (TruoraCountry) -> Void
    let onDocumentSelected: (TruoraDocumentType) -> Void
    let onContinue: () -> Void
    let onCancel: () -> Void

    func makeUIViewController(context _: Context) -> UIViewController {
        TruoraUIExportsKt.createDocumentSelectionViewController(
            countryEnums: countries,
            selectedCountry: selectedCountry,
            selectedDocument: selectedDocument,
            isCountryError: isCountryError,
            isDocumentError: isDocumentError,
            isLoading: isLoading,
            onCountrySelected: onCountrySelected,
            onDocumentSelected: onDocumentSelected,
            onContinue: onContinue,
            onCancel: onCancel
        )
    }

    func updateUIViewController(_: UIViewController, context _: Context) {}
}

struct DocumentSelectionView: View {
    @ObservedObject var viewModel: DocumentSelectionViewModel

    private var composeKey: String {
        let countryIds = viewModel.countries.map(\.id).joined(separator: ",")
        return [
            countryIds,
            viewModel.selectedCountry?.id ?? "nil",
            viewModel.selectedDocument?.value ?? "nil",
            String(viewModel.isCountryError),
            String(viewModel.isDocumentError),
            String(viewModel.isLoading)
        ].joined(separator: "|")
    }

    var body: some View {
        ComposeDocumentSelectionWrapper(
            countries: viewModel.countries,
            selectedCountry: viewModel.selectedCountry,
            selectedDocument: viewModel.selectedDocument,
            isCountryError: viewModel.isCountryError,
            isDocumentError: viewModel.isDocumentError,
            isLoading: viewModel.isLoading,
            onCountrySelected: { country in
                viewModel.presenter?.countrySelected(country)
            },
            onDocumentSelected: { documentType in
                viewModel.presenter?.documentSelected(documentType)
            },
            onContinue: {
                viewModel.presenter?.continueTapped()
            },
            onCancel: {
                viewModel.presenter?.cancelTapped()
            }
        )
        .id(composeKey)
        .edgesIgnoringSafeArea(.all)
        .navigationBarHidden(true)
        .alert(isPresented: $viewModel.showCameraPermissionAlert) {
            Alert(
                title: Text("Camera access required"),
                message: Text("Please allow camera access to continue with document validation."),
                primaryButton: .default(Text("Go to Settings")) {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                },
                secondaryButton: .cancel(Text("Cancel"))
            )
        }
        .onAppear {
            viewModel.onAppear()
        }
    }
}
