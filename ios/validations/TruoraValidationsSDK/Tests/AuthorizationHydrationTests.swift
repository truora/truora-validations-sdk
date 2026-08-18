//
//  AuthorizationHydrationTests.swift
//  TruoraValidationsSDKTests
//

import XCTest
@testable import TruoraValidationsSDK

// MARK: - Authorization Hydration Tests

final class AuthorizationHydrationTests: XCTestCase {
    // MARK: - Fixtures

    private func config(
        countries: [String: CompanyInfo] = [:],
        customInputs: [String: String] = [:]
    ) -> EnterAuthorizationConfig {
        EnterAuthorizationConfig(supportedCountries: countries, customInputs: customInputs)
    }

    private func response(_ terms: [String: [String: String]]) -> ConsentTermsResponse {
        ConsentTermsResponse(terms: terms)
    }

    // MARK: - Block detection

    func testHasCreditBureauBlockMatchesSubstring() {
        XCTAssertTrue(AuthorizationHydration.hasCreditBureauBlock(blockTypes: ["credit_bureau"]))
        XCTAssertTrue(AuthorizationHydration.hasCreditBureauBlock(
            blockTypes: ["document_verification", "credit_bureau_colombia"]
        ))
        XCTAssertFalse(AuthorizationHydration.hasCreditBureauBlock(blockTypes: ["document_verification"]))
        XCTAssertFalse(AuthorizationHydration.hasCreditBureauBlock(blockTypes: []))
        XCTAssertFalse(AuthorizationHydration.hasCreditBureauBlock(blockTypes: nil))
    }

    func testHasFaceOrLivenessValidationMatchesKnownNamesExactly() {
        for name in AuthorizationHydration.faceOrLivenessBlockTypes {
            XCTAssertTrue(AuthorizationHydration.hasFaceOrLivenessValidation(blockTypes: [name]), name)
        }
        XCTAssertFalse(AuthorizationHydration.hasFaceOrLivenessValidation(blockTypes: ["document_verification"]))
        XCTAssertFalse(
            AuthorizationHydration.hasFaceOrLivenessValidation(blockTypes: ["face_recognition_extended"]),
            "Face detection is exact-match, not substring"
        )
        XCTAssertFalse(AuthorizationHydration.hasFaceOrLivenessValidation(blockTypes: nil))
    }

    // MARK: - Country resolution

    func testResolveUserCountrySingleCountryWins() {
        let country = AuthorizationHydration.resolveUserCountry(
            supportedCountries: ["MX": CompanyInfo(name: "Acme")],
            deviceCountry: "CO"
        )
        XCTAssertEqual(country, "MX")
    }

    func testResolveUserCountryUsesUppercasedDeviceCountryWhenSupported() {
        let country = AuthorizationHydration.resolveUserCountry(
            supportedCountries: ["CO": CompanyInfo(name: "Acme"), "MX": CompanyInfo(name: "Acme MX")],
            deviceCountry: "co"
        )
        XCTAssertEqual(country, "CO")
    }

    func testResolveUserCountryPrefersALLWhenDeviceCountryUnsupported() {
        let country = AuthorizationHydration.resolveUserCountry(
            supportedCountries: ["ALL": CompanyInfo(name: "Acme"), "MX": CompanyInfo(name: "Acme MX")],
            deviceCountry: "BR"
        )
        XCTAssertEqual(country, "ALL")
    }

    func testResolveUserCountryFallsBackToFirstSortedKey() {
        let country = AuthorizationHydration.resolveUserCountry(
            supportedCountries: ["MX": CompanyInfo(name: "Acme MX"), "CO": CompanyInfo(name: "Acme CO")],
            deviceCountry: nil
        )
        XCTAssertEqual(country, "CO")
    }

    func testResolveUserCountryEmptyMapResolvesToALL() {
        let country = AuthorizationHydration.resolveUserCountry(supportedCountries: [:], deviceCountry: "CO")
        XCTAssertEqual(country, "ALL")
    }

    // MARK: - Terms ids

    func testTermsIdsUseCustomInputsOverrides() {
        let config = config(customInputs: [
            "default-basic": "DPCTbasic123",
            "default-items": "DPCTitems456"
        ])

        XCTAssertEqual(AuthorizationHydration.basicTermsId(config: config), "DPCTbasic123")
        XCTAssertEqual(AuthorizationHydration.itemsTermsId(config: config), "DPCTitems456")
    }

