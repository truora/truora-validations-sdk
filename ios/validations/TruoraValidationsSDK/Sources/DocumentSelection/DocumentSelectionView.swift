//
//  DocumentSelectionView.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 07/01/26.
//

import SwiftUI
import UIKit

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

    private var viewTitle: String {
        if viewModel.isSelectionFixed {
            return fixedTitle
        }
        if viewModel.isCountryLocked, viewModel.isDocumentLocked {
            return TruoraLocalization.string(forKey: LocalizationKeys.documentSelectionLockedTitle)
        }
        return TruoraLocalization.string(forKey: LocalizationKeys.documentSelectionTitle)
    }

    private var fixedTitle: String {
        if viewModel.selectedCountry == .co, viewModel.selectedDocument == .nationalId {
            return TruoraLocalization.string(forKey: LocalizationKeys.documentSelectionLockedTitleCoNationalId)
        }
        return TruoraLocalization.string(forKey: LocalizationKeys.documentSelectionLockedTitle)
    }

    private var fixedScanButtonText: String {
        if viewModel.selectedCountry == .co, viewModel.selectedDocument == .nationalId {
            return TruoraLocalization.string(forKey: LocalizationKeys.documentIntroStartCaptureCoNationalId)
        }
        return TruoraLocalization.string(forKey: LocalizationKeys.documentIntroStartCapture)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header
                TruoraHeaderView {
                    Task { await viewModel.presenter?.cancelTapped() }
                }

                if viewModel.isSelectionFixed {
                    DocumentUnifiedContentView(
                        imageState: viewModel.documentImageState,
                        title: viewTitle
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            // Title
                            Text(viewTitle)
                                .font(theme.typography.titleLarge)
                                .foregroundColor(theme.colors.onSurface)
                                .padding(.top, 16)

                            // Country - either static display (locked) or picker
                            if viewModel.isCountryLocked {
                                // Static country display when pre-configured
                                if let country = viewModel.selectedCountry {
                                    CountryStaticView(country: country)
                                }
                            } else {
                                // Country Picker
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(TruoraLocalization.string(
                                        forKey: LocalizationKeys.documentSelectionCountryLabel
                                    ))
                                    .font(theme.typography.bodyMedium)
                                    .foregroundColor(theme.colors.onSurface)

                                    CountryPickerView(
                                        selectedCountry: viewModel.selectedCountry,
                                        isError: viewModel.isCountryError,
                                        isExpanded: Binding(
                                            get: { viewModel.isCountryDropdownExpanded },
                                            set: { viewModel.isCountryDropdownExpanded = $0
                                                if $0 {
                                                    viewModel.isDocumentDropdownExpanded = false
                                                }
                                            }
                                        )
                                    )
                                    .anchorPreference(
                                        key: CountryPickerAnchorKey.self,
                                        value: .bounds
                                    ) { $0 }

                                    if viewModel.isCountryError {
                                        Text(
                                            TruoraLocalization.string(
                                                forKey: LocalizationKeys.documentSelectionCountryError
                                            )
                                        )
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
                                            ? TruoraLocalization.string(
                                                forKey: LocalizationKeys.documentSelectionAcceptedDocuments
                                            )
                                            : TruoraLocalization.string(
                                                forKey: LocalizationKeys.documentSelectionDocumentLabel
                                            )
                                    )
                                    .font(theme.typography.bodyMedium)
                                    .foregroundColor(theme.colors.onSurface)

                                    if viewModel.isDocumentLocked,
                                       let country = viewModel.selectedCountry,
                                       let docType = viewModel.selectedDocument {
                                        DocumentTypeStaticView(
                                            country: country,
                                            document: docType
                                        )
                                    } else {
                                        DocumentTypePickerView(
                                            documentTypes: viewModel.availableDocuments,
                                            selectedDocument: viewModel.selectedDocument,
                                            selectedCountry: viewModel.selectedCountry,
                                            isError: viewModel.isDocumentError,
                                            isExpanded: Binding(
                                                get: { viewModel.isDocumentDropdownExpanded },
                                                set: { viewModel.isDocumentDropdownExpanded = $0
                                                    if $0 {
                                                        viewModel.isCountryDropdownExpanded = false
                                                    }
                                                }
                                            )
                                        ) { document in
                                            Task { await viewModel.presenter?.documentSelected(document) }
                                        }
                                    }

                                    if viewModel.isDocumentError {
                                        Text(
                                            TruoraLocalization.string(
                                                forKey: LocalizationKeys.documentSelectionDocumentError
                                            )
                                        )
                                        .font(theme.typography.bodySmall)
                                        .foregroundColor(theme.colors.error)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    Spacer()
                }

                // Footer with continue button
                TruoraFooterView(
                    securityTip: viewModel.isSelectionFixed
                        ? TruoraLocalization.string(forKey: LocalizationKeys.documentIntroSecurityTip)
                        : nil,
                    buttonText: viewModel.isSelectionFixed
                        ? fixedScanButtonText
                        : TruoraLocalization.string(forKey: LocalizationKeys.documentSelectionContinue),
                    isLoading: viewModel.isLoading
                ) {
                    Task { await viewModel.presenter?.continueTapped() }
                }

                if viewModel.isSelectionFixed {
                    HStack {
                        Spacer()
                        TruoraValidationsSDKAsset.byTruora.swiftUIImage
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 38, height: 24)
                            .foregroundColor(theme.colors.layoutTint50)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
            }

            // Loading overlay
            if viewModel.isLoading {
                LoadingOverlayView(
                    message: TruoraLocalization.string(forKey: LocalizationKeys.documentSelectionLoading)
                )
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
                    TruoraLocalization.string(forKey: LocalizationKeys.cameraPermissionDeniedTitle)
                ),
                message: Text(
                    TruoraLocalization.string(forKey: LocalizationKeys.cameraPermissionDeniedDescription)
                ),
                primaryButton: .default(
                    Text(TruoraLocalization.string(forKey: LocalizationKeys.commonGoToSettings))
                ) {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                },
                secondaryButton: .cancel(
                    Text(TruoraLocalization.string(forKey: LocalizationKeys.commonCancel))
                )
            )
        }
        .background(theme.colors.surface.extendingIntoSafeArea())
        .onAppear {
            viewModel.onAppear()
        }
    }
}

