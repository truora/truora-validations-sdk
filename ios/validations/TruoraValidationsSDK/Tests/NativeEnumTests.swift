//
//  NativeEnumTests.swift
//  TruoraValidationsSDKTests
//
//  Created by Truora on 25/01/26.
//

import XCTest
@testable import TruoraValidationsSDK

@MainActor final class NativeEnumTests: XCTestCase {
    // MARK: - NativeCountry Tests

    func testNativeCountry_allCases_haveCorrectRawValues() {
        XCTAssertEqual(NativeCountry.all.rawValue, "all")
        XCTAssertEqual(NativeCountry.ar.rawValue, "ar")
        XCTAssertEqual(NativeCountry.br.rawValue, "br")
        XCTAssertEqual(NativeCountry.cl.rawValue, "cl")
        XCTAssertEqual(NativeCountry.co.rawValue, "co")
        XCTAssertEqual(NativeCountry.cr.rawValue, "cr")
        XCTAssertEqual(NativeCountry.mx.rawValue, "mx")
        XCTAssertEqual(NativeCountry.pe.rawValue, "pe")
        XCTAssertEqual(NativeCountry.sv.rawValue, "sv")
        XCTAssertEqual(NativeCountry.ve.rawValue, "ve")
    }

    func testNativeCountry_displayName_returnsNonEmptyString() {
        for country in NativeCountry.allCases {
            XCTAssertFalse(country.displayName.isEmpty, "Display name for \(country) should not be empty")
        }
    }

    func testNativeCountry_documentTypes_returnsExpectedList() {
        XCTAssertTrue(NativeCountry.mx.documentTypes.contains(.nationalId))
        XCTAssertTrue(NativeCountry.mx.documentTypes.contains(.passport))
        XCTAssertTrue(NativeCountry.br.documentTypes.contains(.cnh))
        XCTAssertTrue(NativeCountry.co.documentTypes.contains(.rut))
        XCTAssertTrue(NativeCountry.all.documentTypes.contains(.passport))
    }

    // MARK: - NativeDocumentType Tests

    func testNativeDocumentType_rawValues_matchAPIFormat() {
        XCTAssertEqual(NativeDocumentType.nationalId.rawValue, "national-id")
        XCTAssertEqual(NativeDocumentType.driverLicense.rawValue, "driver-license")
        XCTAssertEqual(NativeDocumentType.taxId.rawValue, "tax-id")
        XCTAssertEqual(NativeDocumentType.passport.rawValue, "passport")
    }

    func testNativeDocumentType_label_returnsNonEmptyString() {
        for docType in NativeDocumentType.allCases {
            XCTAssertFalse(docType.label.isEmpty, "Label for \(docType) should not be empty")
        }
    }

    // MARK: - DocumentCaptureSide Tests

    func testDocumentCaptureSide_cases() {
        XCTAssertNotNil(DocumentCaptureSide(rawValue: "front"))
        XCTAssertNotNil(DocumentCaptureSide(rawValue: "back"))
    }

    // MARK: - DocumentFeedbackType Tests

    func testDocumentFeedbackType_rawValues() {
        XCTAssertEqual(DocumentFeedbackType.scanningManual.rawValue, "scanning_manual")
        XCTAssertEqual(DocumentFeedbackType.multipleDocuments.rawValue, "multiple_documents")
    }

    // MARK: - FeedbackScenario Tests

    func testFeedbackScenario_rawValues() {
        XCTAssertEqual(FeedbackScenario.blurryImage.rawValue, "blurry_image")
        XCTAssertEqual(FeedbackScenario.imageWithReflection.rawValue, "image_with_reflection")
    }
}