    func testTermsIdsFallBackToLiteralAliases() {
        XCTAssertEqual(AuthorizationHydration.basicTermsId(config: config()), "default-basic")
        XCTAssertEqual(AuthorizationHydration.itemsTermsId(config: config()), "default-items")
        XCTAssertEqual(AuthorizationHydration.basicTermsId(config: nil), "default-basic")
        XCTAssertEqual(AuthorizationHydration.itemsTermsId(config: nil), "default-items")
    }

    // MARK: - Query building

    func testBasicQueryItemsOnlyResolvedCountry() {
        let config = config(countries: [
            "CO": CompanyInfo(name: "Acme", nit: "900123"),
            "MX": CompanyInfo(name: "Acme MX")
        ])

        let items = AuthorizationHydration.basicQueryItems(config: config, userCountry: "CO")

        XCTAssertEqual(items, [
            URLQueryItem(name: "CO.name", value: "Acme"),
            URLQueryItem(name: "CO.nit", value: "900123")
        ])
    }

    func testBasicQueryItemsOmitsEmptyNameAndNit() {
        let skipping = config(countries: ["CO": CompanyInfo(name: nil, nit: "", skipCompanyInfoCheck: true)])

        XCTAssertEqual(AuthorizationHydration.basicQueryItems(config: skipping, userCountry: "CO"), [])
        XCTAssertEqual(AuthorizationHydration.basicQueryItems(config: skipping, userCountry: "BR"), [])
        XCTAssertEqual(AuthorizationHydration.basicQueryItems(config: nil, userCountry: "CO"), [])
    }

    func testItemsQueryItemsEveryCountrySorted() {
        let config = config(countries: [
            "MX": CompanyInfo(name: "Acme MX"),
            "ALL": CompanyInfo(name: "Acme Global"),
            "CO": CompanyInfo(name: "Acme", nit: "900123")
        ])

        let items = AuthorizationHydration.itemsQueryItems(config: config)

        XCTAssertEqual(items, [
            URLQueryItem(name: "ALL.name", value: "Acme Global"),
            URLQueryItem(name: "CO.name", value: "Acme"),
            URLQueryItem(name: "CO.nit", value: "900123"),
            URLQueryItem(name: "MX.name", value: "Acme MX")
        ])
    }

    // MARK: - Language fallback

    func testTextExactLocaleWinsOverBaseLanguage() {
        let terms = ["ALL": ["es-MX": "Texto MX", "es": "Texto base"]]

        XCTAssertEqual(
            AuthorizationHydration.text(in: terms, variant: "ALL", languageCode: "es-MX"),
            "Texto MX"
        )
    }

    func testTextRegionalVariantFallsBackToBaseLanguage() {
        let terms = ["ALL": ["es": "Texto español", "en": "English text", "pt": "Texto português"]]

        XCTAssertEqual(
            AuthorizationHydration.text(in: terms, variant: "ALL", languageCode: "es-MX"),
            "Texto español"
        )
        XCTAssertEqual(
            AuthorizationHydration.text(in: terms, variant: "ALL", languageCode: "pt-BR"),
            "Texto português"
        )
    }

    /// `"".split(separator: "-")` returns an empty array, so taking the base
    /// language by subscript traps rather than falling back. An empty code
    /// reaches here straight from `authorizationConsents(languageCode:)`, so
    /// this asserts a crash, not just a wrong answer.
    func testTextEmptyLanguageCodeFallsBackInsteadOfTrapping() {
        let terms = ["ALL": ["es": "Texto"]]

        XCTAssertNil(AuthorizationHydration.text(in: terms, variant: "ALL", languageCode: ""))
    }

    func testTextMissingLanguageOrVariantIsNil() {
        let terms = ["ALL": ["es": "Texto"]]

        XCTAssertNil(AuthorizationHydration.text(in: terms, variant: "ALL", languageCode: "fr"))
        XCTAssertNil(AuthorizationHydration.text(in: terms, variant: "CO", languageCode: "es"))
        XCTAssertNil(AuthorizationHydration.text(in: nil, variant: "ALL", languageCode: "es"))
    }

    // MARK: - Basic text

    func testBasicTextSingleVariantWinsRegardlessOfCountry() {
        let response = response(["MX": ["es": "Texto MX"]])

        XCTAssertEqual(
            AuthorizationHydration.basicText(response: response, userCountry: "CO", languageCode: "es"),
            "Texto MX"
        )
    }

    func testBasicTextPrefersUserCountryVariant() {
        let response = response([
            "ALL": ["es": "Texto general"],
            "CO": ["es": "Texto CO"]
        ])

        XCTAssertEqual(
            AuthorizationHydration.basicText(response: response, userCountry: "CO", languageCode: "es"),
            "Texto CO"
        )
    }

