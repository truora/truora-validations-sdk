//
//  DocumentIntroPresenterTests.swift
//  TruoraValidationsSDKTests
//
//  Created by Truora on 23/12/25.
//

import XCTest

@testable import TruoraValidationsSDK

final class DocumentIntroPresenterTests: XCTestCase {
    private var sut: DocumentIntroPresenter!
    private var mockView: MockDocumentIntroView!
    private var mockInteractor: MockDocumentIntroInteractor!
    private var mockRouter: MockDocumentIntroRouter!

    override func setUp() {
        super.setUp()
        mockView = MockDocumentIntroView()
        mockInteractor = MockDocumentIntroInteractor()
        let navController = UINavigationController()
        mockRouter = MockDocumentIntroRouter(navigationController: navController)

        sut = DocumentIntroPresenter(
            view: mockView,
            interactor: mockInteractor,
            router: mockRouter
        )

        ValidationConfig.shared.reset()
    }

    override func tearDown() {
        sut = nil
        mockView = nil
        mockInteractor = nil
        mockRouter = nil
        ValidationConfig.shared.reset()
        super.tearDown()
    }

    func testStartTapped_withoutAccountId_showsError() {
        XCTAssertNil(ValidationConfig.shared.accountId)

        sut.startTapped()

        XCTAssertTrue(mockView.showErrorCalled)
        XCTAssertTrue(mockView.lastErrorMessage?.contains("Missing account ID") ?? false)
        XCTAssertFalse(mockView.showLoadingCalled)
        XCTAssertFalse(mockInteractor.createValidationCalled)
    }

    func testStartTapped_withNilInteractor_showsError() async throws {
        ValidationConfig.shared.reset()
        try await ValidationConfig.shared.configure(
            apiKey: "test-api-key",
            accountId: "test-account-id",
            delegate: nil
        )

        sut = DocumentIntroPresenter(
            view: mockView,
            interactor: nil,
            router: mockRouter
        )

        sut.startTapped()

        XCTAssertTrue(mockView.showErrorCalled)
        XCTAssertTrue(mockView.lastErrorMessage?.contains("Interactor not configured") ?? false)
        XCTAssertFalse(mockInteractor.createValidationCalled)
    }

    func testStartTapped_withValidConfiguration_callsInteractor() async throws {
        let expectedAccountId = "test-account-id"
        try await ValidationConfig.shared.configure(
            apiKey: "test-api-key",
            accountId: expectedAccountId,
            delegate: nil
        )

        sut.startTapped()

        XCTAssertTrue(mockView.showLoadingCalled)
        XCTAssertTrue(mockInteractor.createValidationCalled)
        XCTAssertEqual(mockInteractor.lastAccountId, expectedAccountId)
    }

    func testCancelTapped_callsRouterHandleCancellation() {
        sut.cancelTapped()

        XCTAssertTrue(mockRouter.handleCancellationCalled)
    }

    func testValidationCreated_withValidFrontAndReverseUrls_navigatesToDocumentCapture() {
        let instructions = ValidationInstructions(
            fileUploadLink: nil,
            frontUrl: "https://example.com/front",
            reverseUrl: "https://example.com/reverse"
        )
        let response = ValidationCreateResponse(
            validationId: "validation-id",
            accountId: "account-id",
            type: "document-validation",
            validationStatus: "pending",
            lifecycleStatus: "active",
            threshold: nil,
            creationDate: "2025-01-01T00:00:00Z",
            ipAddress: nil,
            details: nil,
            instructions: instructions
        )

        sut.validationCreated(response: response)

        XCTAssertFalse(mockView.showErrorCalled, "Should not show error when validation succeeds")
        XCTAssertTrue(mockView.hideLoadingCalled)
        XCTAssertTrue(mockRouter.navigateToDocumentCaptureCalled)
        XCTAssertEqual(mockRouter.lastValidationId, "validation-id")
        XCTAssertEqual(mockRouter.lastFrontUploadUrl, "https://example.com/front")
        XCTAssertEqual(mockRouter.lastReverseUploadUrl, "https://example.com/reverse")
    }

