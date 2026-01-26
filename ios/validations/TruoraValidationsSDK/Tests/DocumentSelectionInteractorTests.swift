//
//  DocumentSelectionInteractorTests.swift
//  TruoraValidationsSDKTests
//
//  Created by Truora on 07/01/26.
//

import XCTest

import TruoraShared
@testable import TruoraValidationsSDK

final class DocumentSelectionInteractorTests: XCTestCase {
    func testFetchSupportedCountries_returnsAllSupportedCountriesExcludingAll() {
        let presenter = MockDocumentSelectionInteractorPresenter()
        let sut = DocumentSelectionInteractor(presenter: presenter)

        sut.fetchSupportedCountries()

        XCTAssertTrue(presenter.didLoadCountriesCalled)
        XCTAssertEqual(
            presenter.lastCountries,
            [.all, .ar, .br, .cl, .co, .cr, .mx, .pe, .sv, .ve]
        )
        XCTAssertTrue(presenter.lastCountries?.contains(.all) ?? false)
    }
}

// MARK: - Mocks

private final class MockDocumentSelectionInteractorPresenter: DocumentSelectionInteractorToPresenter {
    private(set) var didLoadCountriesCalled = false
    private(set) var lastCountries: [TruoraCountry]?

    func didLoadCountries(_ countries: [TruoraCountry]) {
        didLoadCountriesCalled = true
        lastCountries = countries
    }
}
