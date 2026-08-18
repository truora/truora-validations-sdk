//
//  DataAuthorizationView.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 01/07/26.
//

import SwiftUI

// MARK: - Public self-contained view

/// Self-contained view for the `enter_authorization` step — the first screen in every DI process.
///
/// It renders a dynamic list of ``AuthorizationConsent`` rows the user can grant individually and
/// is **fully controlled**: the host owns each consent's `checked` state, the loading flag and the
/// error message. It only emits events and reacts to props (mirroring the KMP `DataAuthorizationView`
/// composable); it is intentionally **not** wired to any Interactor/Presenter/Router.
///
/// The primary button is always enabled. When tapped while a required consent is still unchecked,
/// those checkboxes turn red and a validation message is shown above the button instead of invoking
/// `onAccept`. `onAccept` only fires once every required consent is granted — the host is then
/// expected to verify the step with **both** the `authorization` and `client_authorization`
/// inputs set to `"true"` (`verifyStep(stepId, [Input(name: "authorization", value: "true"),
/// Input(name: "client_authorization", value: "true")])`), set `isLoading` while it runs and
/// surface `errorMessage` on failure.
///
/// - Parameters:
///   - consents: Dynamic list of consents rendered as checkbox rows with optional inline links.
///   - title: Localized screen title.
///   - policyLinkURL: Optional URL forwarded to `onPolicyTap` when the policy link is tapped.
///   - isLoading: Whether the primary action is in progress (e.g. verifyStep running).
///   - errorMessage: Optional error rendered above the button when an action fails.
///   - config: Optional UI configuration for colors and logo.
///   - onAccept: Invoked when the primary button is tapped and every required consent is granted.
///   - onConsentToggle: Invoked with the consent id and new checked value when a row is toggled.
///   - onCancel: Invoked when the header close button is tapped. When nil the close button is hidden.
///   - onConsentLinkTap: Invoked when an inline link inside a consent text is tapped.
///   - onPolicyTap: Invoked with `policyLinkURL` when the data-processing policy link is tapped.
struct DataAuthorizationView: View {
    let consents: [AuthorizationConsent]
    let title: String
    let policyLinkURL: URL?
    let isLoading: Bool
    let errorMessage: String?
    let onAccept: () -> Void
    let onConsentToggle: (String, Bool) -> Void
    let onCancel: (() -> Void)?
    let onConsentLinkTap: ((URL?) -> Void)?
    let onPolicyTap: ((URL?) -> Void)?

    @ObservedObject private var theme: TruoraTheme
    // Local validation state: flipped on when the user tries to continue with a required consent
    // still unchecked. Visuals key off the live `hasMissingRequired` condition, so they clear
    // automatically as soon as the missing consents are granted.
    @State private var showRequiredError = false

    init(
        consents: [AuthorizationConsent],
        title: String = TruoraLocalization.string(forKey: LocalizationKeys.authorizationTitle),
        policyLinkURL: URL? = nil,
        isLoading: Bool = false,
        errorMessage: String? = nil,
        config: UIConfig? = nil,
        onAccept: @escaping () -> Void,
        onConsentToggle: @escaping (String, Bool) -> Void,
        onCancel: (() -> Void)? = nil,
        onConsentLinkTap: ((URL?) -> Void)? = nil,
        onPolicyTap: ((URL?) -> Void)? = nil
    ) {
        self.consents = consents
        self.title = title
        self.policyLinkURL = policyLinkURL
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.onAccept = onAccept
        self.onConsentToggle = onConsentToggle
        self.onCancel = onCancel
        self.onConsentLinkTap = onConsentLinkTap
        self.onPolicyTap = onPolicyTap
        self.theme = TruoraTheme(config: config)
    }

    private var hasMissingRequired: Bool {
        AuthorizationValidation.hasMissingRequired(in: consents)
    }

    var body: some View {
        DataAuthorizationContent(
            consents: consents,
            title: title,
            policyLinkURL: policyLinkURL,
            isLoading: isLoading,
            errorMessage: errorMessage,
            showRequiredError: showRequiredError,
            hasMissingRequired: hasMissingRequired,
            onPrimaryTap: {
                switch AuthorizationValidation.primaryAction(for: consents) {
                case .showRequiredError:
                    showRequiredError = true
                case .accept:
                    showRequiredError = false
                    onAccept()
                }
            },
            onConsentToggle: onConsentToggle,
            onCancel: onCancel,
            onConsentLinkTap: onConsentLinkTap,
            onPolicyTap: onPolicyTap
        )
        .environmentObject(theme)
        .background(theme.colors.surface.extendingIntoSafeArea())
        .navigationBarHidden(true)
    }
}

// MARK: - Stateless content

