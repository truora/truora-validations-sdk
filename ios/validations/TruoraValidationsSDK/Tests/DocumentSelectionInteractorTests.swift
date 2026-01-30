//
//  DocumentSelectionInteractorTests.swift
//  TruoraValidationsSDKTests
//
//  Created by Truora on 07/01/26.
//

import XCTest
@testable import TruoraValidationsSDK

@MainActor final class DocumentSelectionInteractorTests: XCTestCase {
    func testFetchSupportedCountries_returnsAllSupportedCountries() async throws {
        let presenter = MockDocumentSelectionInteractorPresenter()
        presenter.didLoadCountriesExpectation = expectation(description: "Countries loaded")
        let sut = DocumentSelectionInteractor(presenter: presenter)

        sut.fetchSupportedCountries()
        try await fulfillment(of: [XCTUnwrap(presenter.didLoadCountriesExpectation)], timeout: 1.0)

        XCTAssertTrue(presenter.didLoadCountriesCalled)
        XCTAssertEqual(
            presenter.lastCountries,
            [.all, .ar, .br, .cl, .co, .cr, .mx, .pe, .sv, .ve]
        )
        XCTAssertTrue(presenter.lastCountries?.contains(.all) ?? false)
    }
}

// MARK: - Mocks

@MainActor private final class MockDocumentSelectionInteractorPresenter: DocumentSelectionInteractorToPresenter {
    private(set) var didLoadCountriesCalled = false
    private(set) var lastCountries: [NativeCountry]?
    var didLoadCountriesExpectation: XCTestExpectation?

    func didLoadCountries(_ countries: [NativeCountry]) {
        didLoadCountriesCalled = true
        lastCountries = countries
        didLoadCountriesExpectation?.fulfill()
    }
}
