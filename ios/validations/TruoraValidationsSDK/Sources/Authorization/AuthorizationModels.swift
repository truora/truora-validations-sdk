//
//  AuthorizationModels.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 01/07/26.
//

import Foundation

/// A single consent the user can grant on the `enter_authorization` screen.
///
/// The number of consents is dynamic, so `DataAuthorizationView` renders one row per element.
/// The view is fully controlled: the host owns each consent's `checked` state and reacts to
/// `onConsentToggle` to update it, mirroring the KMP `AuthorizationConsent` model.
///
/// - Parameters:
///   - id: Stable identifier used to report toggles back to the host.
///   - text: Localized consent text. May embed `linkText` as an inline highlighted link.
///   - checked: Whether the consent is currently granted. State is hoisted to the host.
///   - required: When true the primary action shows a validation error until this consent is
///     checked. Optional consents never block the action.
///   - linkText: Optional substring of `text` rendered as a highlighted, tappable link.
///   - linkURL: Optional URL associated with `linkText`, forwarded on link taps.
struct AuthorizationConsent: Identifiable, Equatable {
    let id: String
    let text: String
    var checked: Bool
    var required: Bool
    var linkText: String?
    var linkURL: URL?

    init(
        id: String,
        text: String,
        checked: Bool = false,
        required: Bool = true,
        linkText: String? = nil,
        linkURL: URL? = nil
    ) {
        self.id = id
        self.text = text
        self.checked = checked
        self.required = required
        self.linkText = linkText
        self.linkURL = linkURL
    }
}