    func testBasicTextFallsBackToALLVariant() {
        let response = response([
            "ALL": ["es": "Texto general"],
            "CO": ["es": "Texto CO"]
        ])

        XCTAssertEqual(
            AuthorizationHydration.basicText(response: response, userCountry: "MX", languageCode: "es"),
            "Texto general"
        )
    }

    func testBasicTextNilResponseIsNil() {
        XCTAssertNil(AuthorizationHydration.basicText(response: nil, userCountry: "CO", languageCode: "es"))
    }

    // MARK: - Items text

    private let itemsTerms: [String: [String: String]] = [
        "ALL-credit_bureau": ["es": "Texto centrales"],
        "CO-face_search": ["es": "Texto biométrico CO"],
        "MX-face_search": ["es": "Texto biométrico MX"],
        "ALL-face_search": ["es": "Texto biométrico general"]
    ]

    func testItemsTextConcatenatesFaceAndCreditBureauWithBreaks() {
        let text = AuthorizationHydration.itemsText(
            response: response(itemsTerms),
            supportedCountries: ["CO": CompanyInfo(name: "Acme")],
            hasFaceOrLiveness: true,
            languageCode: "es"
        )

        XCTAssertEqual(text, "Texto biométrico CO<br><br>Texto centrales")
    }

    func testItemsTextProbesFaceCountriesInOrderCOMXBR() {
        let mxText = AuthorizationHydration.itemsText(
            response: response(itemsTerms),
            supportedCountries: ["MX": CompanyInfo(name: "Acme"), "BR": CompanyInfo(name: "Acme BR")],
            hasFaceOrLiveness: true,
            languageCode: "es"
        )
        XCTAssertEqual(mxText, "Texto biométrico MX<br><br>Texto centrales")

        let coWins = AuthorizationHydration.itemsText(
            response: response(itemsTerms),
            supportedCountries: ["MX": CompanyInfo(name: "Acme"), "CO": CompanyInfo(name: "Acme CO")],
            hasFaceOrLiveness: true,
            languageCode: "es"
        )
        XCTAssertEqual(coWins, "Texto biométrico CO<br><br>Texto centrales")
    }

    func testItemsTextUsesALLFaceSearchWhenNoProbeCountrySupported() {
        let text = AuthorizationHydration.itemsText(
            response: response(itemsTerms),
            supportedCountries: ["ALL": CompanyInfo(name: "Acme")],
            hasFaceOrLiveness: true,
            languageCode: "es"
        )

        XCTAssertEqual(text, "Texto biométrico general<br><br>Texto centrales")
    }

    func testItemsTextWithoutFaceOrLivenessIsCreditBureauOnly() {
        let text = AuthorizationHydration.itemsText(
            response: response(itemsTerms),
            supportedCountries: ["CO": CompanyInfo(name: "Acme")],
            hasFaceOrLiveness: false,
            languageCode: "es"
        )

        XCTAssertEqual(text, "Texto centrales")
    }

    func testItemsTextFaceVariantSelectedByCountryPresenceNotText() {
        // BR is the first supported probe country but has no face variant in the
        // response: the probe stops there (country presence decides), so only the
        // credit-bureau copy remains.
        let text = AuthorizationHydration.itemsText(
            response: response(["ALL-credit_bureau": ["es": "Texto centrales"]]),
            supportedCountries: ["BR": CompanyInfo(name: "Acme")],
            hasFaceOrLiveness: true,
            languageCode: "es"
        )

        XCTAssertEqual(text, "Texto centrales")
    }

    func testItemsTextFaceOnlyWhenCreditBureauCopyMissing() {
        let text = AuthorizationHydration.itemsText(
            response: response(["CO-face_search": ["es": "Texto biométrico CO"]]),
            supportedCountries: ["CO": CompanyInfo(name: "Acme")],
            hasFaceOrLiveness: true,
            languageCode: "es"
        )

        XCTAssertEqual(text, "Texto biométrico CO")
    }

    // MARK: - Custom consent text

    func testCustomConsentTextReadsClientAuthorizationDescription() {
        let inputs = [
            TruoraInput(type: "checkbox", name: "authorization", description: "ignored"),
            TruoraInput(type: "checkbox", name: "client_authorization", description: "Acepto los términos de Acme")
        ]

        XCTAssertEqual(
            AuthorizationHydration.customConsentText(expectedInputs: inputs),
            "Acepto los términos de Acme"
        )
    }