    func testValidationCreated_missingFrontUrl_showsErrorAndDoesNotNavigate() {
        let instructions = ValidationInstructions(
            fileUploadLink: nil,
            frontUrl: nil,
            reverseUrl: "https://example.com/reverse"
        )
        let response = ValidationCreateResponse(
            validationId: "validation-id",
            accountId: "account-id",
            type: "document-validation",
            validationStatus: "pending",
            lifecycleStatus: "active",
            threshold: nil,
            creationDate: "2025-01-01T00:00:00Z",
            ipAddress: nil,
            details: nil,
            instructions: instructions
        )

        sut.validationCreated(response: response)

        XCTAssertTrue(mockView.showErrorCalled)
        XCTAssertTrue(
            mockView.hideLoadingCalled,
            "Presenter should hide loading before validating instructions"
        )
        XCTAssertTrue(mockView.lastErrorMessage?.contains("Missing front upload URL") ?? false)
        XCTAssertFalse(mockRouter.navigateToDocumentCaptureCalled)
    }

    func testValidationCreated_missingReverseUrl_showsErrorAndDoesNotNavigate() {
        let instructions = ValidationInstructions(
            fileUploadLink: nil,
            frontUrl: "https://example.com/front",
            reverseUrl: nil
        )
        let response = ValidationCreateResponse(
            validationId: "validation-id",
            accountId: "account-id",
            type: "document-validation",
            validationStatus: "pending",
            lifecycleStatus: "active",
            threshold: nil,
            creationDate: "2025-01-01T00:00:00Z",
            ipAddress: nil,
            details: nil,
            instructions: instructions
        )

        sut.validationCreated(response: response)

        XCTAssertTrue(mockView.showErrorCalled)
        XCTAssertTrue(
            mockView.hideLoadingCalled,
            "Presenter should hide loading before validating instructions"
        )
        XCTAssertTrue(mockView.lastErrorMessage?.contains("Missing reverse upload URL") ?? false)
        XCTAssertFalse(mockRouter.navigateToDocumentCaptureCalled)
    }

    func testValidationFailed_hidesLoadingAndCallsRouterHandleError() {
        let error = ValidationError.apiError("Test error")

        sut.validationFailed(error)

        XCTAssertTrue(mockView.hideLoadingCalled)
        XCTAssertTrue(mockRouter.handleErrorCalled)
        XCTAssertEqual(mockRouter.lastErrorMessage, error.localizedDescription)
    }

    // MARK: - Single-Sided Document Tests

    func testValidationCreated_withOnlyFrontUrl_navigatesToCapture() {
        // Given - Single-sided document (passport) with only front URL
        let instructions = ValidationInstructions(
            fileUploadLink: nil,
            frontUrl: "https://example.com/front",
            reverseUrl: nil
        )
        let response = ValidationCreateResponse(
            validationId: "validation-123",
            accountId: "account-1",
            type: "document-validation",
            validationStatus: "processing",
            lifecycleStatus: "active",
            threshold: nil,
            creationDate: "2025-01-09",
            ipAddress: "127.0.0.1",
            details: nil,
            instructions: instructions
        )

        // When
        sut.validationCreated(response: response)

        // Then
        XCTAssertTrue(mockView.hideLoadingCalled)
        XCTAssertFalse(mockView.showErrorCalled)
        XCTAssertTrue(mockRouter.navigateToDocumentCaptureCalled)
        XCTAssertEqual(mockRouter.lastValidationId, "validation-123")
        XCTAssertEqual(mockRouter.lastFrontUploadUrl, "https://example.com/front")
        XCTAssertNil(mockRouter.lastReverseUploadUrl, "Reverse URL should be nil for single-sided documents")
    }

