//
//  DocumentSelectionInteractorTests.swift
//  TruoraValidationsSDKTests
//
//  Created by Truora on 07/01/26.
//

import XCTest
@testable import TruoraValidationsSDK

@MainActor final class DocumentSelectionInteractorTests: XCTestCase {
    override func tearDown() {
        try? ValidationConfig.shared.setValidation(.document(Document()))
        super.tearDown()
    }

    func testFetchSupportedCountries_returnsAllSupportedCountries() async throws {
        let presenter = MockDocumentSelectionInteractorPresenter()
        presenter.didLoadCountriesExpectation = expectation(description: "Countries loaded")
        let sut = DocumentSelectionInteractor(presenter: presenter, logger: MockTruoraLogger())

        sut.fetchSupportedCountries()
        try await fulfillment(of: [XCTUnwrap(presenter.didLoadCountriesExpectation)], timeout: 1.0)

        XCTAssertTrue(presenter.didLoadCountriesCalled)
        XCTAssertEqual(
            presenter.lastCountries,
            [.all, .ar, .bo, .br, .cl, .co, .cr, .ec, .mx, .pe, .sv, .ve]
        )
        XCTAssertTrue(presenter.lastCountries?.contains(.all) ?? false)
    }

    func testFetchSupportedCountries_withAllowedCountries_filtersResults() async throws {
        let config = Document().setAllowedCountries("PE,CO,MX")
        try ValidationConfig.shared.setValidation(.document(config))

        let presenter = MockDocumentSelectionInteractorPresenter()
        presenter.didLoadCountriesExpectation = expectation(description: "Countries loaded")
        let sut = DocumentSelectionInteractor(presenter: presenter, logger: MockTruoraLogger())

        sut.fetchSupportedCountries()
        try await fulfillment(of: [XCTUnwrap(presenter.didLoadCountriesExpectation)], timeout: 1.0)

        XCTAssertTrue(presenter.didLoadCountriesCalled)
        XCTAssertEqual(presenter.lastCountries, [.co, .mx, .pe])
    }

    func testFetchSupportedCountries_withPreselectedCountry_returnsAllCountries() async throws {
        let config = Document().setCountry("PE")
        try ValidationConfig.shared.setValidation(.document(config))

        let presenter = MockDocumentSelectionInteractorPresenter()
        presenter.didLoadCountriesExpectation = expectation(description: "Countries loaded")
        let sut = DocumentSelectionInteractor(presenter: presenter, logger: MockTruoraLogger())

        sut.fetchSupportedCountries()
        try await fulfillment(of: [XCTUnwrap(presenter.didLoadCountriesExpectation)], timeout: 1.0)

        XCTAssertEqual(
            presenter.lastCountries,
            [.all, .ar, .bo, .br, .cl, .co, .cr, .ec, .mx, .pe, .sv, .ve]
        )
    }

    func testFetchSupportedCountries_withAllowedCountriesCaseInsensitive_filtersCorrectly() async throws {
        let config = Document().setAllowedCountries("pe,CO,Mx")
        try ValidationConfig.shared.setValidation(.document(config))

        let presenter = MockDocumentSelectionInteractorPresenter()
        presenter.didLoadCountriesExpectation = expectation(description: "Countries loaded")
        let sut = DocumentSelectionInteractor(presenter: presenter, logger: MockTruoraLogger())

        sut.fetchSupportedCountries()
        try await fulfillment(of: [XCTUnwrap(presenter.didLoadCountriesExpectation)], timeout: 1.0)

        XCTAssertEqual(presenter.lastCountries, [.co, .mx, .pe])
    }

    func testFetchSupportedCountries_withInvalidAllowedCountries_returnsEmptyList() async throws {
        let config = Document().setAllowedCountries("XX,YY,ZZ")
        try ValidationConfig.shared.setValidation(.document(config))

        let presenter = MockDocumentSelectionInteractorPresenter()
        presenter.didLoadCountriesExpectation = expectation(description: "Countries loaded")
        let sut = DocumentSelectionInteractor(presenter: presenter, logger: MockTruoraLogger())

        sut.fetchSupportedCountries()
        try await fulfillment(of: [XCTUnwrap(presenter.didLoadCountriesExpectation)], timeout: 1.0)

        XCTAssertTrue(presenter.lastCountries?.isEmpty ?? false)
    }
}

// MARK: - Mocks

@MainActor private final class MockDocumentSelectionInteractorPresenter: DocumentSelectionInteractorToPresenter {
    private(set) var didLoadCountriesCalled = false
    private(set) var lastCountries: [NativeCountry]?
    var didLoadCountriesExpectation: XCTestExpectation?

    func didLoadCountries(_ countries: [NativeCountry]) async {
        didLoadCountriesCalled = true
        lastCountries = countries
        didLoadCountriesExpectation?.fulfill()
    }
}
