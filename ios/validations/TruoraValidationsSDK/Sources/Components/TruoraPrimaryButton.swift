//
//  TruoraPrimaryButton.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 23/01/26.
//

import SwiftUI

// MARK: - Accessibility Identifier Modifier

/// A view modifier that applies an accessibility identifier if provided
private struct AccessibilityIdentifierModifier: ViewModifier {
    let identifier: String?

    func body(content: Content) -> some View {
        if #available(iOS 14.0, *), let identifier {
            content.accessibilityIdentifier(identifier)
        } else {
            content
        }
    }
}

struct TruoraPrimaryButton: View {
    let title: String
    let isLoading: Bool
    let accessibilityIdentifier: String?
    let action: () -> Void
    @EnvironmentObject var theme: TruoraTheme

    init(
        title: String,
        isLoading: Bool,
        accessibilityIdentifier: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isLoading = isLoading
        self.accessibilityIdentifier = accessibilityIdentifier
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ActivityIndicator(
                        isAnimating: .constant(true),
                        style: .medium,
                        color: .white
                    )
                } else {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                }
            }
            .frame(maxWidth: 810)
            .frame(height: 41)
            .background(theme.colors.primary)
            .foregroundColor(theme.colors.onPrimary)
            .cornerRadius(20)
        }
        .disabled(isLoading)
        .opacity(isLoading ? 0.6 : 1.0)
        .modifier(AccessibilityIdentifierModifier(identifier: accessibilityIdentifier))
    }
}

// MARK: - Previews

#Preview("Default") {
    TruoraPrimaryButton(
        title: "Continue",
        isLoading: false
    ) {}
        .padding()
        .environmentObject(TruoraTheme(config: nil))
}

#Preview("Loading") {
    TruoraPrimaryButton(
        title: "Continue",
        isLoading: true
    ) {}
        .padding()
        .environmentObject(TruoraTheme(config: nil))
}

#Preview("Long Text") {
    TruoraPrimaryButton(
        title: "Start Identity Verification",
        isLoading: false
    ) {}
        .padding()
        .environmentObject(TruoraTheme(config: nil))
}
