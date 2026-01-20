//
//  DocumentIntroInteractorTests.swift
//  TruoraValidationsSDKTests
//
//  Created by Truora on 23/12/25.
//

import XCTest

@testable import TruoraValidationsSDK

final class DocumentIntroInteractorTests: XCTestCase {
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

    func testCreateValidation_withInjectedHandler_callsValidationCreatedAndSendsCorrectFormData() {
        let accountId = "test-account-id"
        let expectation = self.expectation(description: "validationCreated called")

        var capturedFormData: [String: String]?
        mockPresenter.onValidationCreated = {
            expectation.fulfill()
        }

        let interactor = DocumentIntroInteractor(
            presenter: mockPresenter,
            country: "PE",
            documentType: "national-id",
            createValidationHandler: { formData in
                capturedFormData = formData
                return ValidationCreateResponse(
                    validationId: "validation-id",
                    accountId: accountId,
                    type: "document-validation",
                    validationStatus: "pending",
                    lifecycleStatus: "active",
                    threshold: nil,
                    creationDate: "2025-01-01T00:00:00Z",
                    ipAddress: nil,
                    details: nil,
                    instructions: ValidationInstructions(
                        fileUploadLink: nil,
                        frontUrl: "https://example.com/front",
                        reverseUrl: "https://example.com/reverse"
                    )
                )
            }
        )

        interactor.createValidation(accountId: accountId)

        wait(for: [expectation], timeout: 1.0)

        XCTAssertTrue(mockPresenter.validationCreatedCalled)
        XCTAssertFalse(mockPresenter.validationFailedCalled)

        XCTAssertEqual(capturedFormData?["type"], "document-validation")
        XCTAssertEqual(capturedFormData?["country"], "pe")
        XCTAssertEqual(capturedFormData?["document_type"], "national-id")
        XCTAssertEqual(capturedFormData?["account_id"], accountId)
        XCTAssertEqual(capturedFormData?["user_authorized"], "true")
    }
}

// MARK: - Mock Presenter

private final class MockDocumentIntroPresenter: DocumentIntroInteractorToPresenter {
    private(set) var validationCreatedCalled = false
    private(set) var validationFailedCalled = false
    private(set) var lastResponse: ValidationCreateResponse?
    private(set) var lastError: ValidationError?
    var onValidationCreated: (() -> Void)?
    var onValidationFailed: (() -> Void)?

    func validationCreated(response: ValidationCreateResponse) {
        validationCreatedCalled = true
        lastResponse = response
        onValidationCreated?()
    }

    func validationFailed(_ error: ValidationError) {
        validationFailedCalled = true
        lastError = error
        onValidationFailed?()
    }
}
