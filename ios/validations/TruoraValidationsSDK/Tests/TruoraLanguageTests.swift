//
//  TruoraLanguageTests.swift
//  SDKTests
//
//  Created by Brayan Escobar on 10/11/25.
//

import XCTest
@testable import TruoraValidationsSDK

final class TruoraLanguageTests: XCTestCase {
    func testEnglishCase() {
        let language = TruoraLanguage.english

        XCTAssertEqual(language.rawValue, "en")
    }

    func testSpanishCase() {
        let language = TruoraLanguage.spanish

        XCTAssertEqual(language.rawValue, "es")
    }

    func testPortugueseCase() {
        let language = TruoraLanguage.portuguese

        XCTAssertEqual(language.rawValue, "pt")
    }

    // MARK: - Raw Value Initialization Tests

    func testInitFromRawValue_english() {
        let language = TruoraLanguage(rawValue: "en")

        XCTAssertEqual(language, .english)
    }

    func testInitFromRawValue_spanish() {
        let language = TruoraLanguage(rawValue: "es")

        XCTAssertEqual(language, .spanish)
    }

    func testInitFromRawValue_portuguese() {
        let language = TruoraLanguage(rawValue: "pt")

        XCTAssertEqual(language, .portuguese)
    }

    func testInitFromRawValue_invalid() {
        let language = TruoraLanguage(rawValue: "fr")

        XCTAssertNil(language)
    }

    func testInitFromRawValue_empty() {
        let language = TruoraLanguage(rawValue: "")

        XCTAssertNil(language)
    }
}
