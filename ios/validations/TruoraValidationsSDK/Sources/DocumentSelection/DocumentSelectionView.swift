//
//  DocumentSelectionView.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 07/01/26.
//

import SwiftUI
import UIKit

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

    /// Tracks if country dropdown is expanded (for overlay rendering outside ScrollView)
    @Published var isCountryDropdownExpanded: Bool = false

    /// Tracks if document type dropdown is expanded
    @Published var isDocumentDropdownExpanded: Bool = false

    var presenter: DocumentSelectionViewToPresenter?
    private var didLoadOnce: Bool = false

    func onAppear() {
        guard !didLoadOnce else { return }
        didLoadOnce = true
        Task { await presenter?.viewDidLoad() }
    }

    var availableDocuments: [NativeDocumentType] {
        selectedCountry?.documentTypes ?? []
    }
}

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
}

// MARK: - Anchor Preference Key for Country Picker Position

private struct CountryPickerAnchorKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>?
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

// MARK: - Native SwiftUI View

struct DocumentSelectionView: View {
    @ObservedObject var viewModel: DocumentSelectionViewModel
    @ObservedObject private var theme: TruoraTheme

    init(viewModel: DocumentSelectionViewModel, config: UIConfig?) {
        self.viewModel = viewModel
        self.theme = TruoraTheme(config: config)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header
                TruoraHeaderView {
                    Task { await viewModel.presenter?.cancelTapped() }
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Title
                        Text(TruoraValidationsSDKStrings.documentSelectionTitle)
                            .font(theme.typography.titleLarge)
                            .foregroundColor(theme.colors.onSurface)
                            .padding(.top, 16)

                        // Country - either static display (locked) or picker
                        if viewModel.isCountryLocked {
                            // Static country display when pre-configured
                            if let country = viewModel.selectedCountry {
                                CountryStaticView(country: country)
                                    .environmentObject(theme)
                            }
                        } else {
                            // Country Picker
                            VStack(alignment: .leading, spacing: 8) {
                                Text(TruoraValidationsSDKStrings.documentSelectionCountryLabel)
                                    .font(theme.typography.bodyMedium)
                                    .foregroundColor(theme.colors.onSurface)

                                CountryPickerView(
                                    selectedCountry: viewModel.selectedCountry,
                                    isError: viewModel.isCountryError,
                                    isExpanded: Binding(
                                        get: { viewModel.isCountryDropdownExpanded },
                                        set: { viewModel.isCountryDropdownExpanded = $0
                                            if $0 { viewModel.isDocumentDropdownExpanded = false }
                                        }
                                    )
                                )
                                .environmentObject(theme)
                                .anchorPreference(
                                    key: CountryPickerAnchorKey.self,
                                    value: .bounds
                                ) { $0 }

                                if viewModel.isCountryError {
                                    Text(TruoraValidationsSDKStrings.documentSelectionCountryError)
                                        .font(theme.typography.bodySmall)
                                        .foregroundColor(theme.colors.error)
                                }
                            }
                        }

                        // Document Type Picker
                        if viewModel.selectedCountry != nil {
                            VStack(alignment: .leading, spacing: 8) {
                                // Use different label when country is locked
                                Text(
                                    viewModel.isCountryLocked
                                        ? TruoraValidationsSDKStrings
                                        .documentSelectionAcceptedDocuments
                                        : TruoraValidationsSDKStrings.documentSelectionDocumentLabel
                                )
                                .font(theme.typography.bodyMedium)
                                .foregroundColor(theme.colors.onSurface)

                                DocumentTypePickerView(
                                    documentTypes: viewModel.availableDocuments,
                                    selectedDocument: viewModel.selectedDocument,
                                    selectedCountry: viewModel.selectedCountry,
                                    isError: viewModel.isDocumentError,
                                    isExpanded: Binding(
                                        get: { viewModel.isDocumentDropdownExpanded },
                                        set: { viewModel.isDocumentDropdownExpanded = $0
                                            if $0 { viewModel.isCountryDropdownExpanded = false }
                                        }
                                    )
                                ) { document in
                                    Task { await viewModel.presenter?.documentSelected(document) }
                                }
                                .environmentObject(theme)

                                if viewModel.isDocumentError {
                                    Text(TruoraValidationsSDKStrings.documentSelectionDocumentError)
                                        .font(theme.typography.bodySmall)
                                        .foregroundColor(theme.colors.error)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }

                Spacer()

                // Footer with continue button
                TruoraFooterView(
                    securityTip: nil,
                    buttonText: TruoraValidationsSDKStrings.documentSelectionContinue,
                    isLoading: viewModel.isLoading
                ) {
                    Task { await viewModel.presenter?.continueTapped() }
                }
            }

            // Loading overlay
            if viewModel.isLoading {
                LoadingOverlayView(message: TruoraValidationsSDKStrings.documentSelectionLoading)
            }
        }
        .overlayPreferenceValue(CountryPickerAnchorKey.self) { anchor in
            GeometryReader { geometry in
                if let anchor, viewModel.isCountryDropdownExpanded {
                    let pickerFrame = geometry[anchor]

                    ZStack(alignment: .topLeading) {
                        // Dismiss tap area
                        Color.black.opacity(0.01)
                            .onTapGesture {
                                viewModel.isCountryDropdownExpanded = false
                                viewModel.isDocumentDropdownExpanded = false
                            }

                        // Dropdown positioned below the picker
                        CountryDropdownOverlay(
                            countries: viewModel.countries,
                            onSelect: { country in
                                Task { await viewModel.presenter?.countrySelected(country) }
                            },
                            isExpanded: $viewModel.isCountryDropdownExpanded
                        )
                        .environmentObject(theme)
                        .frame(width: pickerFrame.width)
                        .offset(x: pickerFrame.minX, y: pickerFrame.maxY + 4)
                    }
                }
            }
        }
        .environmentObject(theme)
        .navigationBarHidden(true)
        .alert(isPresented: $viewModel.showCameraPermissionAlert) {
            Alert(
                title: Text(
                    NSLocalizedString(
                        "camera_permission_denied_title", bundle: .module, comment: ""
                    )
                ),
                message: Text(
                    NSLocalizedString(
                        "camera_permission_denied_description", bundle: .module, comment: ""
                    )
                ),
                primaryButton: .default(
                    Text(NSLocalizedString("common_go_to_settings", bundle: .module, comment: ""))
                ) {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                },
                secondaryButton: .cancel(
                    Text(NSLocalizedString("common_cancel", bundle: .module, comment: ""))
                )
            )
        }
        .background(theme.colors.surface)
        .onAppear {
            viewModel.onAppear()
        }
    }
}

// MARK: - Country Static View (when locked/pre-configured)

private struct CountryStaticView: View {
    let country: NativeCountry

