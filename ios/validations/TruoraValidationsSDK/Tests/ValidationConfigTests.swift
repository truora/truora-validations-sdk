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

    func testClearValidationId_keepsTheRestOfTheConfiguration() async throws {
        try await ValidationConfig.shared.configure(apiKey: "test-api-key", accountId: "test-account-id")
        ValidationConfig.shared.updateValidationId("dummy-validation-id")

        ValidationConfig.shared.clearValidationId()

        XCTAssertNil(ValidationConfig.shared.validationId)
        XCTAssertEqual(ValidationConfig.shared.accountId, "test-account-id")
        XCTAssertNotNil(ValidationConfig.shared.apiClient)
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

    // MARK: - Passport Autocapture Validation Tests

    func testSetValidation_passportWithDefaultAutocapture_shouldSucceed() {
        // Given — No explicit useAutocapture call.
        // setDocumentType("passport") silently disables autocapture and
        // didExplicitlyEnableAutocapture is false, so validation passes.
        let document = Document()
            .setDocumentType("passport")

        // When/Then — should not throw
        XCTAssertNoThrow(
            try ValidationConfig.shared.setValidation(.document(document))
        )
        XCTAssertEqual(ValidationConfig.shared.documentConfig.documentType, "passport")
        XCTAssertFalse(ValidationConfig.shared.documentConfig.useAutocapture)
    }

    func testSetValidation_useAutocaptureThenPassport_shouldThrow() {
        // Given — Developer misconfiguration: useAutocapture(true) then passport.
        // setDocumentType silently disables autocapture but keeps the explicit
        // flag, so validateAutocaptureConfig throws a catchable TruoraException.
        let document = Document()
            .useAutocapture(true)
            .setDocumentType("passport")

        // When/Then — should throw invalidConfiguration
        XCTAssertThrowsError(
            try ValidationConfig.shared.setValidation(.document(document))
        )
    }

    func testSetValidation_passportThenExplicitAutocapture_shouldThrow() {
        // Given — Developer misconfiguration: passport then useAutocapture(true).
        // useAutocapture keeps autocapture disabled (enabled && !isPassport) but
        // sets didExplicitlyEnableAutocapture, so validateAutocaptureConfig throws.
        let document = Document()
            .setDocumentType("passport")
            .useAutocapture(true)

        // When/Then — should throw invalidConfiguration
        XCTAssertThrowsError(
            try ValidationConfig.shared.setValidation(.document(document))
        )
    }

    func testSetValidation_runtimePassportAfterExplicitAutocapture_shouldSucceed() {
        // Given — Simulates the document selection presenter flow:
        // developer enabled autocapture via Builder (no document type),
        // then the user picks passport at runtime via applyRuntimeDocumentType.
        let document = Document()
            .useAutocapture(true)
            .applyRuntimeDocumentType("passport")

        // When/Then — should not throw (runtime selection resets the flag)
        XCTAssertNoThrow(
            try ValidationConfig.shared.setValidation(.document(document))
        )
        XCTAssertEqual(ValidationConfig.shared.documentConfig.documentType, "passport")
        XCTAssertFalse(ValidationConfig.shared.documentConfig.useAutocapture)
    }

    func testSetValidation_passportWithAutocaptureDisabled_shouldSucceed() {
        // Given
        let document = Document()
            .setDocumentType("passport")
            .useAutocapture(false)

        // When/Then — should not throw
        XCTAssertNoThrow(
            try ValidationConfig.shared.setValidation(.document(document))
        )
        XCTAssertEqual(ValidationConfig.shared.documentConfig.documentType, "passport")
        XCTAssertFalse(ValidationConfig.shared.documentConfig.useAutocapture)
    }

    func testSetValidation_nonPassportWithAutocapture_shouldSucceed() {
        // Given
        let document = Document()
            .setDocumentType("national-id")
            .useAutocapture(true)

        // When/Then — should not throw
        XCTAssertNoThrow(
            try ValidationConfig.shared.setValidation(.document(document))
        )
        XCTAssertEqual(ValidationConfig.shared.documentConfig.documentType, "national-id")
        XCTAssertTrue(ValidationConfig.shared.documentConfig.useAutocapture)
    }

    func testSetValidation_documentWithNoType_shouldSucceed() {
        // Given — no document type set (user will select later)
        let document = Document()

        // When/Then — should not throw even though autocapture defaults to true
        XCTAssertNoThrow(
            try ValidationConfig.shared.setValidation(.document(document))
        )
    }

    // MARK: - Detection Reporter Forwarding Tests

    func testUpdateValidationId_forwardsToReporter() async throws {
        // Given: inject a DetectionReporter backed by a mock bridge into ValidationConfig.shared
        let detector = InjectionDetector()
        let logger = MockDetectionLogger()
        let mockBridge = MockDetectionBridge()
        let reporter = detector.createReporter(
            logger: logger,
            flowType: "face",
            bridge: mockBridge
        )
        ValidationConfig.shared.setDetectionReporterForTesting(reporter)

        // When: call updateValidationId — forwards to reporter via fire-and-forget Task
        ValidationConfig.shared.updateValidationId("test-val-id")

        // Allow the fire-and-forget Task to execute
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Trigger signReport by calling reportLayer
        _ = await reporter.reportLayer("camera")

        // Then: the forwarded validationId must appear in signReport arguments
        XCTAssertEqual(
            mockBridge.lastSignReportValidationId,
            "test-val-id",
            "ValidationConfig.updateValidationId must forward to DetectionReporter.updateValidationId"
        )
    }
}

// MARK: - Test Helpers

@MainActor private class MockValidationDelegate {
    var completionCalled = false
    var failureCalled = false
    var cancellationCalled = false
    var lastResult: ValidationResult?
    var lastError: TruoraException?

    var closure: (TruoraValidationResult<ValidationResult>) -> Void {
        { [unowned self] result in
            switch result {
            case .completed(let validationResult):
                self.completionCalled = true
                self.lastResult = validationResult
            case .error(let err):
                self.failureCalled = true
                self.lastError = err
            case .canceled:
                self.cancellationCalled = true
            }
        }
    }
}
