//
//  TruoraFooterView.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 23/01/26.
//

import SwiftUI

struct TruoraFooterView: View {
    let securityTip: String?
    let buttonText: String
    let isLoading: Bool
    let buttonAccessibilityIdentifier: String?
    let action: () -> Void
    @EnvironmentObject var theme: TruoraTheme

    init(
        securityTip: String?,
        buttonText: String,
        isLoading: Bool,
        buttonAccessibilityIdentifier: String? = nil,
        action: @escaping () -> Void
    ) {
        self.securityTip = securityTip
        self.buttonText = buttonText
        self.isLoading = isLoading
        self.buttonAccessibilityIdentifier = buttonAccessibilityIdentifier
        self.action = action
    }

    var body: some View {
        VStack(spacing: 16) {
            // Security tip with lock icon
            if let tip = securityTip {
                HStack(spacing: 4) {
                    TruoraValidationsSDKAsset.iconLock.swiftUIImage
                        .resizable()
                        .frame(width: 16, height: 16)
                        .foregroundColor(theme.colors.layoutGray700)
                    Text(tip)
                        .font(theme.typography.bodySmall)
                        .foregroundColor(theme.colors.layoutGray700)
                }
            }

            // Primary button
            TruoraPrimaryButton(
                title: buttonText,
                isLoading: isLoading,
                accessibilityIdentifier: buttonAccessibilityIdentifier,
                action: action
            )
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Previews

#Preview("With Security Tip") {
    VStack {
        Spacer()
        TruoraFooterView(
            securityTip: "Your data is encrypted and secure",
            buttonText: "Continue",
            isLoading: false
        ) {}
    }
    .environmentObject(TruoraTheme(config: nil))
}

#Preview("Without Security Tip") {
    VStack {
        Spacer()
        TruoraFooterView(
            securityTip: nil,
            buttonText: "Continue",
            isLoading: false
        ) {}
    }
    .environmentObject(TruoraTheme(config: nil))
}

#Preview("Loading State") {
    VStack {
        Spacer()
        TruoraFooterView(
            securityTip: "Your data is encrypted and secure",
            buttonText: "Continue",
            isLoading: true
        ) {}
    }
    .environmentObject(TruoraTheme(config: nil))
}
