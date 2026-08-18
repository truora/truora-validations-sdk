//
//  AuthorizationHydration.swift
//  TruoraValidationsSDK
//

import Foundation

/// Pure logic that turns the `enter_authorization` step config plus the fetched
/// consent terms into the ``AuthorizationConsent`` list ``DataAuthorizationView``
/// renders. Ported from the web process-runner (`stores/consent_terms.ts` +
/// `DefaultAuthorizationMessage.vue` + `IntroView.vue`), which is the canonical
/// implementation — resolution rules must stay behaviorally identical.
///
/// **Selection** is verbatim: which variant and language win, and the exact
/// separator between texts, match the web byte for byte — including unparsed
/// Go-template tokens (`{{.company}}`), which the service returns on purpose when
/// the company params are omitted. **Presentation** is not: the web renders the
/// result with `v-html`, so the last step (``buildConsents``) runs the selected
/// copy through ``ConsentMarkup`` to turn the service's HTML into the plain text
/// and single inline link SwiftUI can actually display.
///
/// No I/O happens in this type; ``AuthorizationConsentLoader`` owns the fetches.
enum AuthorizationHydration {
    // MARK: - Constants

    /// Alias keys of ``EnterAuthorizationConfig/customInputs``; also valid
    /// `terms_id` values themselves — the service resolves the aliases when no
    /// concrete id overrides them.
    static let basicTermsAlias = "default-basic"
    static let itemsTermsAlias = "default-items"

    /// Any block name **containing** this fragment marks the process as
    /// having a credit-bureau block (mirrors the web's
    /// `hasCreditBureauVerification` substring match). Names are
    /// server-controlled, hence the substring rather than an enum.
    static let creditBureauNameFragment = "credit_bureau"

    /// Block names that imply a face/liveness validation (mirror of the
    /// web's `verificationNameToValidationTypes` entries mapping to
    /// `face_validation` / `liveness_validation`).
    static let faceOrLivenessBlockTypes: Set<String> = [
        "document_verification_with_face_recognition",
        "document_verification_with_liveness",
        "face_recognition",
        "face_recognition_liveness",
        "government_face_verification"
    ]

    /// Probe order for the face-search terms variant: the first of these present
    /// in `supported_countries` selects `"{C}-face_search"`.
    ///
    /// This deliberately **diverges** from the web's `countryToTermKey`, which
    /// probes `CO`, `MX`, `PT` and `SV`. The backend validates
    /// `supported_countries` keys to exactly `ALL | CO | BR | MX`
    /// (`validateSupportedCountries`), so the web's `PT` and `SV` entries can
    /// never match and a Brazilian process silently falls through to
    /// `"ALL-face_search"` — even though the terms table does define
    /// `"BR-face_search"`. Probing `BR` picks up the variant the web misses; drop
    /// `BR` from this list to restore bug-for-bug parity.
    static let faceSearchCountryProbeOrder = ["CO", "MX", "BR"]

    private static let allCountriesKey = "ALL"
    private static let creditBureauVariant = "ALL-credit_bureau"
    /// The web's exact separator, kept as markup so the concatenation stays
    /// byte-identical; ``ConsentMarkup`` turns it into a blank line at render time.
    private static let faceCreditBureauSeparator = "<br><br>"
    private static let customConsentInputName = "client_authorization"

    // MARK: - Block detection

    /// Whether any block name contains ``creditBureauNameFragment``.
    /// Gates both the items fetch and the items consent.
    static func hasCreditBureauBlock(blockTypes: [String]?) -> Bool {
        blockTypes?.contains { $0.contains(creditBureauNameFragment) } ?? false
    }

    /// Whether any block name is one of ``faceOrLivenessBlockTypes``.
    static func hasFaceOrLivenessValidation(blockTypes: [String]?) -> Bool {
        blockTypes?.contains { faceOrLivenessBlockTypes.contains($0) } ?? false
    }

    // MARK: - Country resolution

