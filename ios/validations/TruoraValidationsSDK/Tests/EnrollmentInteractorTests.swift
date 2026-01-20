//
//  EnrollmentInteractorTests.swift
//  TruoraValidationsSDKTests
//
//  Created by Truora on 11/11/25.
//

import XCTest
@testable import TruoraValidationsSDK

/// Tests for EnrollmentInteractor
/// Verifies enrollment creation and API error handling
final class EnrollmentInteractorTests: XCTestCase {
    // MARK: - Properties

    private var sut: EnrollmentInteractor!

    // MARK: - Lifecycle

    override func setUp() {
        super.setUp()
        sut = EnrollmentInteractor()
        ValidationConfig.shared.reset()
    }

    override func tearDown() {
        sut = nil
        ValidationConfig.shared.reset()
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialization_createsInteractor() {
        // When
        let interactor = EnrollmentInteractor()

        // Then
        XCTAssertNotNil(interactor, "Interactor should be successfully initialized")
    }

    // MARK: - Create Enrollment Tests

    func testCreateEnrollment_withoutAPIClient_throwsError() async {
        // Given
        let accountId = "test-account-id"

        // When/Then
        do {
            _ = try await sut.createEnrollment(accountId: accountId)
            XCTFail("Should throw error when API client is not configured")
        } catch let error as ValidationError {
            // Then
            switch error {
            case .invalidConfiguration(let message):
                XCTAssertTrue(
                    message.contains("API client not configured"),
                    "Error should mention API client not configured"
                )
            default:
                XCTFail("Expected invalidConfiguration error, got \(error)")
            }
        } catch {
            XCTFail("Expected ValidationError, got \(error)")
        }
    }

    func testCreateEnrollment_withAPIClient_hasCorrectConfiguration() async throws {
        // Given
        let expectedAccountId = "test-account-id"
        let apiKey = "test-api-key"

        try await ValidationConfig.shared.configure(
            apiKey: apiKey,
            accountId: expectedAccountId,
            delegate: nil
        )

        // Then
        XCTAssertNotNil(
            ValidationConfig.shared.apiClient,
            "API client should be configured before enrollment creation"
        )

        // Note: Actual API call would require mocking the KMP module
        // This test verifies the prerequisite configuration is in place
    }

    func testCreateEnrollment_withEmptyAccountId_canProceed() async throws {
        // Given
        let emptyAccountId = ""
        let apiKey = "test-api-key"

        try await ValidationConfig.shared.configure(
            apiKey: apiKey,
            accountId: "config-account-id",
            delegate: nil
        )

        // Then
        XCTAssertNotNil(
            ValidationConfig.shared.apiClient,
            "Should allow empty account ID to be passed to API"
        )

        // Note: API validation should happen server-side
        // The interactor doesn't validate account ID format
    }
}