    @EnvironmentObject var theme: TruoraTheme

    var body: some View {
        HStack(spacing: 12) {
            SwiftUI.Image(country.rawValue, bundle: .module)
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 22)
            Text(country.displayName)
                .font(.system(size: 16))
                .foregroundColor(theme.colors.onSurface)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Country Picker Component

private struct CountryPickerView: View {
    let selectedCountry: NativeCountry?
    let isError: Bool
    @Binding var isExpanded: Bool

    @EnvironmentObject var theme: TruoraTheme

    private var showError: Bool {
        isError && selectedCountry == nil
    }

    var body: some View {
        Button(
            action: { isExpanded.toggle() },
            label: {
                HStack(spacing: 12) {
                    if let country = selectedCountry {
                        SwiftUI.Image(country.rawValue, bundle: .module)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 30, height: 22)
                        Text(country.displayName)
                            .font(.system(size: 16))
                            .foregroundColor(theme.colors.onSurface)
                    } else {
                        Text(TruoraValidationsSDKStrings.documentSelectionCountryPlaceholder)
                            .font(.system(size: 16))
                            .foregroundColor(theme.colors.tint00)
                    }
                    Spacer()
                    SwiftUI.Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.colors.onSurface)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .animation(.easeInOut(duration: 0.2), value: isExpanded)
                }
                .padding(.horizontal, 16)
                .frame(height: 56)
                .background(Color.white)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(showError ? theme.colors.error : theme.colors.tint00, lineWidth: 1)
                )
            }
        )
    }
}

// MARK: - Country Dropdown Overlay

private struct CountryDropdownOverlay: View {
    let countries: [NativeCountry]
    let onSelect: (NativeCountry) -> Void
    @Binding var isExpanded: Bool

    @EnvironmentObject var theme: TruoraTheme

    // Row dimensions - keep in sync with row layout below
    private let rowVerticalPadding: CGFloat = 12 // Applied to top and bottom
    private let rowContentHeight: CGFloat = 22 // Flag image height (tallest element)
    private var rowHeight: CGFloat {
        rowVerticalPadding * 2 + rowContentHeight
    }

    private let maxVisibleItems = 5

    private var dropdownHeight: CGFloat {
        let itemCount = min(countries.count, maxVisibleItems)
        return CGFloat(itemCount) * rowHeight
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(countries) { country in
                    Button(
                        action: {
                            onSelect(country)
                            isExpanded = false
                        },
                        label: {
                            HStack(spacing: 12) {
                                SwiftUI.Image(country.rawValue, bundle: .module)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 30, height: rowContentHeight)
                                Text(country.displayName)
                                    .font(.system(size: 16))
                                    .foregroundColor(theme.colors.onSurface)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, rowVerticalPadding)
                        }
                    )
                    if country.id != countries.last?.id {
                        Divider()
                    }
                }
            }
        }
        .frame(height: dropdownHeight)
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Document Type Picker Component

private struct DocumentTypePickerView: View {
    let documentTypes: [NativeDocumentType]
    let selectedDocument: NativeDocumentType?
    let selectedCountry: NativeCountry?
    let isError: Bool
    @Binding var isExpanded: Bool
    let onSelect: (NativeDocumentType) -> Void

    @EnvironmentObject var theme: TruoraTheme