// MARK: - Document Unified Content View (single-document fixed flow)

private struct DocumentUnifiedContentView: View {
    let imageState: DocumentImageState
    let title: String

    @EnvironmentObject var theme: TruoraTheme

    var body: some View {
        GeometryReader { geometry in
            let isPhone = geometry.size.width < 600
            let maxImageHeight: CGFloat = isPhone
                ? geometry.size.height * 0.5
                : min(850, geometry.size.height * 0.65)

            VStack(spacing: 0) {
                if case .unavailable = imageState {
                    TruoraValidationsSDKAsset.documentIntro.swiftUIImage
                        .resizable()
                        .scaledToFill()
                        .frame(maxHeight: maxImageHeight, alignment: .top)
                        .frame(maxWidth: isPhone ? geometry.size.width * 0.9 : 1024 * 0.9)
                        .clipped()
                        .fadingEdge(
                            brush: Gradient(colors: [.clear, theme.colors.surface]),
                            height: 80
                        )
                } else {
                    DocumentExampleImage(state: imageState, isPhone: isPhone)
                        .frame(maxHeight: maxImageHeight)
                        .frame(maxWidth: isPhone ? .infinity : 1024)
                        .clipped()
                        .id(imageState.id)
                }

                VStack(alignment: .leading, spacing: 16) {
                    Text(title)
                        .font(theme.typography.titleLarge)
                        .foregroundColor(theme.colors.onSurface)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(TruoraLocalization.string(forKey: LocalizationKeys.documentFixedSubtitle))
                            .font(theme.typography.titleSmall)
                            .kerning(0.16)
                            .foregroundColor(theme.colors.onSurface)

                        DocumentSuggestionRow(
                            icon: "person.text.rectangle",
                            text: TruoraLocalization.string(forKey: LocalizationKeys.documentFirstSuggestion)
                        )

                        DocumentSuggestionRow(
                            icon: "camera",
                            text: TruoraLocalization.string(forKey: LocalizationKeys.documentSecondSuggestion)
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 16)

                Spacer()
            }
        }
    }
}

private struct DocumentSuggestionRow: View {
    let icon: String
    let text: String

    @EnvironmentObject var theme: TruoraTheme

    var body: some View {
        HStack(spacing: 8) {
            SwiftUI.Image(systemName: icon)
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .foregroundColor(theme.colors.primary)
            Text(text)
                .font(theme.typography.bodyMedium)
                .foregroundColor(theme.colors.onSurface)
        }
    }
}

// MARK: - Document Example Image (unified screen)

private struct DocumentExampleImage: View {
    let state: DocumentImageState
    let isPhone: Bool
    @EnvironmentObject var theme: TruoraTheme
    @State private var loadedImage: UIImage?
    @State private var downloadFailed = false

    private var cardMaxWidth: CGFloat {
        isPhone ? 240 : 400
    }

    private var cardMaxHeight: CGFloat {
        isPhone ? 200 : 320
    }

