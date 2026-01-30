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

    private var loadingIcon: SwiftUI.Image {
        switch loadingType {
        case .face:
            TruoraValidationsSDKAsset.faceLoadingIcon.swiftUIImage
        case .document:
            TruoraValidationsSDKAsset.documentLoadingIcon.swiftUIImage
        }
    }

    /// Returns the icon size proportional to screen width (50%) with a maximum size.
    /// - Face icon: 50% of screen width, max 200pt (square)
    /// - Document icon: 50% of screen width, max 200pt width, aspect ratio 1.3:1
    private func iconSize(for screenWidth: CGFloat) -> CGSize {
        let maxSize: CGFloat = 200
        switch loadingType {
        case .face:
            let size = min(screenWidth * 0.5, maxSize)
            return CGSize(width: size, height: size)
        case .document:
            let width = min(screenWidth * 0.5, maxSize)
            let height = width / 1.3 // aspect ratio from Figma (150/115 ≈ 1.3)
            return CGSize(width: width, height: height)
        }
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
                // Full-screen dark blue background
                theme.colors.primary900
                    .edgesIgnoringSafeArea(.all)

                VStack(spacing: 0) {
                    Spacer()

                    // Centered icon
                    loadingIcon
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: iconSizeValue.width, height: iconSizeValue.height)
                        .foregroundColor(.white)

                    Spacer()

                    // Bottom text section
                    VStack(alignment: .leading, spacing: isIPad ? 12 : 8) {
                        Text(
                            loadingType == .face
                                ? TruoraValidationsSDKStrings.passiveCaptureLoadingTitle
                                : TruoraValidationsSDKStrings.documentAutocaptureLoadingVerifying
                        )
                        .font(theme.typography.titleSmall)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Text(TruoraValidationsSDKStrings.documentAutocaptureLoadingVerifyingDescription)
                            .font(theme.typography.bodyLarge)
                            .foregroundColor(.white)
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
                        TruoraValidationsSDKAsset.byTruoraDark.swiftUIImage
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: footerLogoSize.width, height: footerLogoSize.height)
                            .foregroundColor(theme.colors.tint00)
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
