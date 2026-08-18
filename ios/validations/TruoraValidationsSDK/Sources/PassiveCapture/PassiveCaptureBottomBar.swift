//
//  PassiveCaptureBottomBar.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 23/01/26.
//

import SwiftUI
import UIKit

/// Bottom navigation bar for passive capture screen with Truora branding.
/// Matches KMP PassiveCaptureBottomBar behavior:
/// - Always visible with consistent height
/// - Help button visibility controlled via showHelpButton parameter
/// - Respects safe area (navigation bar padding)
struct PassiveCaptureBottomBar: View {
    let showHelpButton: Bool
    let onHelpClick: () -> Void
    @EnvironmentObject var theme: TruoraTheme

    init(showHelpButton: Bool = true, onHelpClick: @escaping () -> Void) {
        self.showHelpButton = showHelpButton
        self.onHelpClick = onHelpClick
    }

    var body: some View {
        // Fixed height container matching KMP (36dp for content + padding)
        HStack {
            // Help button (pill-shaped) - only shown when showHelpButton is true
            if showHelpButton {
                Button(action: onHelpClick) {
                    Text(TruoraLocalization.string(forKey: LocalizationKeys.passiveCaptureHelp))
                        .font(theme.typography.bodySmall)
                        .foregroundColor(theme.colors.onSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(theme.colors.secondary)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(theme.colors.gray600, lineWidth: 1)
                        )
                }
            }

            Spacer()

            // Branding logo - always visible
            TruoraValidationsSDKAsset.byTruora.swiftUIImage
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 65, height: 20)
                .foregroundColor(theme.colors.onSurfaceVariant)
        }
        .frame(height: 36) // Fixed height to prevent layout shift
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
    }
}

#Preview("With Help Button") {
    VStack {
        Spacer()
        PassiveCaptureBottomBar(showHelpButton: true) {}
    }
    .environmentObject(TruoraTheme(config: nil))
}

#Preview("Without Help Button") {
    VStack {
        Spacer()
        PassiveCaptureBottomBar(showHelpButton: false) {}
    }
    .environmentObject(TruoraTheme(config: nil))
}
