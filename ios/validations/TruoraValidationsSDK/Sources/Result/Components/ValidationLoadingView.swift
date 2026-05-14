//
//  ValidationLoadingView.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 23/01/26.
//

import SwiftUI
import UIKit

/// Full-screen loading view displayed during document/face validation processing.
/// Matches the Figma design with:
/// - Dark blue background (primary900 / #082054)
/// - Centered icon (face or document based on loadingType)
/// - "Verificando" title and description text
/// - Animated progress bar
/// - "By Truora" footer branding
///
/// Adapts layout for both iPhone and iPad screen sizes.
struct ValidationLoadingView: View {
    let loadingType: ResultLoadingType
    @EnvironmentObject var theme: TruoraTheme

    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    private func iconSize(for screenWidth: CGFloat) -> CGSize {
        let size = min(screenWidth * 0.5, 200)
        return CGSize(width: size, height: size)
    }

    private var horizontalPadding: CGFloat {
        isIPad ? 48 : 18
    }

    private var footerHorizontalPadding: CGFloat {
        isIPad ? 48 : 24
    }

    private var footerBottomPadding: CGFloat {
        isIPad ? 48 : 30
    }

    private var footerLogoSize: CGSize {
        isIPad ? CGSize(width: 57, height: 36) : CGSize(width: 38, height: 24)
    }

    private var loadingBarHeight: CGFloat {
        isIPad ? 6 : 4
    }

    var body: some View {
        GeometryReader { geometry in
            let maxContentWidth: CGFloat = isIPad ? min(600, geometry.size.width * 0.7) : .infinity
            let iconSizeValue = iconSize(for: geometry.size.width)

            ZStack {
                theme.colors.surfaceVariant
                    .extendingIntoSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    // Centered icon
                    AnimatedGIFView(
                        gifName: loadingType.gifName,
                        tintColor: theme.colors.onSurfaceVariant.uiColor,
                        size: iconSizeValue
                    )
                    .frame(width: iconSizeValue.width, height: iconSizeValue.height)

                    Spacer()

                    // Bottom text section
                    VStack(alignment: .leading, spacing: isIPad ? 12 : 8) {
                        Text(
                            loadingType == .face
                                ? TruoraLocalization.string(
                                    forKey: LocalizationKeys.passiveCaptureLoadingTitle
                                )
                                : TruoraLocalization.string(
                                    forKey: LocalizationKeys.documentAutocaptureLoadingVerifying
                                )
                        )
                        .font(theme.typography.titleLarge)
                        .fontWeight(.bold)
                        .foregroundColor(theme.colors.onSurfaceVariant)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Text(
                            TruoraLocalization.string(
                                forKey: LocalizationKeys.docAutocaptureVerifyingDesc
                            )
                        )
                        .font(theme.typography.bodyLarge)
                        .foregroundColor(theme.colors.onSurfaceVariant)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                        AnimatedLoadingBar(height: loadingBarHeight)
                            .padding(.top, isIPad ? 16 : 8)
                    }
                    .frame(maxWidth: maxContentWidth)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, isIPad ? 24 : 16)

                    // Footer with Truora branding
                    HStack {
                        Spacer()
                        TruoraValidationsSDKAsset.byTruora.swiftUIImage
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: footerLogoSize.width, height: footerLogoSize.height)
                            .foregroundColor(theme.colors.onSurfaceVariant)
                    }
                    .frame(maxWidth: maxContentWidth)
                    .padding(.horizontal, footerHorizontalPadding)
                    .padding(.bottom, footerBottomPadding)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Previews

#Preview("Face Loading") {
    ValidationLoadingView(loadingType: .face)
        .environmentObject(TruoraTheme(config: nil))
}

#Preview("Document Loading") {
    ValidationLoadingView(loadingType: .document)
        .environmentObject(TruoraTheme(config: nil))
}

#Preview("Document Loading with Custom Theme") {
    ValidationLoadingView(loadingType: .document)
        .environmentObject(TruoraTheme(
            config: UIConfig()
                .setSurfaceVariantColor("#000000")
                .setOnSurfaceVariantColor("#FF0000")
        ))
}

#Preview("Invoice Loading") {
    ValidationLoadingView(loadingType: .invoice)
        .environmentObject(TruoraTheme(config: nil))
}
