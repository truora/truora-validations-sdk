//
//  DocumentValidationConfigTests.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 05/02/26.
//

import XCTest
@testable import TruoraValidationsSDK

@MainActor final class DocumentValidationConfigTests: XCTestCase {
    var sut: Document!

    override func setUp() {
        super.setUp()
        sut = Document()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Finish View Configuration Tests

    func testFinishViewConfigDefaultIsNil() {
        XCTAssertNil(sut.finishViewConfig, "Finish view config should be nil by default")
    }

    func testSetFinishViewConfiguration() {
        // Given
        let config = FinishViewConfiguration(success: .show, failure: .hide)

        // When
        let result = sut.setFinishViewConfiguration(config)

        // Then
        XCTAssertNotNil(sut.finishViewConfig, "Should set finish view config")
        XCTAssertEqual(sut.finishViewConfig?.success, .show)
        XCTAssertEqual(sut.finishViewConfig?.failure, .hide)
        XCTAssertTrue(result === sut, "Should return self for chaining")
    }

    func testSetFinishViewConfigurationImplicitlyEnablesWaitForResults() {
        // Given
        _ = sut.waitForResults(false)
        XCTAssertFalse(sut.waitForResults, "Precondition: wait for results disabled")

        // When
        _ = sut.setFinishViewConfiguration(FinishViewConfiguration(success: .hide, failure: .hide))

        // Then
        XCTAssertTrue(sut.waitForResults, "Should implicitly enable wait for results")
    }

    func testWaitForResultsFalseWithoutFinishViewConfig_succeeds() {
        // When — disabling waitForResults without finishViewConfig is valid
        _ = sut.waitForResults(false)

        // Then
        XCTAssertFalse(sut.waitForResults)
        XCTAssertNil(sut.finishViewConfig)
    }

    // Note: waitForResults(false) after setFinishViewConfiguration
    // triggers a preconditionFailure, which cannot be tested with XCTest
    // since it terminates the process. The precondition protects against
    // developer misconfiguration at the call site.
    // ValidationConfig.setValidation also throws invalidConfiguration as a
    // defense-in-depth check, but that path is unreachable through the
    // public builder API since the precondition fires first.

    // MARK: - Passport Autocapture (Public API)

    // setDocumentType("passport") silently disables _useAutocapture but keeps
    // _didExplicitlyEnableAutocapture so validateAutocaptureConfig can throw
    // a catchable TruoraException at start time.
    //
    // useAutocapture(true) on a passport document keeps autocapture disabled
    // (enabled && !isPassport) but records the explicit intent.

    func testPassportWithDefaultAutocapture_disablesAutocapture() {
        // No explicit useAutocapture call — setDocumentType silently disables it.
        _ = sut.setDocumentType("passport")

        XCTAssertEqual(sut.documentType, "passport")
        XCTAssertFalse(sut.useAutocapture, "Autocapture should be disabled for passport")
        XCTAssertFalse(sut.didExplicitlyEnableAutocapture)
    }

    func testPassportWithAutocaptureDisabled_succeeds() {
        _ = sut
            .setDocumentType("passport")
            .useAutocapture(false)

        XCTAssertEqual(sut.documentType, "passport")
        XCTAssertFalse(sut.useAutocapture)
        XCTAssertFalse(sut.didExplicitlyEnableAutocapture)
    }

    func testUseAutocaptureTrueThenPassport_disablesButKeepsExplicitFlag() {
        // Developer misconfiguration: useAutocapture(true) then passport.
        // No crash — validateAutocaptureConfig will throw at start time instead.
        _ = sut
            .useAutocapture(true)
            .setDocumentType("passport")

        XCTAssertEqual(sut.documentType, "passport")
        XCTAssertFalse(sut.useAutocapture, "Autocapture should be disabled for passport")
        XCTAssertTrue(sut.didExplicitlyEnableAutocapture, "Explicit flag preserved for validation")
    }

    func testPassportThenUseAutocaptureTrue_disablesButKeepsExplicitFlag() {
        // Developer misconfiguration: passport then useAutocapture(true).
        // No crash — validateAutocaptureConfig will throw at start time instead.
        _ = sut
            .setDocumentType("passport")
            .useAutocapture(true)

        XCTAssertEqual(sut.documentType, "passport")
        XCTAssertFalse(sut.useAutocapture, "Autocapture should remain disabled for passport")
        XCTAssertTrue(sut.didExplicitlyEnableAutocapture, "Explicit flag preserved for validation")
    }

    func testPassportWithAutocaptureEnabledThenDisabled_succeeds() {
        // useAutocapture(false) resets the explicit flag, so passport is fine.
        _ = sut
            .useAutocapture(true)
            .useAutocapture(false)
            .setDocumentType("passport")

        XCTAssertEqual(sut.documentType, "passport")
        XCTAssertFalse(sut.useAutocapture)
        XCTAssertFalse(sut.didExplicitlyEnableAutocapture)
    }

    func testNonPassportWithAutocapture_succeeds() {
        _ = sut
            .setDocumentType("national-id")
            .useAutocapture(true)

        XCTAssertEqual(sut.documentType, "national-id")
        XCTAssertTrue(sut.useAutocapture)
    }

    // MARK: - applyRuntimeDocumentType (Internal / Presenter API)

    func testApplyRuntimeDocumentType_passport_disablesAutocaptureAndResetsFlag() {
        // Simulates the document selection presenter flow: the developer
        // enabled autocapture via the Builder, and the user picks passport.
        _ = sut.useAutocapture(true)
        XCTAssertTrue(sut.didExplicitlyEnableAutocapture, "Precondition")

        _ = sut.applyRuntimeDocumentType("passport")

        XCTAssertEqual(sut.documentType, "passport")
        XCTAssertFalse(sut.useAutocapture, "Autocapture should be disabled for passport")
        XCTAssertFalse(sut.didExplicitlyEnableAutocapture, "Flag should be reset for runtime selection")
    }

    func testApplyRuntimeDocumentType_nonPassport_keepsAutocapture() {
        // Non-passport runtime selection should not change autocapture settings.
        _ = sut.useAutocapture(true)

        _ = sut.applyRuntimeDocumentType("national-id")

        XCTAssertEqual(sut.documentType, "national-id")
        XCTAssertTrue(sut.useAutocapture)
        XCTAssertTrue(sut.didExplicitlyEnableAutocapture)
    }

    func testApplyRuntimeDocumentType_passportWithoutExplicitAutocapture_succeeds() {
        // No prior useAutocapture call — the default flow.
        _ = sut.applyRuntimeDocumentType("passport")

        XCTAssertEqual(sut.documentType, "passport")
        XCTAssertFalse(sut.useAutocapture)
        XCTAssertFalse(sut.didExplicitlyEnableAutocapture)
    }

    func testMethodChainingWithFinishViewConfig() {
        // Given
        let finishConfig = FinishViewConfiguration(success: .hide, failure: .show)

        // When
        let result =
            sut
                .setCountry("CO")
                .setDocumentType("national-id")
                .setFinishViewConfiguration(finishConfig)
                .setTimeout(90)

        // Then
        XCTAssertTrue(result === sut, "Should support method chaining")
        XCTAssertEqual(sut.country, "CO")
        XCTAssertEqual(sut.documentType, "national-id")
        XCTAssertNotNil(sut.finishViewConfig)
        XCTAssertTrue(sut.waitForResults)
        XCTAssertEqual(sut.timeout, 90)
    }

    // MARK: - setCountry Tests (Pre-selection)

    func testCountryDefaultIsEmpty() {
        XCTAssertTrue(sut.country.isEmpty, "Country should be empty by default")
        XCTAssertFalse(sut.hasSingleCountry)
    }

    func testSetCountry_setsValueAndHasSingleCountry() {
        _ = sut.setCountry("PE")

        XCTAssertEqual(sut.country, "PE")
        XCTAssertTrue(sut.hasSingleCountry)
    }

    // MARK: - setDocumentType Tests (Pre-selection)

    func testDocumentTypeDefaultIsEmpty() {
        XCTAssertTrue(sut.documentType.isEmpty, "Document type should be empty by default")
        XCTAssertFalse(sut.hasSingleDocumentType)
    }

    func testSetDocumentType_setsValueAndHasSingleDocumentType() {
        _ = sut.setDocumentType("national-id")

        XCTAssertEqual(sut.documentType, "national-id")
        XCTAssertTrue(sut.hasSingleDocumentType)
    }

    // MARK: - Allowed Countries List Tests

    func testAllowedCountriesListDefaultIsEmpty() {
        XCTAssertTrue(sut.allowedCountriesList.isEmpty, "Allowed countries list should be empty by default")
    }

    func testSetAllowedCountriesWithSingleValue() {
        _ = sut.setAllowedCountries("PE")

        XCTAssertEqual(sut.allowedCountries, "PE")
        XCTAssertEqual(sut.allowedCountriesList, ["PE"])
    }

    func testSetAllowedCountriesWithMultipleValues() {
        _ = sut.setAllowedCountries("PE,CO,MX")

        XCTAssertEqual(sut.allowedCountries, "PE,CO,MX")
        XCTAssertEqual(sut.allowedCountriesList, ["PE", "CO", "MX"])
    }

    func testSetAllowedCountriesWithSpaces() {
        _ = sut.setAllowedCountries("PE, CO, MX")

        XCTAssertEqual(sut.allowedCountriesList, ["PE", "CO", "MX"])
    }

    // MARK: - Allowed Document Types List Tests

    func testAllowedDocumentTypesListDefaultIsEmpty() {
        XCTAssertTrue(sut.allowedDocumentTypesList.isEmpty, "Allowed document types list should be empty by default")
    }

    func testSetAllowedDocumentTypesWithSingleValue() {
        _ = sut.setAllowedDocumentTypes("national-id")

        XCTAssertEqual(sut.allowedDocumentTypes, "national-id")
        XCTAssertEqual(sut.allowedDocumentTypesList, ["national-id"])
    }

    func testSetAllowedDocumentTypesWithMultipleValues() {
        _ = sut.setAllowedDocumentTypes("national-id,passport,foreign-id")

        XCTAssertEqual(sut.allowedDocumentTypes, "national-id,passport,foreign-id")
        XCTAssertEqual(sut.allowedDocumentTypesList, ["national-id", "passport", "foreign-id"])
    }

    func testSetAllowedDocumentTypesWithSpaces() {
        _ = sut.setAllowedDocumentTypes("national-id, passport, foreign-id")

        XCTAssertEqual(sut.allowedDocumentTypesList, ["national-id", "passport", "foreign-id"])
    }

    // MARK: - Method Chaining with Allowed Values

    func testMethodChainingWithAllowedValues() {
        let result = sut
            .setCountry("PE")
            .setAllowedCountries("PE,CO,MX")
            .setDocumentType("national-id")
            .setAllowedDocumentTypes("national-id,passport")
            .waitForResults(true)

        XCTAssertTrue(result === sut, "Should support method chaining")
        XCTAssertEqual(sut.country, "PE")
        XCTAssertEqual(sut.allowedCountriesList, ["PE", "CO", "MX"])
        XCTAssertEqual(sut.documentType, "national-id")
        XCTAssertEqual(sut.allowedDocumentTypesList, ["national-id", "passport"])
        XCTAssertTrue(sut.waitForResults)
    }

    func testPreselectionAndFilteringTogether() {
        _ = sut
            .setCountry("CO")
            .setAllowedCountries("CO,MX,PE")
            .setDocumentType("national-id")
            .setAllowedDocumentTypes("national-id,foreign-id")

        XCTAssertTrue(sut.hasSingleCountry, "Should have pre-selected country")
        XCTAssertTrue(sut.hasSingleDocumentType, "Should have pre-selected document type")
        XCTAssertEqual(sut.allowedCountriesList.count, 3, "Should have 3 allowed countries")
        XCTAssertEqual(sut.allowedDocumentTypesList.count, 2, "Should have 2 allowed document types")
    }

    // MARK: - Single Allowed Tests

    func testHasSingleAllowedCountry_withOneValue_returnsTrue() {
        _ = sut.setAllowedCountries("CO")

        XCTAssertTrue(sut.hasSingleAllowedCountry)
    }

    func testHasSingleAllowedCountry_withMultipleValues_returnsFalse() {
        _ = sut.setAllowedCountries("CO,MX")

        XCTAssertFalse(sut.hasSingleAllowedCountry)
    }

    func testHasSingleAllowedCountry_withEmptyValue_returnsFalse() {
        XCTAssertFalse(sut.hasSingleAllowedCountry)
    }

    func testHasSingleAllowedDocumentType_withOneValue_returnsTrue() {
        _ = sut.setAllowedDocumentTypes("national-id")

        XCTAssertTrue(sut.hasSingleAllowedDocumentType)
    }

    func testHasSingleAllowedDocumentType_withMultipleValues_returnsFalse() {
        _ = sut.setAllowedDocumentTypes("national-id,passport")

        XCTAssertFalse(sut.hasSingleAllowedDocumentType)
    }

    func testHasSingleAllowedDocumentType_withEmptyValue_returnsFalse() {
        XCTAssertFalse(sut.hasSingleAllowedDocumentType)
    }

    // MARK: - Effective Preselection Priority Tests

    func testEffectivePreselectedCountry_allowedHasPriority() {
        _ = sut
            .setCountry("MX")
            .setAllowedCountries("CO")

        XCTAssertEqual(sut.effectivePreselectedCountry, "CO", "allowedCountries should have priority")
    }

    func testEffectivePreselectedCountry_fallsBackToCountry() {
        _ = sut.setCountry("MX")

        XCTAssertEqual(sut.effectivePreselectedCountry, "MX", "Should fallback to country when allowedCountries is empty")
    }

    func testEffectivePreselectedCountry_returnsNilWhenMultipleAllowed() {
        _ = sut.setAllowedCountries("CO,MX")

        XCTAssertNil(sut.effectivePreselectedCountry, "Should return nil when multiple countries allowed")
    }

    func testEffectivePreselectedCountry_returnsNilWhenBothEmpty() {
        XCTAssertNil(sut.effectivePreselectedCountry)
    }

    func testEffectivePreselectedDocumentType_allowedHasPriority() {
        _ = sut
            .setDocumentType("passport")
            .setAllowedDocumentTypes("national-id")

        XCTAssertEqual(sut.effectivePreselectedDocumentType, "national-id", "allowedDocumentTypes should have priority")
    }

    func testEffectivePreselectedDocumentType_fallsBackToDocumentType() {
        _ = sut.setDocumentType("passport")

        XCTAssertEqual(sut.effectivePreselectedDocumentType, "passport", "Should fallback to documentType when allowedDocumentTypes is empty")
    }

    func testEffectivePreselectedDocumentType_returnsNilWhenMultipleAllowed() {
        _ = sut.setAllowedDocumentTypes("national-id,passport")

        XCTAssertNil(sut.effectivePreselectedDocumentType, "Should return nil when multiple types allowed")
    }

    func testEffectivePreselectedDocumentType_returnsNilWhenBothEmpty() {
        XCTAssertNil(sut.effectivePreselectedDocumentType)
    }
}
