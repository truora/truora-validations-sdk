//
//  ValidationConfigTests.swift
//  TruoraValidationsSDKTests
//
//  Created by Truora on 11/11/25.
//

import TruoraShared
import XCTest

@testable import TruoraValidationsSDK

class ValidationConfigTests: XCTestCase {
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
        } catch let error as ValidationError {
            guard case ValidationError.invalidConfiguration(let message) = error else {
                XCTFail("Expected invalidConfiguration error")
                return
            }
            XCTAssertTrue(message.contains("API key"))
        } catch {
            XCTFail("Expected ValidationError, got \(error)")
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
        } catch let error as ValidationError {
            guard case .invalidConfiguration(let message) = error else {
                XCTFail("Expected invalidConfiguration error")
                return
            }
            XCTAssertTrue(message.contains("Account ID"))
        } catch {
            XCTFail("Expected ValidationError, got \(error)")
        }
    }

    func testConfigureWithCustomBaseUrl() async throws {
        // Given
        let apiKey = "test-api-key"
        let accountId = "test-account-id"
        let customBaseUrl = "https://custom.api.com/v1"

        // When
        try await ValidationConfig.shared.configure(
            apiKey: apiKey,
            accountId: accountId,
            baseUrl: customBaseUrl
        )

        // Then
        XCTAssertNotNil(ValidationConfig.shared.apiClient)
    }

    func testConfigureWithValidBaseUrl_createsAPIClient() async throws {
        // Given
        let apiKey = "test-api-key"
        let accountId = "test-account-id"
        let validBaseUrl = "https://api.example.com"

        // When
        try await ValidationConfig.shared.configure(
            apiKey: apiKey,
            accountId: accountId,
            baseUrl: validBaseUrl
        )

        // Then
        XCTAssertNotNil(
            ValidationConfig.shared.apiClient,
            "API client should be created with valid base URL"
        )
    }

    func testConfigureWithEmptyBaseUrlThrowsError() async {
        // Given
        let apiKey = "test-api-key"
        let accountId = "test-account-id"
        let emptyBaseUrl = ""

        // When/Then
        do {
            try await ValidationConfig.shared.configure(
                apiKey: apiKey,
                accountId: accountId,
                baseUrl: emptyBaseUrl
            )
            XCTFail("Expected error to be thrown")
        } catch let error as ValidationError {
            guard case .invalidConfiguration(let message) = error else {
                XCTFail("Expected invalidConfiguration error")
                return
            }
            XCTAssertTrue(message.contains("Base URL"))
        } catch {
            XCTFail("Expected ValidationError, got \(error)")
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

    // MARK: - ComposeConfig Tests

    func testComposeConfigExistsAfterInit() {
        // Then - composeConfig should be available immediately after reset
        ValidationConfig.shared.reset()
        XCTAssertNotNil(
            ValidationConfig.shared.composeConfig,
            "composeConfig should exist after init/reset"
        )
    }

    func testComposeConfigUpdatedAfterConfigure() async throws {
        // Given
        let apiKey = "test-api-key"
        let accountId = "test-account-id"
        let uiConfig = UIConfig()
            .setSurfaceColor("#FFFFFF")
            .setPrimaryColor("#435AE0")

        // When
        try await ValidationConfig.shared.configure(
            apiKey: apiKey,
            accountId: accountId,
            uiConfig: uiConfig
        )

        // Then
        let composeConfig = ValidationConfig.shared.composeConfig
        XCTAssertNotNil(composeConfig.colors?.surface, "composeConfig should have surface color")
        XCTAssertNotNil(composeConfig.colors?.primary, "composeConfig should have primary color")
    }

    func testComposeConfigResetToDefaultAfterReset() async throws {
        // Given - configure with custom colors
        let apiKey = "test-api-key"
        let accountId = "test-account-id"
        let uiConfig = UIConfig()
            .setSurfaceColor("#FF0000")
            .setPrimaryColor("#00FF00")

        try await ValidationConfig.shared.configure(
            apiKey: apiKey,
            accountId: accountId,
            uiConfig: uiConfig
        )

        // Verify colors are set
        XCTAssertNotNil(ValidationConfig.shared.composeConfig.colors?.surface)

        // When
        ValidationConfig.shared.reset()

        // Then - composeConfig should be reset (colors should be nil)
        let resetComposeConfig = ValidationConfig.shared.composeConfig
        XCTAssertNil(
            resetComposeConfig.colors?.surface,
            "composeConfig surface should be nil after reset"
        )
        XCTAssertNil(
            resetComposeConfig.colors?.primary,
            "composeConfig primary should be nil after reset"
        )
    }

    func testComposeConfigWithAllMaterial3Colors() async throws {
        // Given
        let apiKey = "test-api-key"
        let accountId = "test-account-id"
        let uiConfig = UIConfig()
            .setSurfaceColor("#FFFFFF")
            .setOnSurfaceColor("#1F2828")
            .setPrimaryColor("#435AE0")
            .setOnPrimaryColor("#FFFFFF")
            .setSecondaryColor("#082054")
            .setErrorColor("#FF5454")

        // When
        try await ValidationConfig.shared.configure(
            apiKey: apiKey,
            accountId: accountId,
            uiConfig: uiConfig
        )

        // Then
        let composeConfig = ValidationConfig.shared.composeConfig
        XCTAssertNotNil(composeConfig.colors?.surface, "Should have surface")
        XCTAssertNotNil(composeConfig.colors?.onSurface, "Should have onSurface")
        XCTAssertNotNil(composeConfig.colors?.primary, "Should have primary")
        XCTAssertNotNil(composeConfig.colors?.onPrimary, "Should have onPrimary")
        XCTAssertNotNil(composeConfig.colors?.secondary, "Should have secondary")
        XCTAssertNotNil(composeConfig.colors?.error, "Should have error")
    }

    func testComposeConfigWithNoUIConfig() async throws {
        // Given
        let apiKey = "test-api-key"
        let accountId = "test-account-id"

        // When - configure without uiConfig
        try await ValidationConfig.shared.configure(
            apiKey: apiKey,
            accountId: accountId
        )

        // Then - composeConfig should exist with default (nil) colors
        let composeConfig = ValidationConfig.shared.composeConfig
        XCTAssertNotNil(composeConfig, "composeConfig should exist")
        XCTAssertNil(composeConfig.colors?.surface, "Default surface should be nil")
    }
}

// MARK: - Test Helpers

private class MockValidationDelegate {
    var completionCalled = false
    var failureCalled = false
    var cancellationCalled = false
    var captureCalled = false
    var lastResult: ValidationResult?
    var lastError: ValidationError?

    var closure: (TruoraValidationResult<ValidationResult>) -> Void {
        { [unowned self] result in
            switch result {
            case .complete(let validationResult):
                self.completionCalled = true
                self.lastResult = validationResult
            case .failure(let err):
                switch err {
                case .cancelled:
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