    var body: some View {
        Group {
            if let loadedImage {
                SwiftUI.Image(uiImage: loadedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: cardMaxWidth, maxHeight: cardMaxHeight)
                    .cornerRadius(6)
                    .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if downloadFailed {
                TruoraValidationsSDKAsset.documentIntro.swiftUIImage
                    .resizable()
                    .scaledToFill()
            } else {
                CircularSpinnerView(color: theme.colors.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear { download() }
    }

    private func download() {
        guard case .loaded(let url) = state, loadedImage == nil else { return }
        Task {
            if let data = try? await fetchData(from: url),
               let image = UIImage(data: data) {
                await MainActor.run { loadedImage = image }
            } else {
                await MainActor.run { downloadFailed = true }
            }
        }
    }

    // URLSession.data(from:) is iOS 15+; wrap the callback API for iOS 13 compatibility.
    private func fetchData(from url: URL) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            URLSession.shared.dataTask(with: url) { data, _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: URLError(.badServerResponse))
                }
            }.resume()
        }
    }
}

// MARK: - Country Static View (when locked/pre-configured)

private struct CountryStaticView: View {
    let country: NativeCountry

    @EnvironmentObject var theme: TruoraTheme

    var body: some View {
        HStack(spacing: 12) {
            SwiftUI.Image(country.rawValue, bundle: .truoraModule)
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 22)
            Text(country.displayName)
                .font(theme.typography.bodyLarge)
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
                        SwiftUI.Image(country.rawValue, bundle: .truoraModule)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 30, height: 22)
                        Text(country.displayName)
                            .font(theme.typography.bodyLarge)
                            .foregroundColor(theme.colors.onSurface)
                    } else {
                        Text(TruoraLocalization.string(forKey: LocalizationKeys.documentSelectionCountryPlaceholder))
                            .font(theme.typography.bodyLarge)
                            .foregroundColor(theme.colors.tint00)
                    }
                    Spacer()
                    SwiftUI.Image(systemName: "chevron.down")
                        .font(theme.typography.bodySmall)
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
                                SwiftUI.Image(country.rawValue, bundle: .truoraModule)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 30, height: rowContentHeight)
                                Text(country.displayName)
                                    .font(theme.typography.bodyLarge)
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

// MARK: - Document Static View (when locked/pre-configured)

private struct DocumentTypeStaticView: View {
    let country: NativeCountry
    let document: NativeDocumentType

    @EnvironmentObject var theme: TruoraTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(document.label(for: country))
                .font(theme.typography.bodyLarge)
                .foregroundColor(theme.colors.onSurface)
            if let description = document.descriptionText(for: country) {
                Text(description)
                    .font(theme.typography.bodyMedium)
                    .foregroundColor(theme.colors.layoutGray500)
            }
        }
        .padding(.vertical, 8)
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
                        if let document = selectedDocument, let country = selectedCountry {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(document.label(for: country))
                                    .font(theme.typography.bodyLarge)
                                    .foregroundColor(theme.colors.onSurface)
                                if let description = document.descriptionText(for: country) {
                                    Text(description)
                                        .font(theme.typography.bodyMedium)
                                        .foregroundColor(theme.colors.layoutGray500)
                                }
                            }
                        } else {
                            Text(
                                TruoraLocalization.string(
                                    forKey: LocalizationKeys.documentSelectionDocumentPlaceholder
                                )
                            )
                            .font(theme.typography.bodyLarge)
                            .foregroundColor(theme.colors.tint00)
                        }
                        Spacer()
                        SwiftUI.Image(systemName: "chevron.down")
                            .font(theme.typography.bodySmall)
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
                            .stroke(
                                showError ? theme.colors.error : theme.colors.tint00,
                                lineWidth: 1
                            )
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
                                            if let country = selectedCountry {
                                                Text(document.label(for: country))
                                                    .font(theme.typography.bodyLarge)
                                                    .foregroundColor(theme.colors.onSurface)
                                            } else {
                                                Text(document.label)
                                                    .font(theme.typography.bodyLarge)
                                                    .foregroundColor(theme.colors.onSurface)
                                            }
                                            let description = selectedCountry.flatMap {
                                                document.descriptionText(for: $0)
                                            }
                                            if let description {
                                                Text(description)
                                                    .font(theme.typography.bodyMedium)
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
private struct DocumentSelectionTypeLockedPreview: View {
    @StateObject private var viewModel: DocumentSelectionViewModel = {
        let vm = DocumentSelectionViewModel()
        vm.countries = [.co]
        vm.selectedCountry = .co
        vm.selectedDocument = .nationalId
        vm.isCountryLocked = true
        vm.isDocumentLocked = true
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

@available(iOS 14.0, *)
private struct DocumentSelectionFixedPreview: View {
    @StateObject private var viewModel: DocumentSelectionViewModel = {
        let vm = DocumentSelectionViewModel()
        vm.countries = [.co]
        vm.selectedCountry = .co
        vm.selectedDocument = .nationalId
        vm.isCountryLocked = true
        vm.isDocumentLocked = true
        vm.isSelectionFixed = true
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

#Preview("Document Selection - Country and Type Locked") {
    if #available(iOS 14.0, *) {
        DocumentSelectionTypeLockedPreview()
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

#Preview("Document Selection - Fixed (Unified Screen)") {
    if #available(iOS 14.0, *) {
        DocumentSelectionFixedPreview()
    }
}
