//
//  CompatibleAlert.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 25/01/26.
//

import SwiftUI

/// A view modifier that provides iOS version-compatible alert presentation.
/// Uses the modern alert API on iOS 15+ and falls back to the deprecated Alert struct on iOS 13-14.
struct CompatibleAlert: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    let message: String?
    let dismissButtonTitle: String
    let dismissAction: (() -> Void)?

    func body(content: Content) -> some View {
        if #available(iOS 15.0, *) {
            content.alert(title, isPresented: $isPresented) {
                Button(dismissButtonTitle) {
                    dismissAction?()
                }
            } message: {
                if let message {
                    Text(message)
                }
            }
        } else {
            content.alert(isPresented: $isPresented) {
                Alert(
                    title: Text(title),
                    message: message.map { Text($0) },
                    dismissButton: .default(Text(dismissButtonTitle)) {
                        dismissAction?()
                    }
                )
            }
        }
    }
}

/// A view modifier for two-button alerts with iOS version compatibility.
struct CompatibleConfirmationAlert: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    let message: String?
    let primaryButtonTitle: String
    let primaryAction: () -> Void
    let secondaryButtonTitle: String
    let secondaryAction: (() -> Void)?

    func body(content: Content) -> some View {
        if #available(iOS 15.0, *) {
            content.alert(title, isPresented: $isPresented) {
                Button(primaryButtonTitle, action: primaryAction)
                Button(secondaryButtonTitle, role: .cancel) {
                    secondaryAction?()
                }
            } message: {
                if let message {
                    Text(message)
                }
            }
        } else {
            content.alert(isPresented: $isPresented) {
                Alert(
                    title: Text(title),
                    message: message.map { Text($0) },
                    primaryButton: .default(Text(primaryButtonTitle), action: primaryAction),
                    secondaryButton: .cancel(Text(secondaryButtonTitle)) {
                        secondaryAction?()
                    }
                )
            }
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Presents an alert with iOS version compatibility.
    /// Uses modern alert API on iOS 15+ and deprecated Alert on iOS 13-14.
    func compatibleAlert(
        isPresented: Binding<Bool>,
        title: String,
        message: String?,
        dismissButtonTitle: String = "OK",
        dismissAction: (() -> Void)? = nil
    ) -> some View {
        modifier(CompatibleAlert(
            isPresented: isPresented,
            title: title,
            message: message,
            dismissButtonTitle: dismissButtonTitle,
            dismissAction: dismissAction
        ))
    }

    /// Presents a confirmation alert with iOS version compatibility.
    func compatibleConfirmationAlert(
        isPresented: Binding<Bool>,
        title: String,
        message: String?,
        primaryButtonTitle: String,
        primaryAction: @escaping () -> Void,
        secondaryButtonTitle: String = "Cancel",
        secondaryAction: (() -> Void)? = nil
    ) -> some View {
        modifier(CompatibleConfirmationAlert(
            isPresented: isPresented,
            title: title,
            message: message,
            primaryButtonTitle: primaryButtonTitle,
            primaryAction: primaryAction,
            secondaryButtonTitle: secondaryButtonTitle,
            secondaryAction: secondaryAction
        ))
    }
}
