//
//  PassiveIntroPresenterTests.swift
//  TruoraValidationsSDKTests
//
//  Created by Truora on 11/11/25.
//

import XCTest
@testable import TruoraValidationsSDK

/// Tests for PassiveIntroPresenter following VIPER architecture
/// Ensures proper separation of concerns and protocol-based communication
@MainActor final class PassiveIntroPresenterTests: XCTestCase {
    // MARK: - Properties

    private var sut: PassiveIntroPresenter!
    private var mockView: MockPassiveIntroView!
    private var mockInteractor: MockPassiveIntroInteractor!
    private var mockRouter: MockPassiveIntroRouter!

    // MARK: - Lifecycle

    override func setUp() {
        super.setUp()
        mockView = MockPassiveIntroView()
        mockInteractor = MockPassiveIntroInteractor()
        let navController = UINavigationController()
        mockRouter = MockPassiveIntroRouter(navigationController: navController)

        sut = PassiveIntroPresenter(
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

    // MARK: - View Lifecycle Tests

    func testViewDidLoad_doesNotCrash() async {
        // When
        await sut.viewDidLoad()

        // Then
        XCTAssertNotNil(sut, "Presenter should remain initialized after viewDidLoad")
    }

    // MARK: - Start Validation Tests

    func testStartTapped_withoutAccountId_showsError() async {
        // Given
        XCTAssertNil(ValidationConfig.shared.accountId, "Account ID should be nil initially")

        // When
        await sut.startTapped()

        // Then
        XCTAssertTrue(mockView.showErrorCalled, "Should show error when account ID is missing")
        XCTAssertTrue(
            mockView.lastErrorMessage?.contains("Missing account ID") ?? false,
            "Error message should mention missing account ID"
        )
        XCTAssertFalse(mockView.showLoadingCalled, "Should not show loading on error")
        XCTAssertFalse(mockInteractor.createValidationCalled, "Should not call interactor on error")
    }

    func testStartTapped_withNilInteractor_showsError() async throws {
        // Given
        try await ValidationConfig.shared.configure(
            apiKey: "test-api-key",
            accountId: "test-account-id",
            delegate: nil
        )

        sut = PassiveIntroPresenter(
            view: mockView,
            interactor: nil,
            router: mockRouter
        )

        // When
        await sut.startTapped()

        // Then
        XCTAssertTrue(mockView.showErrorCalled, "Should show error when interactor is nil")
        XCTAssertTrue(
            mockView.lastErrorMessage?.contains("Interactor not configured") ?? false,
            "Error message should mention interactor not configured"
        )
        XCTAssertFalse(mockView.showLoadingCalled, "Should not show loading when interactor is nil")
    }

    func testStartTapped_withValidConfiguration_callsInteractor() async throws {
        // Given
        let expectedAccountId = "test-account-id"
        try await ValidationConfig.shared.configure(
            apiKey: "test-api-key",
            accountId: expectedAccountId,
            delegate: nil
        )

        let enrollmentExpectation = expectation(description: "Enrollment completed")
        let validationExpectation = expectation(description: "Validation created")

        mockInteractor.onEnrollmentCompleted = {
            enrollmentExpectation.fulfill()
        }
        mockInteractor.onCreateValidation = { _ in
            validationExpectation.fulfill()
        }

        // When
        await sut.startTapped()

        // Then - wait for actual completion
        await fulfillment(of: [enrollmentExpectation, validationExpectation], timeout: 1.0, enforceOrder: true)

        XCTAssertTrue(mockView.showLoadingCalled, "Should show loading when starting validation")
        XCTAssertTrue(
            mockInteractor.enrollmentCompletedCalled,
            "Should wait for enrollment completion"
        )
        XCTAssertTrue(
            mockInteractor.createValidationCalled,
            "Should call interactor to create validation"
        )
        XCTAssertEqual(
            mockInteractor.lastAccountId,
            expectedAccountId,
            "Should pass correct account ID to interactor"
        )
    }

    func testStartTapped_waitsForEnrollmentBeforeCreatingValidation() async throws {
        // Given
        let expectedAccountId = "test-account-id"
        try await ValidationConfig.shared.configure(
            apiKey: "test-api-key",
            accountId: expectedAccountId,
            delegate: nil
        )

        // Simulate enrollment taking some time
        mockInteractor.enrollmentDelay = 0.05

        var enrollmentCompletedFirst = false
        var createValidationCalledAfterEnrollment = false

        let enrollmentExpectation = expectation(description: "Enrollment completed")
        let validationExpectation = expectation(description: "Validation created")

        // Track call order using closures
        mockInteractor.onEnrollmentCompleted = {
            enrollmentCompletedFirst = true
            enrollmentExpectation.fulfill()
        }

        mockInteractor.onCreateValidation = { _ in
            if enrollmentCompletedFirst {
                createValidationCalledAfterEnrollment = true
            }
            validationExpectation.fulfill()
        }

        // When
        await sut.startTapped()

        // Then - wait for actual completion with enforced order
        await fulfillment(of: [enrollmentExpectation, validationExpectation], timeout: 1.0, enforceOrder: true)

        XCTAssertTrue(mockView.showLoadingCalled, "Should show loading")
        XCTAssertTrue(mockInteractor.enrollmentCompletedCalled, "Should call enrollmentCompleted")
        XCTAssertTrue(mockInteractor.createValidationCalled, "Should call createValidation")
        XCTAssertTrue(
            createValidationCalledAfterEnrollment,
            "createValidation should be called after enrollment completes"
        )
    }

    func testStartTapped_enrollmentFailure_hidesLoadingAndShowsError() async throws {
        // Given
        try await ValidationConfig.shared.configure(
            apiKey: "test-api-key",
            accountId: "test-account-id",
            delegate: nil
        )

        mockInteractor.shouldThrowEnrollmentError = true

        let enrollmentExpectation = expectation(description: "Enrollment attempted")
        mockInteractor.onEnrollmentCompleted = {
            enrollmentExpectation.fulfill()
        }

        // When
        await sut.startTapped()

        // Then - wait for enrollment to fail
        await fulfillment(of: [enrollmentExpectation], timeout: 1.0)

        // Give time for error handling to propagate
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        XCTAssertTrue(mockView.showLoadingCalled, "Should show loading initially")
        XCTAssertTrue(mockInteractor.enrollmentCompletedCalled, "Should call enrollmentCompleted")
        XCTAssertFalse(mockInteractor.createValidationCalled, "Should NOT call createValidation on failure")
        XCTAssertTrue(mockRouter.handleErrorCalled, "Should call router handleError on enrollment failure")
    }

    // MARK: - Cancel Tests

    func testCancelTapped_callsRouter() async {
        // When
        await sut.cancelTapped()

        // Then
        XCTAssertTrue(
            mockRouter.handleCancellationCalled,
            "Should call router to handle cancellation"
        )
    }

    // MARK: - Validation Created Tests

    func testValidationCreated_withValidResponse_navigatesToPassiveCapture() async {
        // Given
        let mockResponse = MockResponseBuilder.validationCreateResponse(
            validationId: "mock-validation-id",
            instructions: MockResponseBuilder.validationInstructions(
                fileUploadLink: "https://example.com/upload"
            )
        )

        // When
        await sut.validationCreated(response: mockResponse)

        // Then
        XCTAssertTrue(mockView.hideLoadingCalled, "Should hide loading after validation created")
        XCTAssertTrue(
            mockRouter.navigateToPassiveCaptureCalled,
            "Should navigate to passive capture"
        )
        XCTAssertEqual(
            mockRouter.lastValidationId,
            "mock-validation-id",
            "Should pass correct validation ID to router"
        )
        XCTAssertEqual(
            mockRouter.lastUploadUrl,
            "https://example.com/upload",
            "Should pass upload URL from instructions to router"
        )
    }

    func testValidationCreated_withNilInstructions_navigatesWithNilUploadUrl() async {
        // Given
        let mockResponse = MockResponseBuilder.validationCreateResponse(
            validationId: "mock-validation-id",
            instructions: nil
        )

        // When
        await sut.validationCreated(response: mockResponse)

        // Then
        XCTAssertTrue(mockView.hideLoadingCalled, "Should hide loading")
        XCTAssertTrue(
            mockRouter.navigateToPassiveCaptureCalled,
            "Should navigate despite nil instructions"
        )
        XCTAssertNil(mockRouter.lastUploadUrl, "Upload URL should be nil when instructions are nil")
    }

    func testValidationCreated_whenRouterDeallocated_showsError() async throws {
        // Given
        // Create a weak reference scenario by using a temporary router
        var tempRouter: MockPassiveIntroRouter? = MockPassiveIntroRouter(
            navigationController: UINavigationController()
        )
        sut = try PassiveIntroPresenter(
            view: mockView,
            interactor: mockInteractor,
            router: XCTUnwrap(tempRouter)
        )

        // Deallocate the router to simulate weak reference becoming nil
        tempRouter = nil

        let mockResponse = MockResponseBuilder.validationCreateResponse()

        // When
        await sut.validationCreated(response: mockResponse)

        // Then
        XCTAssertTrue(mockView.hideLoadingCalled, "Should hide loading")
        XCTAssertTrue(mockView.showErrorCalled, "Should show error when router is deallocated")
        XCTAssertTrue(
            mockView.lastErrorMessage?.contains("Router not configured") ?? false,
            "Error message should mention router not configured"
        )
    }

    func testValidationCreated_withNavigationError_showsError() async {
        // Given
        mockRouter.shouldThrowError = true
        let mockResponse = MockResponseBuilder.validationCreateResponse()

        // When
        await sut.validationCreated(response: mockResponse)

        // Then
        XCTAssertTrue(mockView.hideLoadingCalled, "Should hide loading before showing error")
        XCTAssertTrue(mockView.showErrorCalled, "Should show error when navigation fails")
        XCTAssertNotNil(mockView.lastErrorMessage, "Error message should be present")
    }

    // MARK: - Validation Failed Tests

    func testValidationFailed_hidesLoadingAndShowsError() async {
        // Given
        let expectedError = TruoraException.network(message: "Network connection failed")

        // When
        await sut.validationFailed(expectedError)

        // Then
        XCTAssertTrue(mockView.hideLoadingCalled, "Should hide loading on validation failure")
        XCTAssertTrue(
            mockRouter.handleErrorCalled,
            "Should call router handle error on validation failure"
        )
        XCTAssertEqual(
            mockRouter.lastErrorMessage,
            expectedError.errorDescription,
            "Should show the error description"
        )
    }

    func testValidationFailed_withDifferentErrorTypes_displaysAppropriateMessages() async throws {
        // Test different error types
        let errorTypes: [TruoraException] = [
            .sdk(SDKError(type: .invalidConfiguration, details: "Invalid config")),
            .network(message: "API failed"),
            .sdk(SDKError(type: .internalError, details: "Internal error"))
        ]

        for error in errorTypes {
            // Given
            try await MainActor.run { setUp() } // Reset for each iteration

            // When
            await sut.validationFailed(error)

            // Then
            XCTAssertTrue(
                mockRouter.handleErrorCalled,
                "Should call router handle error for \(error)"
            )
            XCTAssertNotNil(mockRouter.lastErrorMessage, "Error message should exist for \(error)")
        }
    }
}

// MARK: - Mock View

@MainActor private final class MockPassiveIntroView: PassiveIntroPresenterToView {
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

// MARK: - Mock Interactor

@MainActor private final class MockPassiveIntroInteractor: PassiveIntroPresenterToInteractor {
    private(set) var createValidationCalled = false
    private(set) var enrollmentCompletedCalled = false
    private(set) var lastAccountId: String?
    var enrollmentDelay: TimeInterval = 0.0
    var shouldThrowEnrollmentError = false

    // Closures for custom behavior in tests
    var onEnrollmentCompleted: (() async -> Void)?
    var onCreateValidation: ((String) -> Void)?

    func createValidation(accountId: String) {
        createValidationCalled = true
        lastAccountId = accountId
        onCreateValidation?(accountId)
    }

    func enrollmentCompleted() async throws {
        enrollmentCompletedCalled = true
        if enrollmentDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(enrollmentDelay * 1_000_000_000))
        }
        await onEnrollmentCompleted?()
        if shouldThrowEnrollmentError {
            throw TruoraException.network(message: "Mock enrollment error")
        }
    }
}

// MARK: - Mock Router

@MainActor private final class MockPassiveIntroRouter: ValidationRouter {
    private(set) var handleCancellationCalled = false
    private(set) var navigateToPassiveCaptureCalled = false
    private(set) var lastValidationId: String?
    private(set) var lastUploadUrl: String?
    private(set) var handleErrorCalled = false
    private(set) var lastErrorMessage: String?
    var shouldThrowError = false

    override func handleCancellation() {
        handleCancellationCalled = true
    }

    override func handleError(_ error: TruoraException) {
        handleErrorCalled = true
        lastErrorMessage = error.errorDescription
    }

    override func navigateToPassiveCapture(validationId: String, uploadUrl: String?) throws {
        navigateToPassiveCaptureCalled = true
        lastValidationId = validationId
        lastUploadUrl = uploadUrl

        if shouldThrowError {
            throw TruoraException.sdk(SDKError(type: .internalError, details: "Navigation error"))
        }
    }
}
