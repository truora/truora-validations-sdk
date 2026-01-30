//
//  ValidationConfigTests.swift
//  TruoraValidationsSDKTests
//
//  Created by Truora on 11/11/25.
//

import XCTest
@testable import TruoraValidationsSDK

@MainActor class ValidationConfigTests: XCTestCase {
    override func setUp() {
        super.setUp()
        ValidationConfig.shared.reset()
    }

    override func tearDown() {
        ValidationConfig.shared.reset()
        super.tearDown()
    }

    // MARK: - Configuration Tests

    func testConfigureWithValidAccountId() async throws {
        // Given
        let apiKey = "test-api-key"
        let accountId = "test-account-id"

        // When
        try await ValidationConfig.shared.configure(
            apiKey: apiKey,
            accountId: accountId
        )

        // Then
        XCTAssertNotNil(ValidationConfig.shared.apiClient)
        XCTAssertEqual(ValidationConfig.shared.accountId, accountId)
    }

    func testConfigureWithEmptyApiKeyThrowsError() async {
        // Given
        let emptyApiKey = ""
        let accountId = "test-account-id"

        // When/Then
        do {
            try await ValidationConfig.shared.configure(
                apiKey: emptyApiKey,
                accountId: accountId
            )
            XCTFail("Expected error to be thrown")
        } catch let error as TruoraException {
            guard case .sdk(let sdkError) = error,
                  sdkError.type == .invalidConfiguration else {
                XCTFail("Expected SDK invalidConfiguration error")
                return
            }
            XCTAssertNotNil(sdkError.details, "Error details should not be nil")
            XCTAssertTrue(
                sdkError.details?.contains("API key") == true,
                "Error details should mention 'API key'"
            )
        } catch {
            XCTFail("Expected TruoraException, got \(error)")
        }
    }

    func testConfigureWithEnrollmentDataAndEmptyAccountIdThrowsError() async {
        // Given
        let apiKey = "test-api-key"
        let enrollmentData = EnrollmentData(
            enrollmentId: "test-enrollment",
            accountId: "",
            uploadUrl: nil,
            createdAt: Date()
        )

        // When/Then
        do {
            try await ValidationConfig.shared.configure(
                apiKey: apiKey,
                enrollmentData: enrollmentData
            )
            XCTFail("Expected error to be thrown")
        } catch let error as TruoraException {
            guard case .sdk(let sdkError) = error,
                  sdkError.type == .invalidConfiguration else {
                XCTFail("Expected SDK invalidConfiguration error")
                return
            }
            XCTAssertNotNil(sdkError.details, "Error details should not be nil")
            XCTAssertTrue(
                sdkError.details?.contains("Account ID") == true,
                "Error details should mention 'Account ID'"
            )
        } catch {
            XCTFail("Expected TruoraException, got \(error)")
        }
    }

    func testResetClearsConfiguration() async throws {
        // Given
        let apiKey = "test-api-key"
        let accountId = "test-account-id"
        try await ValidationConfig.shared.configure(
            apiKey: apiKey,
            accountId: accountId
        )

        // When
        ValidationConfig.shared.reset()

        // Then
        XCTAssertNil(ValidationConfig.shared.apiClient)
        XCTAssertNil(ValidationConfig.shared.accountId)
        XCTAssertNil(ValidationConfig.shared.delegate)
        XCTAssertNil(ValidationConfig.shared.enrollmentData)
    }

    func testConfigureWithDelegateStoresDelegate() async throws {
        // Given
        let apiKey = "test-api-key"
        let accountId = "test-account-id"
        let mockDelegate = MockValidationDelegate()

        // When
        try await ValidationConfig.shared.configure(
            apiKey: apiKey,
            accountId: accountId,
            delegate: mockDelegate.closure
        )

        // Then
        XCTAssertNotNil(ValidationConfig.shared.delegate)
    }
}

// MARK: - Test Helpers

@MainActor private class MockValidationDelegate {
    var completionCalled = false
    var failureCalled = false
    var cancellationCalled = false
    var captureCalled = false
    var lastResult: ValidationResult?
    var lastError: TruoraException?

    var closure: (TruoraValidationResult<ValidationResult>) -> Void {
        { [unowned self] result in
            switch result {
            case .complete(let validationResult):
                self.completionCalled = true
                self.lastResult = validationResult
            case .failure(let err):
                switch err {
                case .sdk(let sdkError) where sdkError.type == .processCancelledByUser:
                    self.cancellationCalled = true
                default:
                    self.failureCalled = true
                    self.lastError = err
                }
            case .capture:
                self.captureCalled = true
            }
        }
    }
}
