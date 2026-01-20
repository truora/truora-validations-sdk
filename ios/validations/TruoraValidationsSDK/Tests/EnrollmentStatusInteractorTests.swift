//
//  EnrollmentStatusInteractorTests.swift
//  TruoraValidationsSDKTests
//
//  Created by Truora on 11/11/25.
//

import XCTest
@testable import TruoraValidationsSDK

class EnrollmentStatusInteractorTests: XCTestCase {
    var interactor: EnrollmentStatusInteractor!
    fileprivate var mockPresenter: MockEnrollmentStatusPresenter!

    override func setUp() {
        super.setUp()
        mockPresenter = MockEnrollmentStatusPresenter()
        interactor = EnrollmentStatusInteractor(presenter: mockPresenter)
        ValidationConfig.shared.reset()
    }

    override func tearDown() {
        interactor = nil
        mockPresenter = nil
        ValidationConfig.shared.reset()
        super.tearDown()
    }

    // MARK: - Check Enrollment Status Tests

    func testCheckEnrollmentStatusWithoutAPIClient() {
        // Given
        let enrollmentId = "test-enrollment-id"

        // When
        interactor.checkEnrollmentStatus(enrollmentId: enrollmentId)

        // Then
        XCTAssertTrue(mockPresenter.failedCalled)
        XCTAssertTrue(mockPresenter.lastError?.contains("API client not configured") ?? false)
    }

    func testCheckEnrollmentStatusWithValidAPIClient() async throws {
        // Given
        let enrollmentId = "test-enrollment-id"
        let apiKey = "test-api-key"
        let accountId = "test-account-id"

        try await ValidationConfig.shared.configure(
            apiKey: apiKey,
            accountId: accountId,
            delegate: nil
        )

        // When
        interactor.checkEnrollmentStatus(enrollmentId: enrollmentId)

        // Then
        // Note: This will make a real API call in the current implementation
        // For proper unit testing, the API client should be mockable
        // This test verifies that the method can be called without crashing
        XCTAssertNotNil(ValidationConfig.shared.apiClient)
    }
}

// MARK: - Mock Presenter

private class MockEnrollmentStatusPresenter: EnrollmentStatusInteractorToPresenter {
    var completedCalled = false
    var failedCalled = false
    var lastStatus: String?
    var lastError: String?

    func enrollmentCheckCompleted(status: String) {
        completedCalled = true
        lastStatus = status
    }

    func enrollmentCheckFailed(error: String) {
        failedCalled = true
        lastError = error
    }
}
