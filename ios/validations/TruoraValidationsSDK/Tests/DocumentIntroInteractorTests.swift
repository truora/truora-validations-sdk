//
//  DocumentIntroInteractorTests.swift
//  TruoraValidationsSDKTests
//
//  Created by Truora on 23/12/25.
//

import XCTest
@testable import TruoraValidationsSDK

@MainActor final class DocumentIntroInteractorTests: XCTestCase {
    private var interactor: DocumentIntroInteractor!
    private var mockPresenter: MockDocumentIntroPresenter!

    override func setUp() {
        super.setUp()
        ValidationConfig.shared.reset()
        mockPresenter = MockDocumentIntroPresenter()
        interactor = DocumentIntroInteractor(
            presenter: mockPresenter,
            country: "PE",
            documentType: "national-id"
        )
    }

    override func tearDown() {
        interactor = nil
        mockPresenter = nil
        ValidationConfig.shared.reset()
        super.tearDown()
    }

    func testCreateValidation_withoutApiClient_callsValidationFailed() {
        let accountId = "test-account-id"
        let expectation = self.expectation(description: "validationFailed called")
        mockPresenter.onValidationFailed = { expectation.fulfill() }

        interactor.createValidation(accountId: accountId)

        wait(for: [expectation], timeout: 1.0)

        XCTAssertTrue(mockPresenter.validationFailedCalled)
        XCTAssertTrue(
            mockPresenter.lastError?.localizedDescription.contains("API client not configured")
                ?? false
        )
        XCTAssertFalse(mockPresenter.validationCreatedCalled)
    }

    func testDeinitCancelsValidationTask_withoutCrashing() {
        var optionalInteractor: DocumentIntroInteractor? = DocumentIntroInteractor(
            presenter: mockPresenter,
            country: "PE",
            documentType: "national-id"
        )

        optionalInteractor = nil

        XCTAssertNil(optionalInteractor)
    }

    func testCreateValidation_withInjectedHandler_callsValidationCreatedAndSendsCorrectRequest() {
        let accountId = "test-account-id"
        let expectation = self.expectation(description: "validationCreated called")

        var capturedRequest: NativeValidationRequest?
        mockPresenter.onValidationCreated = {
            expectation.fulfill()
        }

        let interactor = DocumentIntroInteractor(
            presenter: mockPresenter,
            country: "PE",
            documentType: "national-id"
        ) { request in
            capturedRequest = request
            return NativeValidationCreateResponse(
                validationId: "validation-id",
                instructions: NativeValidationInstructions(
                    fileUploadLink: nil,
                    frontUrl: "https://example.com/front",
                    reverseUrl: "https://example.com/reverse"
                )
            )
        }

        interactor.createValidation(accountId: accountId)

        wait(for: [expectation], timeout: 1.0)

        XCTAssertTrue(mockPresenter.validationCreatedCalled)
        XCTAssertFalse(mockPresenter.validationFailedCalled)

        XCTAssertEqual(capturedRequest?.type, "document-validation")
        XCTAssertEqual(capturedRequest?.country, "pe")
        XCTAssertEqual(capturedRequest?.documentType, "national-id")
        XCTAssertEqual(capturedRequest?.accountId, accountId)
    }
}

// MARK: - Mock Presenter

@MainActor private final class MockDocumentIntroPresenter: DocumentIntroInteractorToPresenter {
    private(set) var validationCreatedCalled = false
    private(set) var validationFailedCalled = false
    private(set) var lastResponse: NativeValidationCreateResponse?
    private(set) var lastError: TruoraException?
    var onValidationCreated: (() -> Void)?
    var onValidationFailed: (() -> Void)?

    func validationCreated(response: NativeValidationCreateResponse) {
        validationCreatedCalled = true
        lastResponse = response
        onValidationCreated?()
    }

    func validationFailed(_ error: TruoraException) async {
        validationFailedCalled = true
        lastError = error
        onValidationFailed?()
    }
}