    private var showError: Bool {
        isError && selectedDocument == nil
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(
                action: {
                    isExpanded.toggle()
                },
                label: {
                    HStack {
                        if let document = selectedDocument {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(document.label)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(theme.colors.onSurface)
                                if let country = selectedCountry,
                                   let description = document.descriptionText(for: country) {
                                    Text(description)
                                        .font(.system(size: 14))
                                        .foregroundColor(theme.colors.layoutGray500)
                                }
                            }
                        } else {
                            Text(TruoraValidationsSDKStrings.documentSelectionDocumentPlaceholder)
                                .font(.system(size: 16))
                                .foregroundColor(theme.colors.tint00)
                        }
                        Spacer()
                        SwiftUI.Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(theme.colors.onSurface)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                            .animation(.easeInOut(duration: 0.2), value: isExpanded)
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 56)
                    .background(Color.white)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(showError ? theme.colors.error : theme.colors.tint00, lineWidth: 1)
                    )
                }
            )

            if isExpanded {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(documentTypes) { document in
                            Button(
                                action: {
                                    onSelect(document)
                                    isExpanded = false
                                },
                                label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(document.label)
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundColor(theme.colors.onSurface)
                                            if let country = selectedCountry,
                                               let description = document.descriptionText(for: country) {
                                                Text(description)
                                                    .font(.system(size: 14))
                                                    .foregroundColor(theme.colors.layoutGray500)
                                            }
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                }
                            )
                            if document.id != documentTypes.last?.id {
                                Divider()
                            }
                        }
                    }
                }
                .background(Color.white)
                .cornerRadius(8)
                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                .frame(maxHeight: 280)
            }
        }
    }
}

// MARK: - Preview Helpers

@available(iOS 14.0, *)
private struct DocumentSelectionEmptyPreview: View {
    @StateObject private var viewModel: DocumentSelectionViewModel = {
        let vm = DocumentSelectionViewModel()
        vm.countries = [.co, .mx, .br]
        return vm
    }()

    var body: some View {
        DocumentSelectionView(viewModel: viewModel, config: nil)
    }
}

@available(iOS 14.0, *)
private struct DocumentSelectionCountrySelectedPreview: View {
    @StateObject private var viewModel: DocumentSelectionViewModel = {
        let vm = DocumentSelectionViewModel()
        vm.countries = [.co, .mx]
        vm.selectedCountry = .co
        return vm
    }()

    var body: some View {
        DocumentSelectionView(viewModel: viewModel, config: nil)
    }
}

@available(iOS 14.0, *)
private struct DocumentSelectionFullPreview: View {
    @StateObject private var viewModel: DocumentSelectionViewModel = {
        let vm = DocumentSelectionViewModel()
        vm.countries = [.co]
        vm.selectedCountry = .co
        vm.selectedDocument = .nationalId
        return vm
    }()

    var body: some View {
        DocumentSelectionView(viewModel: viewModel, config: nil)
    }
}

@available(iOS 14.0, *)
private struct DocumentSelectionLockedPreview: View {
    @StateObject private var viewModel: DocumentSelectionViewModel = {
        let vm = DocumentSelectionViewModel()
        vm.countries = [.co]
        vm.selectedCountry = .co
        vm.isCountryLocked = true
        return vm
    }()

    var body: some View {
        DocumentSelectionView(viewModel: viewModel, config: nil)
    }
}

@available(iOS 14.0, *)
private struct DocumentSelectionErrorsPreview: View {
    @StateObject private var viewModel: DocumentSelectionViewModel = {
        let vm = DocumentSelectionViewModel()
        vm.countries = [.co]
        vm.isCountryError = true
        vm.isDocumentError = true
        return vm
    }()

    var body: some View {
        DocumentSelectionView(viewModel: viewModel, config: nil)
    }
}

@available(iOS 14.0, *)
private struct DocumentSelectionLoadingPreview: View {
    @StateObject private var viewModel: DocumentSelectionViewModel = {
        let vm = DocumentSelectionViewModel()
        vm.countries = [.co]
        vm.selectedCountry = .co
        vm.selectedDocument = .nationalId
        vm.isLoading = true
        return vm
    }()

    var body: some View {
        DocumentSelectionView(viewModel: viewModel, config: nil)
    }
}

// MARK: - Previews

#Preview("Document Selection - Empty") {
    if #available(iOS 14.0, *) {
        DocumentSelectionEmptyPreview()
    }
}

#Preview("Document Selection - Country Selected") {
    if #available(iOS 14.0, *) {
        DocumentSelectionCountrySelectedPreview()
    }
}

#Preview("Document Selection - Full Selection") {
    if #available(iOS 14.0, *) {
        DocumentSelectionFullPreview()
    }
}

#Preview("Document Selection - Country Locked") {
    if #available(iOS 14.0, *) {
        DocumentSelectionLockedPreview()
    }
}

#Preview("Document Selection - Errors") {
    if #available(iOS 14.0, *) {
        DocumentSelectionErrorsPreview()
    }
}

#Preview("Document Selection - Loading") {
    if #available(iOS 14.0, *) {
        DocumentSelectionLoadingPreview()
    }
}
