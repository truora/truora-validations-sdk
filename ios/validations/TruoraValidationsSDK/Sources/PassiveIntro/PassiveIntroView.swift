//
//  PassiveIntroView.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 31/10/25.
//

import SwiftUI

struct PassiveIntroView: View {
    @ObservedObject var viewModel: PassiveIntroViewModel
    @ObservedObject private var theme: TruoraTheme

    init(viewModel: PassiveIntroViewModel, config: UIConfig?) {
        self.viewModel = viewModel
        self.theme = TruoraTheme(config: config)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header
                if viewModel.showCancelButton {
                    TruoraHeaderView {
                        viewModel.cancel()
                    }
                }

                // Content
                PassiveIntroContentView()

                Spacer()

                // Footer
                TruoraFooterView(
                    securityTip: TruoraValidationsSDKStrings.passiveInstructionsSecurityTip,
                    buttonText: TruoraValidationsSDKStrings.passiveInstructionsStartVerification,
                    isLoading: viewModel.isLoading,
                    buttonAccessibilityIdentifier: "intro_start_button"
                ) {
                    viewModel.start()
                }
            }

            // Loading overlay
            if viewModel.isLoading {
                LoadingOverlayView(message: TruoraValidationsSDKStrings.passiveCaptureLoadingTitle)
            }
        }
        .environmentObject(theme)
        .navigationBarHidden(true)
        .alert(isPresented: $viewModel.showError) {
            Alert(
                title: Text(NSLocalizedString("common_error", bundle: .module, comment: "")),
                message: Text(viewModel.errorMessage ?? ""),
                dismissButton: .default(Text(NSLocalizedString("common_ok", bundle: .module, comment: "")))
            )
        }
        .onAppear {
            viewModel.onAppear()
        }
    }
}

// MARK: - Previews

#Preview {
    PassiveIntroView(
        viewModel: PassiveIntroViewModel(),
        config: nil
    )
}
