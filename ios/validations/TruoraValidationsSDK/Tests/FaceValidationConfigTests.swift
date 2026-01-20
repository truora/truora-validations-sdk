//
//  FaceValidationConfigTests.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 17/11/25.
//

import XCTest

@testable import TruoraValidationsSDK

final class FaceValidationConfigTests: XCTestCase {
    var sut: Face!

    override func setUp() {
        super.setUp()
        sut = Face()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialState() {
        // Then
        XCTAssertNil(sut.referenceFace, "Reference face should be nil by default")
        XCTAssertEqual(sut.similarityThreshold, 0.8, "Similarity threshold should default to 0.8")
        XCTAssertTrue(sut.shouldWaitForResults, "Should wait for results by default")
        XCTAssertTrue(sut.useAutocapture, "Should use autocapture by default")
        XCTAssertEqual(sut.timeoutSeconds, 60, "Timeout should default to 60 seconds")
    }

    // MARK: - Reference Face Tests

    func testUseReferenceFace() throws {
        // Given
        let referenceFace = try ReferenceFace.from("https://example.com/face.jpg")

        // When
        let result = sut.useReferenceFace(referenceFace)

        // Then
        XCTAssertNotNil(sut.referenceFace, "Should set reference face")
        XCTAssertTrue(result === sut, "Should return self for chaining")
    }

    // MARK: - Similarity Threshold Tests

    func testSetSimilarityThresholdWithValidValue() {
        // Given
        let threshold: Float = 0.85

        // When
        let result = sut.setSimilarityThreshold(threshold)

        // Then
        XCTAssertEqual(sut.similarityThreshold, threshold, "Should set similarity threshold")
        XCTAssertTrue(result === sut, "Should return self for chaining")
    }

    func testSetSimilarityThresholdWithMinValue() {
        // Given
        let threshold: Float = 0.0

        // When
        let result = sut.setSimilarityThreshold(threshold)

        // Then
        XCTAssertEqual(sut.similarityThreshold, threshold, "Should accept 0.0 as threshold")
        XCTAssertTrue(result === sut, "Should return self for chaining")
    }

    func testSetSimilarityThresholdWithMaxValue() {
        // Given
        let threshold: Float = 1.0

        // When
        let result = sut.setSimilarityThreshold(threshold)

        // Then
        XCTAssertEqual(sut.similarityThreshold, threshold, "Should accept 1.0 as threshold")
        XCTAssertTrue(result === sut, "Should return self for chaining")
    }

    func testSetSimilarityThresholdWithInvalidLowValue() {
        // Given
        let threshold: Float = -0.1

        // When
        let result = sut.setSimilarityThreshold(threshold)

        // Then - Should clamp to 0.0
        XCTAssertEqual(sut.similarityThreshold, 0.0, "Should clamp negative threshold to 0.0")
        XCTAssertTrue(result === sut, "Should return self for chaining")
    }

    func testSetSimilarityThresholdWithInvalidHighValue() {
        // Given
        let threshold: Float = 1.1

        // When
        let result = sut.setSimilarityThreshold(threshold)

        // Then - Should clamp to 1.0
        XCTAssertEqual(sut.similarityThreshold, 1.0, "Should clamp high threshold to 1.0")
        XCTAssertTrue(result === sut, "Should return self for chaining")
    }

    // MARK: - Wait For Results Tests

    func testEnableWaitForResults() {
        // When
        let result = sut.enableWaitForResults(false)

        // Then
        XCTAssertFalse(sut.shouldWaitForResults, "Should disable wait for results")
        XCTAssertTrue(result === sut, "Should return self for chaining")
    }

    func testEnableWaitForResultsTrue() {
        // Given
        _ = sut.enableWaitForResults(false)

        // When
        let result = sut.enableWaitForResults(true)

        // Then
        XCTAssertTrue(sut.shouldWaitForResults, "Should enable wait for results")
        XCTAssertTrue(result === sut, "Should return self for chaining")
    }

    // MARK: - Autocapture Tests

    func testEnableAutocapture() {
        // When
        let result = sut.enableAutocapture(false)

        // Then
        XCTAssertFalse(sut.useAutocapture, "Should disable autocapture")
        XCTAssertTrue(result === sut, "Should return self for chaining")
    }

    func testEnableAutocaptureTrue() {
        // Given
        _ = sut.enableAutocapture(false)

        // When
        let result = sut.enableAutocapture(true)

        // Then
        XCTAssertTrue(sut.useAutocapture, "Should enable autocapture")
        XCTAssertTrue(result === sut, "Should return self for chaining")
    }

    // MARK: - Timeout Tests

    func testSetTimeout() {
        // Given
        let timeout = 120

        // When
        let result = sut.setTimeout(timeout)

        // Then
        XCTAssertEqual(sut.timeoutSeconds, timeout, "Should set timeout")
        XCTAssertTrue(result === sut, "Should return self for chaining")
    }

    func testSetTimeoutWithZero() {
        // Given
        let timeout = 0

        // When
        let result = sut.setTimeout(timeout)

        // Then
        XCTAssertEqual(sut.timeoutSeconds, timeout, "Should accept 0 as timeout")
        XCTAssertTrue(result === sut, "Should return self for chaining")
    }

    func testSetTimeoutWithNegativeValue() {
        // Given
        let timeout = -1

        // When
        let result = sut.setTimeout(timeout)

        // Then - Should clamp to 0
        XCTAssertEqual(sut.timeoutSeconds, 0, "Should clamp negative timeout to 0")
        XCTAssertTrue(result === sut, "Should return self for chaining")
    }

    // MARK: - Method Chaining Tests

    func testMethodChaining() throws {
        // Given
        let referenceFace = try ReferenceFace.from("https://example.com/face.jpg")

        // When
        let result =
            sut
                .useReferenceFace(referenceFace)
                .setSimilarityThreshold(0.9)
                .enableAutocapture(false)
                .enableWaitForResults(false)
                .setTimeout(90)

        // Then
        XCTAssertTrue(result === sut, "Should support method chaining")
        XCTAssertNotNil(sut.referenceFace, "Should have set reference face")
        XCTAssertEqual(sut.similarityThreshold, 0.9, "Should have set similarity threshold")
        XCTAssertFalse(sut.useAutocapture, "Should have disabled autocapture")
        XCTAssertFalse(sut.shouldWaitForResults, "Should have disabled wait for results")
        XCTAssertEqual(sut.timeoutSeconds, 90, "Should have set timeout")
    }
}
