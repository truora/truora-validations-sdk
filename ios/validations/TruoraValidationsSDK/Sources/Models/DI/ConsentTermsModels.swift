//
//  ConsentTermsModels.swift
//  TruoraValidationsSDK
//

import Foundation

// MARK: - Consent Terms Response

/// Response from the Account API consent-terms endpoint
/// (`GET {ACCOUNT_URL}/v1/consent-terms/{terms_id}`).
///
/// The SDK always sends the `terms=true` query parameter, so ``terms`` is keyed
/// by variant first: variant (`"ALL"`, `"CO"`, `"ALL-credit_bureau"`,
/// `"MX-face_search"`, …) → language (`"es"` / `"en"` / `"pt"`) → copy.
///
/// When the request omits every `{COUNTRY}.name` / `{COUNTRY}.nit` parameter the
/// service still answers 200, but with the stored Go templates unparsed — texts
/// containing `{{.company}}` tokens. That is a valid response, not an error; the
/// copy flows through verbatim.
struct ConsentTermsResponse: Codable, Equatable, Sendable {
    let clientId: String?
    let termsId: String?
    let version: String?
    let creationDate: String?
    /// Variant → language → consent copy.
    let terms: [String: [String: String]]?

    init(
        clientId: String? = nil,
        termsId: String? = nil,
        version: String? = nil,
        creationDate: String? = nil,
        terms: [String: [String: String]]? = nil
    ) {
        self.clientId = clientId
        self.termsId = termsId
        self.version = version
        self.creationDate = creationDate
        self.terms = terms
    }

    private enum CodingKeys: String, CodingKey {
        case clientId = "client_id"
        case termsId = "terms_id"
        case version
        case creationDate = "creation_date"
        case terms
    }
}

// MARK: - Enter Authorization Config

/// Company information for one country inside the `enter_authorization` step
/// config (`shared/models.CompanyInfo` on the backend).
struct CompanyInfo: Codable, Equatable, Sendable {
    /// Company display name. Absent when ``skipCompanyInfoCheck`` is set.
    let name: String?
    /// Tax id. The backend requires it only for `CO`.
    let nit: String?
    let skipCompanyInfoCheck: Bool

    init(name: String? = nil, nit: String? = nil, skipCompanyInfoCheck: Bool = false) {
        self.name = name
        self.nit = nit
        self.skipCompanyInfoCheck = skipCompanyInfoCheck
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        nit = try container.decodeIfPresent(String.self, forKey: .nit)
        skipCompanyInfoCheck = try container.decodeIfPresent(Bool.self, forKey: .skipCompanyInfoCheck) ?? false
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case nit
        case skipCompanyInfoCheck = "skip_company_info_check"
    }
}

/// Typed view of ``TruoraStep/config`` for the `enter_authorization` step
/// (`EnterAuthorizationVerificationConfig` on the backend).
struct EnterAuthorizationConfig: Codable, Equatable, Sendable {
    /// Country → company info. Keys are `ALL | CO | BR | MX` (backend-validated).
    let supportedCountries: [String: CompanyInfo]
    /// Term alias (`default-basic` / `default-items`) → concrete terms id.
    /// Server-controlled: the backend resets it on every write, so read it and
    /// fall back to the literal alias when a key is absent.
    let customInputs: [String: String]

    init(supportedCountries: [String: CompanyInfo] = [:], customInputs: [String: String] = [:]) {
        self.supportedCountries = supportedCountries
        self.customInputs = customInputs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        supportedCountries = try container.decodeIfPresent(
            [String: CompanyInfo].self, forKey: .supportedCountries
        ) ?? [:]
        customInputs = try container.decodeIfPresent([String: String].self, forKey: .customInputs) ?? [:]
    }

    /// Decodes the step's untyped config bag by round-tripping it through
    /// `Codable`. Returns `nil` when the config is absent or does not decode —
    /// hydration then behaves as "no supported countries, no overrides".
    init?(configValues: TruoraBlockConfigValues?) {
        guard
            let configValues,
            let data = try? JSONEncoder().encode(configValues),
            let decoded = try? JSONDecoder().decode(EnterAuthorizationConfig.self, from: data) else {
            return nil
        }

        self = decoded
    }

    private enum CodingKeys: String, CodingKey {
        case supportedCountries = "supported_countries"
        case customInputs = "custom_inputs"
    }
}
