//
//  InvoiceCountryContentTests.swift
//  TruoraValidationsSDKTests
//
//  Created by Truora on 22/04/26.
//

import XCTest
@testable import TruoraValidationsSDK

final class InvoiceCountryContentTests: XCTestCase {
    // MARK: - init(country:)

    func testInit_mx_returnsMXCase() {
        XCTAssertEqual(InvoiceCountryContent(country: "MX"), .mx)
    }

    func testInit_co_returnsCOCase() {
        XCTAssertEqual(InvoiceCountryContent(country: "CO"), .co)
    }

    func testInit_lowercaseMx_returnsMXCase() {
        XCTAssertEqual(InvoiceCountryContent(country: "mx"), .mx)
    }

    func testInit_lowercaseCo_returnsCOCase() {
        XCTAssertEqual(InvoiceCountryContent(country: "co"), .co)
    }

    func testInit_mixedCase_returnsExpectedCase() {
        XCTAssertEqual(InvoiceCountryContent(country: "Mx"), .mx)
        XCTAssertEqual(InvoiceCountryContent(country: "Co"), .co)
    }

    func testInit_unsupportedCountry_defaultsToMX() {
        XCTAssertEqual(InvoiceCountryContent(country: "US"), .mx)
        XCTAssertEqual(InvoiceCountryContent(country: "BR"), .mx)
        XCTAssertEqual(InvoiceCountryContent(country: ""), .mx)
    }

    // MARK: - MX vs CO property differences

    func testMX_showsValidityPeriod_true() {
        XCTAssertTrue(InvoiceCountryContent.mx.showsValidityPeriod)
    }

    func testCO_showsValidityPeriod_false() {
        XCTAssertFalse(InvoiceCountryContent.co.showsValidityPeriod)
    }

    func testMX_providerLogos_matchExpected() {
        let names = InvoiceCountryContent.mx.providerLogos.map(\.name)
        XCTAssertEqual(
            names,
            ["mx_invoice_cfe_logo", "mx_invoice_telmex_logo", "mx_invoice_totalplay_logo"]
        )
    }

    func testCO_providerLogos_matchExpected() {
        let names = InvoiceCountryContent.co.providerLogos.map(\.name)
        XCTAssertEqual(
            names,
            ["co_invoice_alcanos_logo", "co_invoice_gases_oriente_logo", "co_invoice_metrogas_logo"]
        )
    }

    func testMX_logoSpacing_is24pt() {
        XCTAssertEqual(InvoiceCountryContent.mx.logoSpacing, 24)
    }

    func testCO_logoSpacing_is20pt() {
        XCTAssertEqual(InvoiceCountryContent.co.logoSpacing, 20)
    }

    func testMX_referenceImages_matchExpected() {
        XCTAssertEqual(
            InvoiceCountryContent.mx.referenceImageNames,
            ["mx_invoice_cfe_front", "mx_invoice_telmex_front", "mx_invoice_totalplay_front"]
        )
    }

    func testCO_referenceImages_matchExpected() {
        XCTAssertEqual(
            InvoiceCountryContent.co.referenceImageNames,
            ["co_invoice_alcanos_front", "co_invoice_gases_oriente_front", "co_invoice_metrogas_front"]
        )
    }

    // MARK: - Localization keys (non-empty + per-country divergence)

    func testMX_titleKey_isNonEmpty() {
        XCTAssertFalse(InvoiceCountryContent.mx.titleKey.isEmpty)
    }

    func testCO_titleKey_isNonEmpty() {
        XCTAssertFalse(InvoiceCountryContent.co.titleKey.isEmpty)
    }

    func testMX_subtitleParts_areNonEmpty() {
        XCTAssertFalse(InvoiceCountryContent.mx.subtitlePrefixKey.isEmpty)
        XCTAssertFalse(InvoiceCountryContent.mx.validityPeriodKey.isEmpty)
        XCTAssertFalse(InvoiceCountryContent.mx.subtitleSuffixKey.isEmpty)
    }

    func testCO_subtitleKey_isNonEmpty() {
        XCTAssertFalse(InvoiceCountryContent.co.subtitleKey.isEmpty)
    }

    func testFeedback_missingTextTitle_keysDifferPerCountry() {
        XCTAssertNotEqual(
            InvoiceCountryContent.mx.feedbackMissingTextTitleKey,
            InvoiceCountryContent.co.feedbackMissingTextTitleKey
        )
    }

    func testFeedback_notFoundTitle_keysDifferPerCountry() {
        XCTAssertNotEqual(
            InvoiceCountryContent.mx.feedbackNotFoundTitleKey,
            InvoiceCountryContent.co.feedbackNotFoundTitleKey
        )
    }

    func testFeedback_expiredTitle_keysDifferPerCountry() {
        XCTAssertNotEqual(
            InvoiceCountryContent.mx.feedbackExpiredTitleKey,
            InvoiceCountryContent.co.feedbackExpiredTitleKey
        )
    }

    func testFeedback_tipCorners_keysDifferPerCountry() {
        XCTAssertNotEqual(
            InvoiceCountryContent.mx.feedbackTipCornersKey,
            InvoiceCountryContent.co.feedbackTipCornersKey
        )
    }

    func testFeedback_tipGlare_keysDifferPerCountry() {
        XCTAssertNotEqual(
            InvoiceCountryContent.mx.feedbackTipGlareKey,
            InvoiceCountryContent.co.feedbackTipGlareKey
        )
    }
}
