//
//  AuthorizationComponents.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 01/07/26.
//

import SwiftUI

// MARK: - Accessibility helpers

private extension View {
    /// Applies an accessibility identifier on iOS 14+ (the API is unavailable on iOS 13, the
    /// SDK's minimum deployment target).
    @ViewBuilder
    func authorizationAccessibilityIdentifier(_ identifier: String) -> some View {
        if #available(iOS 14.0, *) {
            accessibilityIdentifier(identifier)
        } else {
            self
        }
    }
}

// MARK: - Highlighted / linkable text

/// Renders `text` with an optional `linkText` substring highlighted as a link.
///
/// On iOS 15+ the link substring is genuinely tappable and forwards `linkURL` through
/// `onLinkTap`. On iOS 13/14 (no `AttributedString`) the substring is still visually
/// highlighted; when the whole text represents a single link (the policy line) the caller can
/// opt into a whole-text tap via `tapWholeText`.
struct AuthorizationLinkText: View {
    let text: String
    let linkText: String?
    let linkURL: URL?
    let color: Color
    let baseColor: Color
    let font: Font
    var tapWholeText: Bool = false
    var onLinkTap: ((URL?) -> Void)?

    var body: some View {
        if #available(iOS 15.0, *), let linkText, !linkText.isEmpty {
            Text(attributedText(linkText: linkText))
                .font(font)
                .environment(\.openURL, OpenURLAction { _ in
                    onLinkTap?(linkURL)
                    return .handled
                })
        } else {
            let content = concatenatedText(linkText: linkText)
                .font(font)
            if tapWholeText, linkText != nil {
                content.onTapGesture { onLinkTap?(linkURL) }
            } else {
                content
            }
        }
    }

    /// iOS 13/14 fallback: concatenate plain + highlighted + plain `Text` segments so the link
    /// substring is emphasized even though per-segment taps are unavailable.
    private func concatenatedText(linkText: String?) -> Text {
        guard let linkText, !linkText.isEmpty,
              let range = text.range(of: linkText) else {
            return Text(text).foregroundColor(baseColor)
        }
        let before = String(text[text.startIndex ..< range.lowerBound])
        let after = String(text[range.upperBound ..< text.endIndex])
        return Text(before).foregroundColor(baseColor)
            + Text(linkText).foregroundColor(color).underline()
            + Text(after).foregroundColor(baseColor)
    }

    @available(iOS 15.0, *)
    private func attributedText(linkText: String) -> AttributedString {
        var attributed = AttributedString(text)
        attributed.foregroundColor = baseColor
        if let range = attributed.range(of: linkText) {
            attributed[range].foregroundColor = color
            attributed[range].underlineStyle = .single
            // A concrete URL is required for the link to be tappable; the real navigation is
            // intercepted by the openURL handler, so a placeholder is fine when linkURL is nil.
            attributed[range].link = linkURL ?? URL(string: "truora://authorization-link")
        }
        return attributed
    }
}

// MARK: - Consent row

/// A consent row: a checkbox bound to `consent.checked` plus the consent text with an optional
/// inline link. Only the checkbox toggles the consent (matching the KMP layout); tapping an
/// inline link calls `onLinkTap`.
///
/// When `isError` is true (a required consent left unchecked after the user tried to continue)
/// the checkbox is rendered with the theme error color to draw attention to it.
struct AuthorizationConsentRow: View {
    let consent: AuthorizationConsent
    let onToggle: (Bool) -> Void
    var onLinkTap: ((URL?) -> Void)?
    var isError: Bool = false

    @EnvironmentObject var theme: TruoraTheme

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            AuthorizationCheckbox(
                checked: consent.checked,
                isError: isError,
                accessibilityLabel: consent.text
            ) {
                onToggle(!consent.checked)
            }

            AuthorizationLinkText(
                text: consent.text,
                linkText: consent.linkText,
                linkURL: consent.linkURL,
                color: theme.colors.primary,
                baseColor: theme.colors.onSurface,
                font: theme.typography.bodyMedium,
                onLinkTap: onLinkTap
            )
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            // Align the first text line with the 22 pt box centered in the 44 pt hit area.
            .padding(.top, 11)
            // The checkbox already carries the consent text as its VoiceOver label, so hide the
            // visible copy to avoid VoiceOver announcing it twice.
            .accessibility(hidden: true)
        }
    }
}

/// Custom checkbox (SwiftUI has no native checkbox on iOS). Draws a rounded square that fills
/// with the primary color and a checkmark when checked; the border turns to the error color when
/// `isError` is true.
struct AuthorizationCheckbox: View {
    let checked: Bool
    var isError: Bool = false
    /// Localized label VoiceOver announces for the toggle (typically the consent text).
    var accessibilityLabel: String?
    let onToggle: () -> Void

    @EnvironmentObject var theme: TruoraTheme

    private var borderColor: Color {
        if isError {
            return theme.colors.error
        }
        return checked ? theme.colors.primary : theme.colors.layoutTint20
    }

    var body: some View {
        Button(action: onToggle) {
            RoundedRectangle(cornerRadius: 4)
                .stroke(borderColor, lineWidth: 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(checked ? theme.colors.primary : Color.clear)
                )
                .frame(width: 22, height: 22)
                .overlay(
                    SwiftUI.Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(theme.colors.onPrimary)
                        .opacity(checked ? 1 : 0)
                )
                // Expand the tappable area to the 44x44 pt minimum from Apple's HIG while keeping
                // the 22 pt visual box centered inside it.
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // `.accessibility(...)` (not the iOS 14 `.accessibilityLabel`) so it also compiles on the
        // SDK's iOS 13 minimum. Announced as a selectable button so VoiceOver reads it as a toggle.
        .accessibility(label: Text(accessibilityLabel ?? ""))
        .accessibility(addTraits: checked ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Policy link

/// A standalone policy line: a full localized sentence (`text`) in which `linkText` is
/// highlighted as a tappable link. Keeping the sentence whole lets each locale place the link
/// wherever its grammar requires.
struct AuthorizationPolicyLink: View {
    let text: String
    let linkText: String
    var linkURL: URL?
    var onTap: ((URL?) -> Void)?

    @EnvironmentObject var theme: TruoraTheme

    var body: some View {
        AuthorizationLinkText(
            text: text,
            linkText: linkText,
            linkURL: linkURL,
            color: theme.colors.primary,
            baseColor: theme.colors.layoutGray700,
            font: theme.typography.bodyMedium,
            tapWholeText: true,
            onLinkTap: onTap
        )
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Error text

/// Inline error message shown above the primary action when a required consent is missing or an
/// action (e.g. verifyStep) fails.
struct AuthorizationErrorText: View {
    let message: String
    @EnvironmentObject var theme: TruoraTheme

    var body: some View {
        Text(message)
            .font(theme.typography.labelSmall)
            .foregroundColor(theme.colors.error)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .authorizationAccessibilityIdentifier("authorization_error")
    }
}

// MARK: - By Truora badge

/// The "By Truora" badge anchored at the bottom-trailing edge of the authorization screen.
struct ByTruoraBadge: View {
    var body: some View {
        TruoraValidationsSDKAsset.byTruora.swiftUIImage
            .resizable()
            .scaledToFit()
            .frame(height: 20)
    }
}
