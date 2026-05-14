//
//  InvoiceInstructionsView.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 16/04/26.
//

import SwiftUI

// MARK: - Native SwiftUI View

struct InvoiceInstructionsView: View {
    @ObservedObject var viewModel: InvoiceInstructionsViewModel
    @ObservedObject private var theme: TruoraTheme
    let countryContent: InvoiceCountryContent

    init(viewModel: InvoiceInstructionsViewModel, config: UIConfig?, country: String) {
        self.viewModel = viewModel
        self.theme = TruoraTheme(config: config)
        self.countryContent = InvoiceCountryContent(country: country)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header
                TruoraHeaderView {
                    viewModel.cancel()
                }

                // Content
                InvoiceInstructionsContentView(countryContent: countryContent)

                Spacer()

                // Footer: Two buttons
                VStack(spacing: 12) {
                    // Primary button: Upload file
                    TruoraPrimaryButton(
                        title: TruoraLocalization.string(
                            forKey: LocalizationKeys.invoiceInstructionsUploadFile
                        ),
                        isLoading: viewModel.isLoading
                    ) {
                        viewModel.uploadFile()
                    }

                    // Secondary button: Take photo (outlined, per Figma)
                    Button {
                        viewModel.takePhoto()
                    } label: {
                        Text(TruoraLocalization.string(forKey: LocalizationKeys.invoiceInstructionsTakePhoto))
                            .font(Font.system(size: 16, weight: .medium))
                            .foregroundColor(theme.colors.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 50)
                            .stroke(theme.colors.primary, lineWidth: 2)
                    )
                    .disabled(viewModel.isLoading)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }

            // Loading overlay
            if viewModel.isLoading {
                LoadingOverlayView(
                    message: TruoraLocalization.string(
                        forKey: LocalizationKeys.invoiceInstructionsCreatingValidation
                    )
                )
            }
        }
        .environmentObject(theme)
        .background(theme.colors.surface.extendingIntoSafeArea())
        .navigationBarHidden(true)
        .alert(isPresented: $viewModel.showError) {
            Alert(
                title: Text(TruoraLocalization.string(forKey: LocalizationKeys.commonError)),
                message: Text(viewModel.errorMessage ?? ""),
                dismissButton: .default(
                    Text(TruoraLocalization.string(forKey: LocalizationKeys.commonOk))
                )
            )
        }
        .onAppear {
            viewModel.onAppear()
        }
    }
}

// MARK: - Invoice Instructions Content

/// Content component for InvoiceInstructionsView.
/// Follows the same pattern as DocumentIntroContentView: image at top, left-aligned text below.
struct InvoiceInstructionsContentView: View {
    @EnvironmentObject var theme: TruoraTheme
    let countryContent: InvoiceCountryContent

    var body: some View {
        GeometryReader { geometry in
            let isPhone = geometry.size.width < 600
            let maxImageHeight: CGFloat =
                isPhone
                    ? geometry.size.height * 0.4
                    : min(850, geometry.size.height * 0.5)

            VStack(spacing: 0) {
                // Illustration - matches DocumentIntroContentView pattern
                SwiftUI.Image("invoice_instructions", bundle: .truoraModule)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: maxImageHeight)
                    .frame(maxWidth: isPhone ? .infinity : 1024)
                    .clipped()

                // Title & Subtitle - left-aligned per Figma
                VStack(alignment: .leading, spacing: 16) {
                    // Title (country-specific: MX "comprobante", CO "factura")
                    Text(TruoraLocalization.string(forKey: countryContent.titleKey))
                        .font(theme.typography.titleLarge)
                        .foregroundColor(theme.colors.onSurface)
                        .multilineTextAlignment(.leading)

                    // Subtitle: MX has bold-red validity period, CO has plain text
                    invoiceSubtitleText

                    // Provider logos row
                    HStack(spacing: countryContent.logoSpacing) {
                        ForEach(countryContent.providerLogoNames, id: \.self) { logoName in
                            SwiftUI.Image(logoName, bundle: .truoraModule)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 60)
                        }
                    }
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
        }
    }

    /// Builds the subtitle. MX: mixed formatting with bold-red validity period. CO: plain text.
    @ViewBuilder
    private var invoiceSubtitleText: some View {
        if countryContent.showsValidityPeriod {
            // MX: "Con **vigencia máxima de 3 meses** de las siguientes entidades:"
            let prefix = TruoraLocalization.string(forKey: countryContent.subtitlePrefixKey)
            let highlight = TruoraLocalization.string(forKey: countryContent.validityPeriodKey)
            let suffix = TruoraLocalization.string(forKey: countryContent.subtitleSuffixKey)

            (
                Text(prefix)
                    .font(theme.typography.bodyLarge)
                    .foregroundColor(theme.colors.onSurface)
                    + Text(highlight)
                    .font(Font.system(size: 16, weight: .bold))
                    .foregroundColor(theme.colors.error)
                    + Text(suffix)
                    .font(theme.typography.bodyLarge)
                    .foregroundColor(theme.colors.onSurface)
            )
            .multilineTextAlignment(.leading)
        } else {
            // CO: "Aceptamos facturas de las siguientes entidades:"
            Text(TruoraLocalization.string(forKey: countryContent.subtitleKey))
                .font(theme.typography.bodyLarge)
                .foregroundColor(theme.colors.onSurface)
                .multilineTextAlignment(.leading)
        }
    }
}

// MARK: - Previews

#Preview("Invoice Instructions - MX") {
    InvoiceInstructionsView(
        viewModel: InvoiceInstructionsViewModel(),
        config: nil,
        country: "MX"
    )
}

#Preview("Invoice Instructions - CO") {
    InvoiceInstructionsView(
        viewModel: InvoiceInstructionsViewModel(),
        config: nil,
        country: "CO"
    )
}
