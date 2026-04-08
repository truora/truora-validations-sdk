//
//  DocumentSelectionViewModelTests.swift
//  TruoraValidationsSDKTests
//
//  Created by Truora on 30/03/26.
//

import XCTest
@testable import TruoraValidationsSDK

@MainActor final class DocumentSelectionViewModelTests: XCTestCase {
    var sut: DocumentSelectionViewModel!

    override func setUp() {
        super.setUp()
        sut = DocumentSelectionViewModel()
    }

    override func tearDown() {
        sut = nil
        try? ValidationConfig.shared.setValidation(.document(Document()))
        super.tearDown()
    }

    // MARK: - Available Documents Tests

    func testAvailableDocuments_withNoCountrySelected_returnsEmptyArray() {
        XCTAssertTrue(sut.availableDocuments.isEmpty)
    }

    func testAvailableDocuments_withCountrySelected_returnsCountryDocumentTypes() {
        sut.selectedCountry = .pe

        XCTAssertEqual(sut.availableDocuments, [.nationalId, .foreignId])
    }

    func testAvailableDocuments_withSingleAllowedDocumentType_filtersToOnlyThatType() throws {
        let config = Document().setAllowedDocumentTypes("national-id")
        try ValidationConfig.shared.setValidation(.document(config))

        sut.selectedCountry = .pe

        XCTAssertEqual(sut.availableDocuments, [.nationalId])
    }

    func testAvailableDocuments_withAllowedDocumentTypeNotSupportedByCountry_returnsEmptyArray() throws {
        let config = Document().setAllowedDocumentTypes("passport")
        try ValidationConfig.shared.setValidation(.document(config))

        sut.selectedCountry = .pe

        XCTAssertTrue(sut.availableDocuments.isEmpty)
    }

    func testAvailableDocuments_withMultipleAllowedDocumentTypes_filtersResults() throws {
        let config = Document().setAllowedDocumentTypes("national-id,foreign-id")
        try ValidationConfig.shared.setValidation(.document(config))

        sut.selectedCountry = .co

        XCTAssertEqual(sut.availableDocuments, [.nationalId, .foreignId])
    }

    func testAvailableDocuments_withAllowedDocumentTypesCaseInsensitive_filtersCorrectly() throws {
        let config = Document().setAllowedDocumentTypes("NATIONAL-ID,Foreign-Id")
        try ValidationConfig.shared.setValidation(.document(config))

        sut.selectedCountry = .pe

        XCTAssertEqual(sut.availableDocuments, [.nationalId, .foreignId])
    }

    func testAvailableDocuments_withInvalidAllowedDocumentTypes_returnsEmptyArray() throws {
        let config = Document().setAllowedDocumentTypes("invalid-type,another-invalid")
        try ValidationConfig.shared.setValidation(.document(config))

        sut.selectedCountry = .pe

        XCTAssertTrue(sut.availableDocuments.isEmpty)
    }

    func testAvailableDocuments_withAllowedDocumentTypeNotSupportedByCountry_excludesUnsupportedType() throws {
        let config = Document().setAllowedDocumentTypes("national-id,passport")
        try ValidationConfig.shared.setValidation(.document(config))

        sut.selectedCountry = .pe

        XCTAssertEqual(sut.availableDocuments, [.nationalId])
    }

    func testAvailableDocuments_withCountryHavingPassport_includesPassportIfInAllowedList() throws {
        let config = Document().setAllowedDocumentTypes("national-id,passport")
        try ValidationConfig.shared.setValidation(.document(config))

        sut.selectedCountry = .cl

        XCTAssertEqual(sut.availableDocuments, [.nationalId, .passport])
    }
}