    func testCustomConsentTextEmptyOrMissingIsNil() {
        XCTAssertNil(AuthorizationHydration.customConsentText(
            expectedInputs: [TruoraInput(type: "checkbox", name: "client_authorization", description: "")]
        ))
        XCTAssertNil(AuthorizationHydration.customConsentText(
            expectedInputs: [TruoraInput(type: "checkbox", name: "client_authorization")]
        ))
        XCTAssertNil(AuthorizationHydration.customConsentText(
            expectedInputs: [TruoraInput(type: "checkbox", name: "authorization", description: "text")]
        ))
        XCTAssertNil(AuthorizationHydration.customConsentText(expectedInputs: nil))
    }

    // MARK: - Consent assembly

    func testBuildConsentsFullMatrix() {
        let all = AuthorizationHydration.buildConsents(
            basicText: "Basic",
            itemsText: "Items",
            customText: "Custom"
        )
        XCTAssertEqual(all.map(\.id), ["basic", "items", "custom"])
        XCTAssertEqual(all.map(\.text), ["Basic", "Items", "Custom"])
        XCTAssertTrue(all.allSatisfy(\.required))
        XCTAssertTrue(all.allSatisfy { !$0.checked })
        XCTAssertTrue(all.allSatisfy { $0.linkText == nil && $0.linkURL == nil })

        let basicOnly = AuthorizationHydration.buildConsents(basicText: "Basic", itemsText: nil, customText: nil)
        XCTAssertEqual(basicOnly.map(\.id), ["basic"])

        let noCustom = AuthorizationHydration.buildConsents(basicText: "Basic", itemsText: "Items", customText: "")
        XCTAssertEqual(noCustom.map(\.id), ["basic", "items"])

        XCTAssertTrue(AuthorizationHydration.buildConsents(basicText: nil, itemsText: nil, customText: nil).isEmpty)
    }

    /// Selection stays verbatim (the `{{.company}}` token survives), presentation
    /// does not: the service's markup is rendered before it reaches the view.
    func testBuildConsentsRendersServiceMarkup() throws {
        let markup = "Autorizo a {{.company}} — ver <a href=\"https://acme.co/terms\">términos</a>.<br><br>Fin."

        let consents = AuthorizationHydration.buildConsents(basicText: markup, itemsText: nil, customText: nil)

        let consent = try XCTUnwrap(consents.first)
        XCTAssertEqual(consent.text, "Autorizo a {{.company}} — ver términos.\n\nFin.")
        XCTAssertEqual(consent.linkText, "términos")
        XCTAssertEqual(consent.linkURL, URL(string: "https://acme.co/terms"))
    }

    /// Copy that is nothing but markup renders to an empty string, which must not
    /// become a required-but-blank checkbox the user can never understand.
    func testBuildConsentsSkipsCopyThatRendersEmpty() {
        let consents = AuthorizationHydration.buildConsents(
            basicText: "Basic",
            itemsText: "<br><br>",
            customText: nil
        )

        XCTAssertEqual(consents.map(\.id), ["basic"])
    }

    // MARK: - Config decoding from the step's JSONValue bag

    func testEnterAuthorizationConfigDecodesFromConfigValues() throws {
        let configValues: TruoraBlockConfigValues = [
            "supported_countries": .object([
                "CO": .object([
                    "name": .string("Acme"),
                    "nit": .string("900123")
                ]),
                "ALL": .object([
                    "skip_company_info_check": .bool(true)
                ])
            ]),
            "custom_inputs": .object([
                "default-basic": .string("DPCTbasic123")
            ])
        ]

        let config = try XCTUnwrap(EnterAuthorizationConfig(configValues: configValues))

        XCTAssertEqual(config.supportedCountries["CO"], CompanyInfo(name: "Acme", nit: "900123"))
        XCTAssertEqual(config.supportedCountries["ALL"], CompanyInfo(skipCompanyInfoCheck: true))
        XCTAssertEqual(config.customInputs, ["default-basic": "DPCTbasic123"])
    }

    func testEnterAuthorizationConfigDefaultsMissingKeys() throws {
        let config = try XCTUnwrap(EnterAuthorizationConfig(configValues: [:]))

        XCTAssertTrue(config.supportedCountries.isEmpty)
        XCTAssertTrue(config.customInputs.isEmpty)
    }

    func testEnterAuthorizationConfigNilOrGarbageConfigIsNil() {
        XCTAssertNil(EnterAuthorizationConfig(configValues: nil))
        XCTAssertNil(EnterAuthorizationConfig(configValues: ["supported_countries": .string("garbage")]))
    }
}