    func testValidationCreated_withEmptyReverseUrl_navigatesToCapture() {
        // Given - Single-sided document with empty reverse URL string
        let instructions = ValidationInstructions(
            fileUploadLink: nil,
            frontUrl: "https://example.com/front",
            reverseUrl: ""
        )
        let response = ValidationCreateResponse(
            validationId: "validation-456",
            accountId: "account-1",
            type: "document-validation",
            validationStatus: "processing",
            lifecycleStatus: "active",
            threshold: nil,
            creationDate: "2025-01-09",
            ipAddress: "127.0.0.1",
            details: nil,
            instructions: instructions
        )

        // When
        sut.validationCreated(response: response)

        // Then
        XCTAssertTrue(mockView.hideLoadingCalled)
        XCTAssertFalse(mockView.showErrorCalled)
        XCTAssertTrue(mockRouter.navigateToDocumentCaptureCalled)
        XCTAssertEqual(mockRouter.lastValidationId, "validation-456")
        XCTAssertEqual(mockRouter.lastFrontUploadUrl, "https://example.com/front")
        XCTAssertEqual(mockRouter.lastReverseUploadUrl, "", "Empty reverse URL should be passed as-is")
    }

    func testValidationCreated_withBothUrls_navigatesToCapture() {
        // Given - Two-sided document with both URLs
        let instructions = ValidationInstructions(
            fileUploadLink: nil,
            frontUrl: "https://example.com/front",
            reverseUrl: "https://example.com/reverse"
        )
        let response = ValidationCreateResponse(
            validationId: "validation-789",
            accountId: "account-1",
            type: "document-validation",
            validationStatus: "processing",
            lifecycleStatus: "active",
            threshold: nil,
            creationDate: "2025-01-09",
            ipAddress: "127.0.0.1",
            details: nil,
            instructions: instructions
        )

        // When
        sut.validationCreated(response: response)

        // Then
        XCTAssertTrue(mockView.hideLoadingCalled)
        XCTAssertFalse(mockView.showErrorCalled)
        XCTAssertTrue(mockRouter.navigateToDocumentCaptureCalled)
        XCTAssertEqual(mockRouter.lastValidationId, "validation-789")
        XCTAssertEqual(mockRouter.lastFrontUploadUrl, "https://example.com/front")
        XCTAssertEqual(mockRouter.lastReverseUploadUrl, "https://example.com/reverse")
    }
}

// MARK: - Mocks

private final class MockDocumentIntroView: DocumentIntroPresenterToView {
    private(set) var showLoadingCalled = false
    private(set) var hideLoadingCalled = false
    private(set) var showErrorCalled = false
    private(set) var lastErrorMessage: String?

    func showLoading() {
        showLoadingCalled = true
    }

    func hideLoading() {
        hideLoadingCalled = true
    }

    func showError(_ message: String) {
        showErrorCalled = true
        lastErrorMessage = message
    }
}

private final class MockDocumentIntroInteractor: DocumentIntroPresenterToInteractor {
    private(set) var createValidationCalled = false
    private(set) var lastAccountId: String?

    func createValidation(accountId: String) {
        createValidationCalled = true
        lastAccountId = accountId
    }
}

private final class MockDocumentIntroRouter: ValidationRouter {
    private(set) var handleCancellationCalled = false
    private(set) var handleErrorCalled = false
    private(set) var lastErrorMessage: String?

    private(set) var navigateToDocumentCaptureCalled = false
    private(set) var lastValidationId: String?
    private(set) var lastFrontUploadUrl: String?
    private(set) var lastReverseUploadUrl: String?

    override func handleCancellation() {
        handleCancellationCalled = true
    }

    override func handleError(_ error: ValidationError) {
        handleErrorCalled = true
        lastErrorMessage = error.localizedDescription
    }

    override func navigateToDocumentCapture(
        validationId: String,
        frontUploadUrl: String,
        reverseUploadUrl: String?
    ) throws {
        navigateToDocumentCaptureCalled = true
        lastValidationId = validationId
        lastFrontUploadUrl = frontUploadUrl
        lastReverseUploadUrl = reverseUploadUrl
    }
}