/// Stateless body of ``DataAuthorizationView``. The validation state and decision are owned by the
/// public view; this layer only renders, which keeps every visual state (including the required
/// error state) exercisable from `#Preview`s and tests.
struct DataAuthorizationContent: View {
    let consents: [AuthorizationConsent]
    let title: String
    let policyLinkURL: URL?
    let isLoading: Bool
    let errorMessage: String?
    let showRequiredError: Bool
    let hasMissingRequired: Bool
    let onPrimaryTap: () -> Void
    let onConsentToggle: (String, Bool) -> Void
    let onCancel: (() -> Void)?
    let onConsentLinkTap: ((URL?) -> Void)?
    let onPolicyTap: ((URL?) -> Void)?

    @EnvironmentObject var theme: TruoraTheme

    /// The validation message is only shown while the user has attempted to continue *and* a
    /// required consent is still missing, so it disappears the moment the rule is satisfied.
    private var showValidationMessage: Bool {
        showRequiredError && hasMissingRequired
    }

    /// A hard backend error takes precedence; otherwise the local validation message is shown.
    private var inlineError: String? {
        if let errorMessage {
            return errorMessage
        }
        if showValidationMessage {
            return TruoraLocalization.string(forKey: LocalizationKeys.authorizationRequiredFieldsError)
        }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            TruoraHeaderView(onCancel: onCancel)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(title)
                        .font(theme.typography.titleLarge)
                        .foregroundColor(theme.colors.onSurface)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(consents) { consent in
                            AuthorizationConsentRow(
                                consent: consent,
                                onToggle: { checked in onConsentToggle(consent.id, checked) },
                                onLinkTap: onConsentLinkTap,
                                isError: showRequiredError && consent.required && !consent.checked
                            )
                        }
                    }

                    AuthorizationPolicyLink(
                        text: TruoraLocalization.string(forKey: LocalizationKeys.authorizationDataPolicyText),
                        linkText: TruoraLocalization.string(forKey: LocalizationKeys.authorizationDataPolicyLink),
                        linkURL: policyLinkURL,
                        onTap: onPolicyTap
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }

            footer
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            if let inlineError {
                AuthorizationErrorText(message: inlineError)
                    .padding(.horizontal, 16)
            }

            TruoraFooterView(
                // Once every required consent is granted (and there is no hard error), surface the
                // reassuring security tip with its lock icon in place of the validation message.
                securityTip: (!hasMissingRequired && errorMessage == nil)
                    ? TruoraLocalization.string(forKey: LocalizationKeys.authorizationSecurityTip)
                    : nil,
                buttonText: TruoraLocalization.string(forKey: LocalizationKeys.authorizationAccept),
                isLoading: isLoading,
                buttonAccessibilityIdentifier: "authorization_accept_button",
                action: onPrimaryTap
            )

            HStack {
                Spacer()
                ByTruoraBadge()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }
}

// MARK: - Previews

#Preview("Default") {
    DataAuthorizationView(
        consents: [
            AuthorizationConsent(
                id: "biometric",
                text: "Autorizo el uso de mis datos biométricos para verificar mi identidad.",
                checked: true,
                linkText: "datos biométricos"
            ),
            AuthorizationConsent(
                id: "client_consent",
                text: "Ejemplo de autorización del cliente. Lorem ipsum dolor sit amet, consectetur adipiscing elit.",
                checked: false
            )
        ],
        onAccept: {},
        onConsentToggle: { _, _ in },
        onCancel: {}
    )
}

#Preview("Loading") {
    DataAuthorizationView(
        consents: [
            AuthorizationConsent(
                id: "biometric",
                text: "I authorize the use of my biometric data to verify my identity.",
                checked: true,
                linkText: "biometric data"
            )
        ],
        isLoading: true,
        onAccept: {},
        onConsentToggle: { _, _ in },
        onCancel: {}
    )
}

#Preview("Required Error") {
    DataAuthorizationContent(
        consents: [
            AuthorizationConsent(
                id: "biometric",
                text: "Autorizo el uso de mis datos biométricos para verificar mi identidad.",
                checked: false,
                linkText: "datos biométricos"
            ),
            AuthorizationConsent(
                id: "client_consent",
                text: "Ejemplo de autorización del cliente. Lorem ipsum dolor sit amet.",
                checked: false
            )
        ],
        title: "Autorización de datos biométricos",
        policyLinkURL: nil,
        isLoading: false,
        errorMessage: nil,
        showRequiredError: true,
        hasMissingRequired: true,
        onPrimaryTap: {},
        onConsentToggle: { _, _ in },
        onCancel: {},
        onConsentLinkTap: nil,
        onPolicyTap: nil
    )
    .environmentObject(TruoraTheme(config: nil))
}