    /// Resolves the country whose company info parametrizes the basic consent.
    ///
    /// A single supported country wins outright; otherwise the device country
    /// (uppercased — the caller's ``TruoraProcessResponse/geolocationIpCountry``)
    /// when it is a supported key. The web reference then falls back to the config's *first
    /// key*, but Swift dictionaries are unordered (and the step config already
    /// arrives as `[String: JSONValue]`), so the deterministic substitute is
    /// `"ALL"` when present, else the lexicographically-first key.
    static func resolveUserCountry(
        supportedCountries: [String: CompanyInfo],
        deviceCountry: String?
    ) -> String {
        let keys = supportedCountries.keys.sorted()

        guard keys.count > 1 else {
            return keys.first ?? allCountriesKey
        }

        if let deviceCountry = deviceCountry?.uppercased(), supportedCountries[deviceCountry] != nil {
            return deviceCountry
        }

        if supportedCountries[allCountriesKey] != nil {
            return allCountriesKey
        }

        return keys[0]
    }

    // MARK: - Terms ids

    /// `custom_inputs["default-basic"]`, falling back to the literal alias.
    static func basicTermsId(config: EnterAuthorizationConfig?) -> String {
        config?.customInputs[basicTermsAlias] ?? basicTermsAlias
    }

    /// `custom_inputs["default-items"]`, falling back to the literal alias.
    static func itemsTermsId(config: EnterAuthorizationConfig?) -> String {
        config?.customInputs[itemsTermsAlias] ?? itemsTermsAlias
    }

    // MARK: - Query building

    /// Company params for the **basic** fetch: only the resolved user country's
    /// `{C}.name` / `{C}.nit`, each only when non-empty. Omitting them makes the
    /// service return unparsed templates (still HTTP 200), so an unknown country
    /// or empty config degrades to that, never to an error.
    static func basicQueryItems(config: EnterAuthorizationConfig?, userCountry: String) -> [URLQueryItem] {
        guard let companyInfo = config?.supportedCountries[userCountry] else {
            return []
        }

        return queryItems(country: userCountry, companyInfo: companyInfo)
    }

    /// Company params for the **items** fetch: `{C}.name` / `{C}.nit` for every
    /// supported country, iterated in sorted key order so the request is
    /// deterministic (the service keys parsed variants by country, so order does
    /// not affect the response).
    static func itemsQueryItems(config: EnterAuthorizationConfig?) -> [URLQueryItem] {
        guard let supportedCountries = config?.supportedCountries else {
            return []
        }

        return supportedCountries.keys.sorted().flatMap { country in
            queryItems(country: country, companyInfo: supportedCountries[country])
        }
    }

    private static func queryItems(country: String, companyInfo: CompanyInfo?) -> [URLQueryItem] {
        var items: [URLQueryItem] = []

        if let name = companyInfo?.name, !name.isEmpty {
            items.append(URLQueryItem(name: "\(country).name", value: name))
        }
        if let nit = companyInfo?.nit, !nit.isEmpty {
            items.append(URLQueryItem(name: "\(country).nit", value: nit))
        }

        return items
    }

    // MARK: - Text resolution

    /// Looks up `terms[variant][language]`, trying the full language code first
    /// and falling back to its base language (`es-MX` → `es`). Terms are keyed
    /// `es` / `en` / `pt`.
    ///
    /// The split mirrors the web's `locale.value.split('-')[0]`; `Locale`'s
    /// normalizing accessors are iOS 16+ and this target ships to 13.0. Unlike
    /// the web, the base language is taken with `first` rather than `[0]` —
    /// `"".split(separator: "-")` yields an *empty* array, so subscripting would
    /// trap on an empty `languageCode`, which reaches here from the host-supplied
    /// argument to `TruoraProcessManager.authorizationConsents(languageCode:)`.
    static func text(
        in terms: [String: [String: String]]?,
        variant: String,
        languageCode: String
    ) -> String? {
        guard let languages = terms?[variant] else {
            return nil
        }

        if let exact = languages[languageCode] {
            return exact
        }

        guard let baseLanguage = languageCode.split(separator: "-").first else {
            return nil
        }

        return languages[String(baseLanguage)]
    }

