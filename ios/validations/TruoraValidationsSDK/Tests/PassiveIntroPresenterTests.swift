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
final class PassiveIntroPresenterTests: XCTestCase {
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

    func testViewDidLoad_doesNotCrash() {
        // When
        sut.viewDidLoad()

        // Then
        XCTAssertNotNil(sut, "Presenter should remain initialized after viewDidLoad")
    }

    // MARK: - Start Validation Tests

    func testStartTapped_withoutAccountId_showsError() {
        // Given
        XCTAssertNil(ValidationConfig.shared.accountId, "Account ID should be nil initially")

        // When
        sut.startTapped()

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
        sut.startTapped()

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
        sut.startTapped()

        // Then - wait for actual completion
        wait(for: [enrollmentExpectation, validationExpectation], timeout: 1.0, enforceOrder: true)

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
        sut.startTapped()

        // Then - wait for actual completion with enforced order
        wait(for: [enrollmentExpectation, validationExpectation], timeout: 1.0, enforceOrder: true)

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
        sut.startTapped()

        // Then - wait for enrollment to fail
        wait(for: [enrollmentExpectation], timeout: 1.0)

        // Give time for error handling to propagate
        let errorHandlingExpectation = expectation(description: "Error handling")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            errorHandlingExpectation.fulfill()
        }
        wait(for: [errorHandlingExpectation], timeout: 1.0)

        XCTAssertTrue(mockView.showLoadingCalled, "Should show loading initially")
        XCTAssertTrue(mockInteractor.enrollmentCompletedCalled, "Should call enrollmentCompleted")
        XCTAssertFalse(mockInteractor.createValidationCalled, "Should NOT call createValidation on failure")
        XCTAssertTrue(mockRouter.handleErrorCalled, "Should call router handleError on enrollment failure")
    }

    // MARK: - Cancel Tests

    func testCancelTapped_callsRouter() {
        // When
        sut.cancelTapped()

        // Then
        XCTAssertTrue(
            mockRouter.handleCancellationCalled,
            "Should call router to handle cancellation"
        )
    }

    // MARK: - Validation Created Tests

    func testValidationCreated_withValidResponse_navigatesToPassiveCapture() {
        // Given
        let mockResponse = MockResponseBuilder.validationCreateResponse(
            validationId: "mock-validation-id",
            accountId: "test-account-id",
            instructions: MockResponseBuilder.validationInstructions(
                fileUploadLink: "https://example.com/upload"
            )
        )

        // When
        sut.validationCreated(response: mockResponse)

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

    func testValidationCreated_withNilInstructions_navigatesWithNilUploadUrl() {
        // Given
        let mockResponse = MockResponseBuilder.validationCreateResponse(
            validationId: "mock-validation-id",
            instructions: nil
        )

        // When
        sut.validationCreated(response: mockResponse)

        // Then
        XCTAssertTrue(mockView.hideLoadingCalled, "Should hide loading")
        XCTAssertTrue(
            mockRouter.navigateToPassiveCaptureCalled,
            "Should navigate despite nil instructions"
        )
        XCTAssertNil(mockRouter.lastUploadUrl, "Upload URL should be nil when instructions are nil")
    }

    func testValidationCreated_whenRouterDeallocated_showsError() {
        // Given
        // Create a weak reference scenario by using a temporary router
        var tempRouter: MockPassiveIntroRouter? = MockPassiveIntroRouter(
            navigationController: UINavigationController()
        )
        sut = PassiveIntroPresenter(
            view: mockView,
            interactor: mockInteractor,
            router: tempRouter!
        )

        // Deallocate the router to simulate weak reference becoming nil
        tempRouter = nil

        let mockResponse = MockResponseBuilder.validationCreateResponse()

        // When
        sut.validationCreated(response: mockResponse)

        // Then
        XCTAssertTrue(mockView.hideLoadingCalled, "Should hide loading")
        XCTAssertTrue(mockView.showErrorCalled, "Should show error when router is deallocated")
        XCTAssertTrue(
            mockView.lastErrorMessage?.contains("Router not configured") ?? false,
            "Error message should mention router not configured"
        )
    }

    func testValidationCreated_withNavigationError_showsError() {
        // Given
        mockRouter.shouldThrowError = true
        let mockResponse = MockResponseBuilder.validationCreateResponse()

        // When
        sut.validationCreated(response: mockResponse)

        // Then
        XCTAssertTrue(mockView.hideLoadingCalled, "Should hide loading before showing error")
        XCTAssertTrue(mockView.showErrorCalled, "Should show error when navigation fails")
        XCTAssertNotNil(mockView.lastErrorMessage, "Error message should be present")
    }

    // MARK: - Validation Failed Tests

    func testValidationFailed_hidesLoadingAndShowsError() {
        // Given
        let expectedError = ValidationError.apiError("Network connection failed")

        // When
        sut.validationFailed(expectedError)

        // Then
        XCTAssertTrue(mockView.hideLoadingCalled, "Should hide loading on validation failure")
        XCTAssertTrue(
            mockRouter.handleErrorCalled,
            "Should call router handle error on validation failure"
        )
        XCTAssertEqual(
            mockRouter.lastErrorMessage,
            expectedError.localizedDescription,
            "Should show the error's localized description"
        )
    }

    func testValidationFailed_withDifferentErrorTypes_displaysAppropriateMessages() {
        // Test different error types
        let errorTypes: [ValidationError] = [
            .invalidConfiguration("Invalid config"),
            .apiError("API failed"),
            .internalError("Internal error")
        ]

        for error in errorTypes {
            // Given
            setUp() // Reset for each iteration

            // When
            sut.validationFailed(error)

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

private final class MockPassiveIntroView: PassiveIntroPresenterToView {
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

private final class MockPassiveIntroInteractor: PassiveIntroPresenterToInteractor {
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
            throw ValidationError.apiError("Mock enrollment error")
        }
    }
}

// MARK: - Mock Router

private final class MockPassiveIntroRouter: ValidationRouter {
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

    override func handleError(_ error: ValidationError) {
        handleErrorCalled = true
        lastErrorMessage = error.localizedDescription
    }

    override func navigateToPassiveCapture(validationId: String, uploadUrl: String?) throws {
        navigateToPassiveCaptureCalled = true
        lastValidationId = validationId
        lastUploadUrl = uploadUrl

        if shouldThrowError {
            throw ValidationError.internalError("Navigation error")
        }
    }
}
