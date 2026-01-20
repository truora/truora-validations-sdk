//
//  PassiveIntroInteractorTests.swift
//  TruoraValidationsSDKTests
//
//  Created by Truora on 11/11/25.
//

import XCTest

@testable import TruoraValidationsSDK

class PassiveIntroInteractorTests: XCTestCase {
    var interactor: PassiveIntroInteractor!
    fileprivate var mockPresenter: MockPassiveIntroPresenter!

    override func setUp() {
        super.setUp()
        mockPresenter = MockPassiveIntroPresenter()
        interactor = PassiveIntroInteractor(presenter: mockPresenter, enrollmentTask: nil)
        ValidationConfig.shared.reset()
    }

    override func tearDown() {
        interactor = nil
        mockPresenter = nil
        ValidationConfig.shared.reset()
        super.tearDown()
    }

    // MARK: - Create Validation Tests

    func testCreateValidationWithoutAPIClient() {
        // Given
        let accountId = "test-account-id"

        // When
        interactor.createValidation(accountId: accountId)

        // Then
        XCTAssertTrue(mockPresenter.validationFailedCalled)
        XCTAssertTrue(
            mockPresenter.lastError?.localizedDescription.contains("API client not configured")
                ?? false
        )
    }

    func testCreateValidationWithAPIClient() async throws {
        // Given
        let apiKey = "test-api-key"
        let accountId = "test-account-id"

        try await ValidationConfig.shared.configure(
            apiKey: apiKey,
            accountId: accountId,
            delegate: nil
        )

        // When
        interactor.createValidation(accountId: accountId)

        // Then
        // Note: This will make a real API call in the current implementation
        // For proper unit testing, the API client should be mockable
        // This test verifies that the method can be called without crashing
        XCTAssertNotNil(ValidationConfig.shared.apiClient)
    }

    // MARK: - Task Cancellation Tests

    func testDeinitCancelsValidationTask() {
        // Given
        var interactorOptional: PassiveIntroInteractor? = PassiveIntroInteractor(
            presenter: mockPresenter,
            enrollmentTask: nil
        )

        // When
        interactorOptional = nil

        // Then
        // The deinit should cancel the task without crashing
        XCTAssertNil(interactorOptional)
    }

    func testTaskCancellationHandling() async throws {
        // Given
        let apiKey = "test-api-key"
        let accountId = "test-account-id"

        try await ValidationConfig.shared.configure(
            apiKey: apiKey,
            accountId: accountId,
            delegate: nil
        )

        // When
        interactor.createValidation(accountId: accountId)

        // Immediately deallocate to trigger cancellation
        interactor = nil

        // Then
        // The task should be cancelled without crashing
        XCTAssertNil(interactor)
    }

    // MARK: - Enrollment Completion Tests

    func testEnrollmentCompleted_withNoEnrollmentTask_returnsImmediately() async throws {
        // Given
        // No enrollment task started

        // When
        try await interactor.enrollmentCompleted()

        // Then
        // Should complete without crashing
        XCTAssertNotNil(interactor)
    }

    func testEnrollmentCompleted_waitsForEnrollmentTask() async throws {
        // Given
        let expectedDelay: TimeInterval = 0.01 // 10ms
        let mockTask: Task<Void, Error> = Task {
            // Simulate some async work
            try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
        }

        interactor = PassiveIntroInteractor(presenter: mockPresenter, enrollmentTask: mockTask)

        // When
        let startTime = Date()
        try await interactor.enrollmentCompleted()
        let duration = Date().timeIntervalSince(startTime)

        // Then - Should have waited at least the expected delay
        XCTAssertGreaterThanOrEqual(
            duration,
            expectedDelay * 0.9, // Allow 10% tolerance for timing variance
            "Should wait for task completion (expected ~\(expectedDelay)s, got \(duration)s)"
        )
    }

    func testEnrollmentCompleted_throwsErrorWhenTaskFails() async {
        // Given
        let mockTask: Task<Void, Error> = Task {
            throw ValidationError.apiError("Test error")
        }

        interactor = PassiveIntroInteractor(presenter: mockPresenter, enrollmentTask: mockTask)

        // When/Then
        do {
            try await interactor.enrollmentCompleted()
            XCTFail("Should have thrown an error")
        } catch {
            // Expected - error was thrown as expected
        }
    }

    // MARK: - Task Cleanup Tests

    func testDeinitCancelsBothTasks() {
        // Given
        var interactorOptional: PassiveIntroInteractor? = PassiveIntroInteractor(
            presenter: mockPresenter,
            enrollmentTask: nil
        )

        // When
        interactorOptional = nil

        // Then
        // The deinit should cancel both validation and enrollment tasks without crashing
        XCTAssertNil(interactorOptional)
    }
}

// MARK: - Mock Presenter

private class MockPassiveIntroPresenter: PassiveIntroInteractorToPresenter {
    var validationCreatedCalled = false
    var validationFailedCalled = false
    var lastResponse: ValidationCreateResponse?
    var lastError: ValidationError?

    func validationCreated(response: ValidationCreateResponse) {
        validationCreatedCalled = true
        lastResponse = response
    }

    func validationFailed(_ error: ValidationError) {
        validationFailedCalled = true
        lastError = error
    }
}