    /// The basic (always-shown) consent copy: a single-variant response yields
    /// that variant regardless of country; otherwise the user country's variant,
    /// falling back to `"ALL"`.
    static func basicText(
        response: ConsentTermsResponse?,
        userCountry: String,
        languageCode: String
    ) -> String? {
        guard let terms = response?.terms else {
            return nil
        }

        let variants = terms.keys
        if variants.count <= 1 {
            return text(in: terms, variant: variants.first ?? allCountriesKey, languageCode: languageCode)
        }

        let countryText = text(in: terms, variant: userCountry, languageCode: languageCode)
        return countryText ?? text(in: terms, variant: allCountriesKey, languageCode: languageCode)
    }

    /// The items (credit-bureau) consent copy.
    ///
    /// The face-search variant is selected by the first of CO, MX, BR present in
    /// `supported_countries` → `"{C}-face_search"`, else `"ALL-face_search"` —
    /// selection is by country presence, not by whether that variant has text,
    /// matching the web's probe. The credit-bureau copy is always the
    /// `"ALL-credit_bureau"` variant.
    ///
    /// With a face/liveness block and both texts present, the result is
    /// `face + "<br><br>" + creditBureau` (the web's exact separator); without a
    /// face/liveness block only the credit-bureau copy is used; otherwise
    /// whichever is non-empty.
    static func itemsText(
        response: ConsentTermsResponse?,
        supportedCountries: [String: CompanyInfo],
        hasFaceOrLiveness: Bool,
        languageCode: String
    ) -> String? {
        let terms = response?.terms
        let creditBureauText = text(in: terms, variant: creditBureauVariant, languageCode: languageCode)

        guard hasFaceOrLiveness else {
            return creditBureauText
        }

        let faceVariant = faceSearchCountryProbeOrder
            .first { supportedCountries[$0] != nil }
            .map { "\($0)-face_search" } ?? "ALL-face_search"
        let faceText = text(in: terms, variant: faceVariant, languageCode: languageCode)

        if let faceText, !faceText.isEmpty, let creditBureauText, !creditBureauText.isEmpty {
            return faceText + faceCreditBureauSeparator + creditBureauText
        }

        if let faceText, !faceText.isEmpty {
            return faceText
        }

        return creditBureauText
    }

    /// The custom consent copy: the `client_authorization` expected input's
    /// description, as authored, when non-empty.
    ///
    /// This is client-written text rather than terms-service markup, so it may
    /// carry a bare URL instead of an anchor. The web wraps that URL via
    /// `updateLinksInText` before rendering; ``ConsentMarkup`` does the equivalent
    /// in ``buildConsents``.
    static func customConsentText(expectedInputs: [TruoraInput]?) -> String? {
        guard
            let description = expectedInputs?
                .first(where: { $0.name == customConsentInputName })?
                .description,
                !description.isEmpty else {
            return nil
        }

        return description
    }

    // MARK: - Consent assembly

    /// Consent ids, stable so hosts and tests can address individual rows.
    enum ConsentId {
        static let basic = "basic"
        static let items = "items"
        static let custom = "custom"
    }

    /// Assembles the final list in render order (basic, items, custom). Every
    /// consent is required — the primary action stays blocked until all are
    /// checked.
    ///
    /// Each text goes through ``ConsentMarkup``, which is what turns the service's
    /// `<a href>` / `<b>` / `<br>` into displayable copy and lifts the inline link
    /// into ``AuthorizationConsent/linkText`` + ``AuthorizationConsent/linkURL``.
    /// Texts that are missing, empty, or render to nothing but markup are skipped.
    static func buildConsents(
        basicText: String?,
        itemsText: String?,
        customText: String?
    ) -> [AuthorizationConsent] {
        let entries = [
            (ConsentId.basic, basicText),
            (ConsentId.items, itemsText),
            (ConsentId.custom, customText)
        ]

        return entries.compactMap { id, consentText in
            guard let consentText, !consentText.isEmpty else {
                return nil
            }

            let rendered = ConsentMarkup.render(consentText)

            guard !rendered.text.isEmpty else {
                return nil
            }

            return AuthorizationConsent(
                id: id,
                text: rendered.text,
                checked: false,
                required: true,
                linkText: rendered.linkText,
                linkURL: rendered.linkURL
            )
        }
    }
}
