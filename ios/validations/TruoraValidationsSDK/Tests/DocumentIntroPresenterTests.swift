//
//  DocumentIntroPresenterTests.swift
//  TruoraValidationsSDKTests
//
//  Created by Truora on 23/12/25.
//

import XCTest
@testable import TruoraValidationsSDK

@MainActor final class DocumentIntroPresenterTests: XCTestCase {
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
    }

    override func tearDown() {
        sut = nil
        mockView = nil
        mockInteractor = nil
        mockRouter = nil
        ValidationConfig.shared.reset()
        super.tearDown()
    }

    // MARK: - View Lifecycle Tests

    func testViewDidLoad_doesNothing() async {
        await sut.viewDidLoad()
        XCTAssertFalse(mockView.showLoadingCalled)
        XCTAssertFalse(mockInteractor.createValidationCalled)
    }

    // MARK: - Action Tests

    func testStartTapped_withConfiguredAccount_callsInteractor() async throws {
        // Given
        try await ValidationConfig.shared.configure(apiKey: "key", accountId: "acc-123")

        // When
        await sut.startTapped()

        // Then
        XCTAssertTrue(mockView.showLoadingCalled)
        XCTAssertTrue(mockInteractor.createValidationCalled)
        XCTAssertEqual(mockInteractor.lastAccountId, "acc-123")
    }

    func testStartTapped_withoutAccount_showsError() async {
        // Given - ValidationConfig not configured

        // When
        await sut.startTapped()

        // Then
        XCTAssertFalse(mockView.showLoadingCalled)
        XCTAssertFalse(mockInteractor.createValidationCalled)
    }

    func testCancelTapped_callsRouter() async {
        await sut.cancelTapped()
        XCTAssertTrue(mockRouter.handleCancellationCalled)
    }

    // MARK: - Interactor Callback Tests

    func testValidationCreated_withValidUrls_navigatesToCapture() async {
        // Given
        let instructions = NativeValidationInstructions(
            fileUploadLink: nil,
            frontUrl: "https://example.com/front",
            reverseUrl: "https://example.com/reverse"
        )
        let response = NativeValidationCreateResponse(
            validationId: "validation-123",
            instructions: instructions
        )

        // When
        await sut.validationCreated(response: response)

        // Then
        XCTAssertTrue(mockView.hideLoadingCalled)
        XCTAssertTrue(mockRouter.navigateToDocumentCaptureCalled)
        XCTAssertEqual(mockRouter.lastValidationId, "validation-123")
        XCTAssertEqual(mockRouter.lastFrontUploadUrl, "https://example.com/front")
        XCTAssertEqual(mockRouter.lastReverseUploadUrl, "https://example.com/reverse")
    }

    func testValidationCreated_withMissingFrontUrl_showsError() async {
        // Given - instructions missing frontUrl
        let instructions = NativeValidationInstructions(
            fileUploadLink: nil,
            frontUrl: nil,
            reverseUrl: "https://example.com/reverse"
        )
        let response = NativeValidationCreateResponse(
            validationId: "validation-123",
            instructions: instructions
        )

        // When
        await sut.validationCreated(response: response)

        // Then
        XCTAssertTrue(mockView.hideLoadingCalled)
        XCTAssertTrue(mockView.showErrorCalled)
        XCTAssertTrue(mockView.lastErrorMessage?.contains("front upload URL") ?? false)
        XCTAssertFalse(mockRouter.navigateToDocumentCaptureCalled)
    }

    func testValidationCreated_withEmptyFrontUrl_showsError() async {
        // Given - instructions with empty frontUrl
        let instructions = NativeValidationInstructions(
            fileUploadLink: nil,
            frontUrl: "",
            reverseUrl: "https://example.com/reverse"
        )
        let response = NativeValidationCreateResponse(
            validationId: "validation-123",
            instructions: instructions
        )

        // When
        await sut.validationCreated(response: response)

        // Then
        XCTAssertTrue(mockView.hideLoadingCalled)
        XCTAssertTrue(mockView.showErrorCalled)
        XCTAssertTrue(mockView.lastErrorMessage?.contains("front upload URL") ?? false)
        XCTAssertFalse(mockRouter.navigateToDocumentCaptureCalled)
    }

    func testValidationFailed_hidesLoadingAndShowsError() async {
        // When
        await sut.validationFailed(.network(message: "api error"))

        // Then
        XCTAssertTrue(mockView.hideLoadingCalled)
        XCTAssertTrue(mockRouter.handleErrorCalled)
        XCTAssertEqual(mockRouter.lastErrorMessage, "api error")
    }
}

// MARK: - Mocks

@MainActor private final class MockDocumentIntroView: DocumentIntroPresenterToView {
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

@MainActor private final class MockDocumentIntroInteractor: DocumentIntroPresenterToInteractor {
    private(set) var createValidationCalled = false
    private(set) var lastAccountId: String?

    func createValidation(accountId: String) {
        createValidationCalled = true
        lastAccountId = accountId
    }
}

@MainActor private final class MockDocumentIntroRouter: ValidationRouter {
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

    override func handleError(_ error: TruoraException) {
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
