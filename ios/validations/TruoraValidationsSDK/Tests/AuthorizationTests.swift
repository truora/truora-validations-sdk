//
//  AuthorizationTests.swift
//  SDKTests
//
//  Created by Truora on 01/07/26.
//

import XCTest
@testable import TruoraValidationsSDK

@MainActor final class AuthorizationTests: XCTestCase {
    // MARK: - AuthorizationConsent model

    func testConsentDefaults() {
        let consent = AuthorizationConsent(id: "biometric", text: "Authorize biometrics")

        XCTAssertEqual(consent.id, "biometric")
        XCTAssertFalse(consent.checked, "Consents start unchecked so the host owns the initial state")
        XCTAssertTrue(consent.required, "Consents are required by default")
        XCTAssertNil(consent.linkText)
        XCTAssertNil(consent.linkURL)
    }

    func testConsentIsIdentifiableAndEquatable() {
        let url = URL(string: "https://truora.com/policy")
        let checked = AuthorizationConsent(
            id: "x", text: "A", checked: true, required: false, linkText: "A", linkURL: url
        )
        let sameChecked = AuthorizationConsent(
            id: "x", text: "A", checked: true, required: false, linkText: "A", linkURL: url
        )
        let unchecked = AuthorizationConsent(
            id: "x", text: "A", checked: false, required: false, linkText: "A", linkURL: url
        )

        XCTAssertEqual(checked, sameChecked)
        XCTAssertNotEqual(checked, unchecked, "A change in checked state must produce a distinct value")
        XCTAssertEqual(checked.id, "x")
    }

    // MARK: - Required validation state

    func testHasMissingRequiredWhenRequiredConsentUnchecked() {
        let consents = [
            AuthorizationConsent(id: "1", text: "Required", checked: false, required: true)
        ]
        XCTAssertTrue(AuthorizationValidation.hasMissingRequired(in: consents))
    }

    func testHasNoMissingRequiredWhenAllRequiredChecked() {
        let consents = [
            AuthorizationConsent(id: "1", text: "Required", checked: true, required: true),
            AuthorizationConsent(id: "2", text: "Also required", checked: true, required: true)
        ]
        XCTAssertFalse(AuthorizationValidation.hasMissingRequired(in: consents))
    }

    func testOptionalUncheckedConsentDoesNotBlock() {
        let consents = [
            AuthorizationConsent(id: "1", text: "Required", checked: true, required: true),
            AuthorizationConsent(id: "2", text: "Optional", checked: false, required: false)
        ]
        XCTAssertFalse(
            AuthorizationValidation.hasMissingRequired(in: consents),
            "An unchecked optional consent must not count as missing"
        )
    }

    func testEmptyConsentsHasNoMissingRequired() {
        XCTAssertFalse(AuthorizationValidation.hasMissingRequired(in: []))
    }

    // MARK: - Primary action decision

    func testPrimaryActionShowsErrorWhenRequiredMissing() {
        let consents = [
            AuthorizationConsent(id: "1", text: "Required", checked: false, required: true),
            AuthorizationConsent(id: "2", text: "Optional", checked: false, required: false)
        ]
        XCTAssertEqual(AuthorizationValidation.primaryAction(for: consents), .showRequiredError)
    }

    func testPrimaryActionAcceptsWhenAllRequiredGranted() {
        let consents = [
            AuthorizationConsent(id: "1", text: "Required", checked: true, required: true),
            AuthorizationConsent(id: "2", text: "Optional", checked: false, required: false)
        ]
        XCTAssertEqual(AuthorizationValidation.primaryAction(for: consents), .accept)
    }

    // MARK: - Consent toggle contract

    /// The view is a controlled component: it emits `(id, newChecked)` and the host applies it.
    /// This exercises that host-side reducer to lock in the toggle contract.
    func testTogglingConsentUpdatesOnlyTargetById() {
        var consents = [
            AuthorizationConsent(id: "1", text: "One", checked: true),
            AuthorizationConsent(id: "2", text: "Two", checked: false)
        ]
        // Row "1" is already granted; row "2" is the last missing required consent.
        XCTAssertEqual(AuthorizationValidation.primaryAction(for: consents), .showRequiredError)

        // Simulate the onConsentToggle callback the view emits for row "2".
        let toggledId = "2"
        let newValue = true
        if let index = consents.firstIndex(where: { $0.id == toggledId }) {
            consents[index].checked = newValue
        }

        XCTAssertTrue(consents[0].checked, "Untouched rows keep their state")
        XCTAssertTrue(consents[1].checked, "Only the toggled row changes")
        XCTAssertEqual(
            AuthorizationValidation.primaryAction(for: consents),
            .accept,
            "Once the last required consent is granted the primary action accepts"
        )
    }

    // MARK: - Link event data

    func testConsentCarriesLinkPayloadForTapEvents() {
        let url = URL(string: "https://truora.com/privacy")
        let consent = AuthorizationConsent(
            id: "biometric",
            text: "I authorize my biometric data",
            linkText: "biometric data",
            linkURL: url
        )

        XCTAssertEqual(consent.linkText, "biometric data")
        XCTAssertEqual(consent.linkURL, url, "The URL forwarded to onConsentLinkTap must round-trip on the model")
    }
}
