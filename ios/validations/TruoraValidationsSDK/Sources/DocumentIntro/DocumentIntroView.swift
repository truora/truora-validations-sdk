//
//  DocumentIntroView.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 23/12/25.
//

import SwiftUI

// MARK: - Native SwiftUI View

struct DocumentIntroView: View {
    @ObservedObject var viewModel: DocumentIntroViewModel
    @ObservedObject private var theme: TruoraTheme

    init(viewModel: DocumentIntroViewModel, config: UIConfig?) {
        self.viewModel = viewModel
        self.theme = TruoraTheme(config: config)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header
                TruoraHeaderView {
                    viewModel.cancel()
                }

                // Content
                DocumentIntroContentView()

                Spacer()

                // Footer
                VStack(spacing: 0) {
                    TruoraFooterView(
                        securityTip: TruoraLocalization.string(forKey: LocalizationKeys.documentIntroSecurityTip),
                        buttonText: TruoraLocalization.string(forKey: LocalizationKeys.documentIntroStartCapture),
                        isLoading: viewModel.isLoading
                    ) {
                        viewModel.start()
                    }
                }
            }

            // Loading overlay
            if viewModel.isLoading {
                LoadingOverlayView(
                    message: TruoraLocalization.string(forKey: LocalizationKeys.documentIntroCreatingValidation)
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

// MARK: - Document Intro Content

/// Content component for DocumentIntroView.
/// Follows same pattern as PassiveIntroContentView with image at top, left-aligned text.
struct DocumentIntroContentView: View {
    @EnvironmentObject var theme: TruoraTheme

    var body: some View {
        GeometryReader { geometry in
            let isPhone = geometry.size.width < 600
            // iPad: max 850px per Figma spec, iPhone: 50% of available height
            let maxImageHeight: CGFloat =
                isPhone
                    ? geometry.size.height * 0.5
                    : min(850, geometry.size.height * 0.65)

            VStack(spacing: 0) {
                // Illustration with bottom fade - matches PassiveIntroContentView pattern
                TruoraValidationsSDKAsset.documentIntro.swiftUIImage
                    .resizable()
                    .scaledToFill()
                    .frame(maxHeight: maxImageHeight, alignment: .top)
                    .frame(maxWidth: isPhone ? .infinity : 1024)
                    .clipped()
                    .fadingEdge(
                        brush: Gradient(colors: [.clear, theme.colors.surface]),
                        height: 100
                    )

                // Title & Subtitle - left-aligned per Figma
                VStack(alignment: .leading, spacing: 12) {
                    Text(TruoraLocalization.string(forKey: LocalizationKeys.documentIntroTitle))
                        .font(theme.typography.titleLarge)
                        .foregroundColor(theme.colors.onSurface)
                        .multilineTextAlignment(.leading)

                    Text(TruoraLocalization.string(forKey: LocalizationKeys.documentIntroSubtitle))
                        .font(theme.typography.bodyLarge)
                        .foregroundColor(theme.colors.onSurface)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
            }
        }
    }
}

// MARK: - Previews

#Preview("Document Intro View") {
    DocumentIntroView(
        viewModel: DocumentIntroViewModel(),
        config: nil
    )
}

#Preview("Document Intro Content") {
    DocumentIntroContentView()
        .environmentObject(TruoraTheme(config: nil))
}
