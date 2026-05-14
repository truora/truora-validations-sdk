//
//  UploadUrlValidatorTests.swift
//  TruoraValidationsSDKTests
//
//  Created by Truora on 30/01/26.
//

import XCTest
@testable import TruoraValidationsSDK

@MainActor final class UploadUrlValidatorTests: XCTestCase {
    // MARK: - isTruoraFilesUploadUrl Tests

    func testIsTruoraFilesUploadUrl_withMatchingPrefix_returnsTrue() {
        let url = UploadUrlValidator.truoraFilesUploadURLPrefix + "path/to/object?Expires=1"
        XCTAssertTrue(UploadUrlValidator.isTruoraFilesUploadUrl(url))
    }

    func testIsTruoraFilesUploadUrl_withWrongHost_returnsFalse() {
        XCTAssertFalse(UploadUrlValidator.isTruoraFilesUploadUrl("https://files.evil.com/path"))
    }

    // MARK: - isExpired Tests

    func testIsExpired_whenTimestampInFuture_returnsFalse() {
        // Given: URL expiring 1 hour from now
        let futureTimestamp = Date().timeIntervalSince1970 + 3600
        let url = "https://s3.amazonaws.com/bucket/file?Expires=\(Int(futureTimestamp))"

        // When
        let result = UploadUrlValidator.isExpired(url)

        // Then
        XCTAssertFalse(result, "URL expiring in the future should not be expired")
    }

    func testIsExpired_whenTimestampInPast_returnsTrue() {
        // Given: URL that expired 1 hour ago
        let pastTimestamp = Date().timeIntervalSince1970 - 3600
        let url = "https://s3.amazonaws.com/bucket/file?Expires=\(Int(pastTimestamp))"

        // When
        let result = UploadUrlValidator.isExpired(url)

        // Then
        XCTAssertTrue(result, "URL that expired in the past should be expired")
    }

    func testIsExpired_whenTimestampIsNow_returnsTrue() {
        // Given: URL expiring now
        let currentTimestamp: TimeInterval = 1_738_250_000
        let url = "https://s3.amazonaws.com/bucket/file?Expires=\(Int(currentTimestamp))"

        // When
        let result = UploadUrlValidator.isExpired(url, currentTimestamp: currentTimestamp)

        // Then
        XCTAssertTrue(result, "URL expiring at current time should be considered expired")
    }

    func testIsExpired_whenNoExpiresParam_returnsFalse() {
        // Given: URL without Expires parameter
        let url = "https://s3.amazonaws.com/bucket/file?AWSAccessKeyId=abc&Signature=xyz"

        // When
        let result = UploadUrlValidator.isExpired(url)

        // Then
        XCTAssertFalse(result, "URL without Expires should not be considered expired")
    }

    func testIsExpired_whenInvalidUrl_returnsFalse() {
        // Given: Invalid URL string
        let url = "not a valid url"

        // When
        let result = UploadUrlValidator.isExpired(url)

        // Then
        XCTAssertFalse(result, "Invalid URL should not be considered expired")
    }

    func testIsExpired_withInjectableTimestamp_worksCorrectly() {
        // Given: Fixed timestamps for testing
        let expirationTimestamp: TimeInterval = 1_738_250_000
        let url = "https://s3.amazonaws.com/bucket/file?Expires=\(Int(expirationTimestamp))"

        // When: current time is before expiration
        let beforeTs = expirationTimestamp - 1
        let beforeResult = UploadUrlValidator.isExpired(url, currentTimestamp: beforeTs)

        // Then
        let msg1 = "Should not be expired when current time is before expiration"
        XCTAssertFalse(beforeResult, msg1)

        // When: current time is after expiration
        let afterTs = expirationTimestamp + 1
        let afterResult = UploadUrlValidator.isExpired(url, currentTimestamp: afterTs)

        // Then
        XCTAssertTrue(afterResult, "Should be expired when current time is after expiration")
    }

    // MARK: - getExpirationTimestamp Tests

    func testGetExpirationTimestamp_returnsCorrectValue() {
        // Given
        let expectedTimestamp: TimeInterval = 1_738_250_000
        let url = "https://s3.amazonaws.com/bucket/file?Expires=\(Int(expectedTimestamp))"

        // When
        let result = UploadUrlValidator.getExpirationTimestamp(from: url)

        // Then
        XCTAssertEqual(result, expectedTimestamp)
    }

    func testGetExpirationTimestamp_withMultipleParams_returnsCorrectValue() {
        // Given
        let expectedTimestamp: TimeInterval = 1_738_250_000
        let url = "https://s3.amazonaws.com/bucket/file"
            + "?AWSAccessKeyId=abc&Expires=\(Int(expectedTimestamp))&Signature=xyz"

        // When
        let result = UploadUrlValidator.getExpirationTimestamp(from: url)

        // Then
        XCTAssertEqual(result, expectedTimestamp)
    }

    func testGetExpirationTimestamp_whenNoExpires_returnsNil() {
        // Given
        let url = "https://s3.amazonaws.com/bucket/file?AWSAccessKeyId=abc&Signature=xyz"

        // When
        let result = UploadUrlValidator.getExpirationTimestamp(from: url)

        // Then
        XCTAssertNil(result)
    }

    func testGetExpirationTimestamp_whenInvalidExpires_returnsNil() {
        // Given
        let url = "https://s3.amazonaws.com/bucket/file?Expires=invalid"

        // When
        let result = UploadUrlValidator.getExpirationTimestamp(from: url)

        // Then
        XCTAssertNil(result)
    }

    func testGetExpirationTimestamp_whenEmptyExpires_returnsNil() {
        // Given
        let url = "https://s3.amazonaws.com/bucket/file?Expires="

        // When
        let result = UploadUrlValidator.getExpirationTimestamp(from: url)

        // Then
        XCTAssertNil(result)
    }

    func testGetExpirationTimestamp_whenInvalidUrl_returnsNil() {
        // Given
        let url = "not a valid url"

        // When
        let result = UploadUrlValidator.getExpirationTimestamp(from: url)

        // Then
        XCTAssertNil(result)
    }

    func testGetExpirationTimestamp_withRealS3Url_worksCorrectly() {
        // Given: A realistic S3 presigned URL format
        let url = "https://truora-bucket.s3.amazonaws.com/uploads/video.mp4"
            + "?AWSAccessKeyId=AKIAIOSFODNN7EXAMPLE"
            + "&Expires=1738250000"
            + "&Signature=OtxrzxIsfpFjA7SwPzILwy8Bw21TLhquhboDYROV"

        // When
        let result = UploadUrlValidator.getExpirationTimestamp(from: url)

        // Then
        XCTAssertEqual(result, 1_738_250_000)
    }
}
