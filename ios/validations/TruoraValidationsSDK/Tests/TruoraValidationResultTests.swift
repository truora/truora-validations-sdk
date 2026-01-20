//
//  TruoraValidationResultTests.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 17/11/25.
//

import XCTest
@testable import TruoraValidationsSDK

final class TruoraValidationResultTests: XCTestCase {
    // MARK: - Initialization Tests

    func testCompleteCase() {
        // Given
        let validationResult = ValidationResult(
            validationId: "test-id",
            status: .success,
            confidence: 0.95,
            metadata: nil
        )

        // When
        let result: TruoraValidationResult<ValidationResult> = .complete(validationResult)

        // Then
        XCTAssertTrue(result.isComplete, "Should be complete")
        XCTAssertFalse(result.isFailure, "Should not be failure")
        XCTAssertFalse(result.isCapture, "Should not be capture")
        XCTAssertEqual(result.completionValue?.validationId, "test-id", "Should have completion value")
    }

    func testFailureCase() {
        // Given
        let error = ValidationError.invalidConfiguration("Test error")

        // When
        let result: TruoraValidationResult<ValidationResult> = .failure(error)

        // Then
        XCTAssertFalse(result.isComplete, "Should not be complete")
        XCTAssertTrue(result.isFailure, "Should be failure")
        XCTAssertFalse(result.isCapture, "Should not be capture")
        XCTAssertNotNil(result.error, "Should have error")
    }

    func testCaptureCase() {
        // Given
        let media = CapturedMedia(
            type: .photo,
            timestamp: Date()
        )

        // When
        let result: TruoraValidationResult<ValidationResult> = .capture(media)

        // Then
        XCTAssertFalse(result.isComplete, "Should not be complete")
        XCTAssertFalse(result.isFailure, "Should not be failure")
        XCTAssertTrue(result.isCapture, "Should be capture")
        XCTAssertNotNil(result.capturedMedia, "Should have captured media")
    }

    // MARK: - Convenience Property Tests

    func testCompletionValueForComplete() {
        // Given
        let validationResult = ValidationResult(
            validationId: "test-id",
            status: .success,
            confidence: 0.95,
            metadata: nil
        )
        let result: TruoraValidationResult<ValidationResult> = .complete(validationResult)

        // When
        let value = result.completionValue

        // Then
        XCTAssertNotNil(value, "Should have completion value")
        XCTAssertEqual(
            value?.validationId,
            "test-id",
            "Should match validation result"
        )
    }

    func testCompletionValueForNonComplete() {
        // Given
        let result: TruoraValidationResult<ValidationResult> = .failure(.cancelled)

        // When
        let value = result.completionValue

        // Then
        XCTAssertNil(value, "Should not have completion value")
    }

    func testErrorForFailure() {
        // Given
        let error = ValidationError.networkError("Network failed")
        let result: TruoraValidationResult<ValidationResult> = .failure(error)

        // When
        let extractedError = result.error

        // Then
        XCTAssertNotNil(extractedError, "Should have error")
        if case .networkError(let message) = extractedError {
            XCTAssertEqual(message, "Network failed", "Should match error message")
        } else {
            XCTFail("Should be network error")
        }
    }

    func testErrorForNonFailure() {
        // Given
        let validationResult = ValidationResult(
            validationId: "test-id",
            status: .success,
            confidence: 0.95,
            metadata: nil
        )
        let result: TruoraValidationResult<ValidationResult> = .complete(validationResult)

        // When
        let error = result.error

        // Then
        XCTAssertNil(error, "Should not have error")
    }

    func testCapturedMediaForCapture() {
        // Given
        let media = CapturedMedia(
            type: .video,
            timestamp: Date()
        )
        let result: TruoraValidationResult<ValidationResult> = .capture(media)

        // When
        let extractedMedia = result.capturedMedia

        // Then
        XCTAssertNotNil(extractedMedia, "Should have captured media")
        XCTAssertEqual(extractedMedia?.type, .video, "Should match media type")
    }

    func testCapturedMediaForNonCapture() {
        // Given
        let result: TruoraValidationResult<ValidationResult> = .failure(.cancelled)

        // When
        let media = result.capturedMedia

        // Then
        XCTAssertNil(media, "Should not have captured media")
    }

    // MARK: - Equatable Tests

    func testEqualityForComplete() {
        // Given
        let result1 = ValidationResult(validationId: "id1", status: .success, confidence: 0.9, metadata: nil)
        let result2 = ValidationResult(validationId: "id1", status: .success, confidence: 0.9, metadata: nil)

        let validation1: TruoraValidationResult<ValidationResult> = .complete(result1)
        let validation2: TruoraValidationResult<ValidationResult> = .complete(result2)

        // Then
        XCTAssertEqual(validation1, validation2, "Should be equal for same completion values")
    }

    func testEqualityForFailure() {
        // Given
        let validation1: TruoraValidationResult<ValidationResult> = .failure(.cancelled)
        let validation2: TruoraValidationResult<ValidationResult> = .failure(.cancelled)

        // Then
        XCTAssertEqual(validation1, validation2, "Should be equal for same error")
    }

    func testEqualityForCapture() {
        // Given
        let timestamp = Date()
        let media1 = CapturedMedia(type: .photo, timestamp: timestamp)
        let media2 = CapturedMedia(type: .photo, timestamp: timestamp)

        let validation1: TruoraValidationResult<ValidationResult> = .capture(media1)
        let validation2: TruoraValidationResult<ValidationResult> = .capture(media2)

        // Then
        XCTAssertEqual(validation1, validation2, "Should be equal for same captured media")
    }

    func testInequalityBetweenDifferentCases() {
        // Given
        let validationResult = ValidationResult(validationId: "id", status: .success, confidence: 0.9, metadata: nil)
        let complete: TruoraValidationResult<ValidationResult> = .complete(validationResult)
        let failure: TruoraValidationResult<ValidationResult> = .failure(.cancelled)
        let media = CapturedMedia(type: .photo, timestamp: Date())
        let capture: TruoraValidationResult<ValidationResult> = .capture(media)

        // Then
        XCTAssertNotEqual(complete, failure, "Complete should not equal failure")
        XCTAssertNotEqual(complete, capture, "Complete should not equal capture")
        XCTAssertNotEqual(failure, capture, "Failure should not equal capture")
    }

    // MARK: - CustomStringConvertible Tests

    func testDescriptionForComplete() {
        // Given
        let validationResult = ValidationResult(
            validationId: "test-id",
            status: .success,
            confidence: 0.9,
            metadata: nil
        )
        let result: TruoraValidationResult<ValidationResult> = .complete(validationResult)

        // When
        let description = result.description

        // Then
        XCTAssertTrue(description.contains("complete"), "Description should contain 'complete'")
    }

    func testDescriptionForFailure() {
        // Given
        let result: TruoraValidationResult<ValidationResult> = .failure(.cancelled)

        // When
        let description = result.description

        // Then
        XCTAssertTrue(description.contains("failure"), "Description should contain 'failure'")
    }

    func testDescriptionForCapture() {
        // Given
        let media = CapturedMedia(type: .photo, timestamp: Date())
        let result: TruoraValidationResult<ValidationResult> = .capture(media)

        // When
        let description = result.description

        // Then
        XCTAssertTrue(description.contains("capture"), "Description should contain 'capture'")
    }
}
