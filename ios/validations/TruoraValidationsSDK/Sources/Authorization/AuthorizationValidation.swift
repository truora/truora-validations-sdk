//
//  AuthorizationValidation.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 01/07/26.
//

import Foundation

/// Pure validation logic for the authorization screen, extracted from `DataAuthorizationView` so
/// the required-consent rules can be unit tested without instantiating SwiftUI views.
enum AuthorizationValidation {
    /// The decision taken when the primary ("Accept") button is tapped.
    enum PrimaryAction: Equatable {
        /// At least one required consent is still unchecked — surface the validation error.
        case showRequiredError
        /// Every required consent is granted — the host may proceed (e.g. call `verifyStep`).
        case accept
    }

    /// Whether any required consent is still unchecked. Optional consents never block.
    static func hasMissingRequired(in consents: [AuthorizationConsent]) -> Bool {
        consents.contains { $0.required && !$0.checked }
    }

    /// Resolves what should happen when the primary button is tapped for the given `consents`.
    static func primaryAction(for consents: [AuthorizationConsent]) -> PrimaryAction {
        hasMissingRequired(in: consents) ? .showRequiredError : .accept
    }
}
