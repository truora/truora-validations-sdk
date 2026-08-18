//
//  TruoraProcessEnvironment.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 30/07/26.
//

import Foundation

/// Backend environment for the Digital Identity Processes API.
///
/// Mirrors KMP `DIEnvironment`: two hosts per environment, with the same literal
/// values so iOS and Android point at the same backends.
///
/// **Internal on purpose.** Staging is a QA affordance, not a supported knob:
/// the public builder never surfaces an environment and every public entry point
/// keeps resolving to ``production``.
enum TruoraProcessEnvironment {
    case production
    case staging

    /// Identity API root through `/v1`. Mirrors KMP `DIEnvironment.baseUrl`.
    var baseUrl: String {
        switch self {
        case .production:
            "https://api.identity.truora.com/v1"
        case .staging:
            "https://api.identity.truorastaging.com/v1"
        }
    }

    /// Account API root through `/v1`, used for consent-terms. Mirrors KMP
    /// `DIEnvironment.consentsBaseUrl`; carried here for the consents client iOS
    /// does not have yet, so both hosts move together when an environment is added.
    var consentsBaseUrl: String {
        switch self {
        case .production:
            "https://api.account.truora.com/v1"
        case .staging:
            "https://api.account.truorastaging.com/v1"
        }
    }

    /// Processes collection under ``baseUrl`` — the host ``TruoraProcessAPIClient``
    /// targets. Matches KMP, which appends `/processes` to ``baseUrl``.
    var processesBaseUrl: String {
        "\(baseUrl)/processes"
    }
}
