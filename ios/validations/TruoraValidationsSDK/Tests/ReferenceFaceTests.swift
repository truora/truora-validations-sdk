//
//  ReferenceFaceTests.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 17/11/25.
//

import XCTest

@testable import TruoraValidationsSDK

final class ReferenceFaceTests: XCTestCase {
    // MARK: - URL Tests

    func testFromWithURL() {
        // Given
        let url = URL(string: "https://example.com/face.jpg")!

        // When
        let referenceFace = ReferenceFace.from(url)

        // Then
        XCTAssertNotNil(referenceFace, "Should create ReferenceFace from URL")
    }

    func testFromWithHTTPSURLString() throws {
        // Given
        let urlString = "https://example.com/face.jpg"

        // When
        let referenceFace = try ReferenceFace.from(urlString)

        // Then
        XCTAssertNotNil(referenceFace, "Should create ReferenceFace from HTTPS URL string")
    }

    func testFromWithHTTPURLString() throws {
        // Given
        let urlString = "http://example.com/face.jpg"

        // When
        let referenceFace = try ReferenceFace.from(urlString)

        // Then
        XCTAssertNotNil(referenceFace, "Should create ReferenceFace from HTTP URL string")
    }

    func testFromWithFileURLString() throws {
        // Given
        let urlString = "file:///path/to/face.jpg"

        // When
        let referenceFace = try ReferenceFace.from(urlString)

        // Then
        XCTAssertNotNil(referenceFace, "Should create ReferenceFace from file URL string")
    }

    // MARK: - File Path Tests

    func testFromWithFilePath() throws {
        // Given
        let filePath = "/path/to/local/face.jpg"

        // When
        let referenceFace = try ReferenceFace.from(filePath)

        // Then
        XCTAssertNotNil(referenceFace, "Should create ReferenceFace from file path")
    }

    // MARK: - Data Tests

    func testFromWithData() {
        // Given
        let data = Data([0x00, 0x01, 0x02, 0x03])

        // When
        let referenceFace = ReferenceFace.from(data)

        // Then
        XCTAssertNotNil(referenceFace, "Should create ReferenceFace from Data")
    }

    func testFromWithEmptyData() {
        // Given
        let emptyData = Data()

        // When
        let referenceFace = ReferenceFace.from(emptyData)

        // Then
        XCTAssertNotNil(referenceFace, "Should create ReferenceFace from empty Data")
    }

    // MARK: - InputStream Tests

    func testFromWithInputStream() throws {
        // Given
        let data = Data([0x00, 0x01, 0x02, 0x03])
        let stream = InputStream(data: data)

        // When
        let referenceFace = try ReferenceFace.from(stream)

        // Then
        XCTAssertNotNil(referenceFace, "Should create ReferenceFace from InputStream")
    }

    func testFromWithEmptyInputStream() throws {
        // Given
        let emptyData = Data()
        let stream = InputStream(data: emptyData)

        // When
        let referenceFace = try ReferenceFace.from(stream)

        // Then
        XCTAssertNotNil(referenceFace, "Should create ReferenceFace from empty InputStream")
    }

    // MARK: - Validation Tests

    func testFromWithEmptyStringThrows() {
        // Given
        let emptyString = ""

        // When/Then
        XCTAssertThrowsError(try ReferenceFace.from(emptyString)) { error in
            guard let refError = error as? ReferenceFaceError else {
                XCTFail("Expected ReferenceFaceError")
                return
            }

            if case .invalidArgument(let message) = refError {
                XCTAssertTrue(message.contains("empty"), "Error should mention empty string")
            } else {
                XCTFail("Expected invalidArgument error")
            }
        }
    }

    func testFromWithWhitespaceStringThrows() {
        // Given
        let whitespaceString = "   "

        // When/Then
        XCTAssertThrowsError(try ReferenceFace.from(whitespaceString)) { error in
            guard let refError = error as? ReferenceFaceError else {
                XCTFail("Expected ReferenceFaceError")
                return
            }

            if case .invalidArgument = refError {
                // Success
            } else {
                XCTFail("Expected invalidArgument error")
            }
        }
    }

    func testFromWithInvalidURLString() {
        // Given - A string that looks like a malformed URL
        let invalidURL = "htp://invalid url with spaces"

        // When - This should NOT throw, it should treat it as a file path
        let referenceFace = try? ReferenceFace.from(invalidURL)

        // Then
        XCTAssertNotNil(referenceFace, "Should create ReferenceFace treating malformed URL as file path")
        XCTAssertTrue(referenceFace!.url.isFileURL, "Should treat malformed URL as file path")
    }

    // MARK: - URL Property Tests

    func testURLPropertyWithRemoteURL() throws {
        // Given
        let urlString = "https://example.com/face.jpg"

        // When
        let referenceFace = try ReferenceFace.from(urlString)

        // Then
        XCTAssertEqual(referenceFace.url.absoluteString, urlString, "Should store remote URL")
        XCTAssertFalse(referenceFace.url.isFileURL, "Remote URL should not be file URL")
    }

    func testURLPropertyWithLocalFile() throws {
        // Given
        let filePath = "/path/to/local/face.jpg"

        // When
        let referenceFace = try ReferenceFace.from(filePath)

        // Then
        XCTAssertTrue(referenceFace.url.isFileURL, "Should be file URL")
        XCTAssertTrue(referenceFace.url.path.contains(filePath), "Should contain file path")
    }

    func testURLPropertyWithData() {
        // Given
        let data = Data([0x00, 0x01, 0x02, 0x03])

        // When
        let referenceFace = ReferenceFace.from(data)

        // Then
        XCTAssertTrue(referenceFace.url.isFileURL, "Data should be stored as temp file URL")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: referenceFace.url.path),
            "Temp file should exist"
        )
    }

    func testURLPropertyWithInputStream() throws {
        // Given
        let data = Data([0x00, 0x01, 0x02, 0x03])
        let stream = InputStream(data: data)

        // When
        let referenceFace = try ReferenceFace.from(stream)

        // Then
        XCTAssertTrue(referenceFace.url.isFileURL, "Stream should be stored as temp file URL")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: referenceFace.url.path),
            "Temp file should exist"
        )
    }

    // MARK: - Temporary File Cleanup Tests

    func testTemporaryFileCleanupOnDealloc() {
        // Given
        var tempURL: URL?

        autoreleasepool {
            let data = Data([0x00, 0x01, 0x02, 0x03])
            let referenceFace = ReferenceFace.from(data)
            tempURL = referenceFace.url

            XCTAssertTrue(
                FileManager.default.fileExists(atPath: tempURL!.path),
                "Temp file should exist while ReferenceFace is alive"
            )
        }

        // Then - After autoreleasepool, ReferenceFace should be deallocated
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: tempURL!.path),
            "Temp file should be cleaned up after ReferenceFace is deallocated"
        )
    }

    func testNoCleanupForNonTemporaryFiles() throws {
        // Given
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test_face_permanent.jpg")
        let testData = Data([0x00, 0x01, 0x02, 0x03])
        try testData.write(to: testFile)

        defer {
            try? FileManager.default.removeItem(at: testFile)
        }

        try autoreleasepool {
            let referenceFace = try ReferenceFace.from(testFile.path)
            XCTAssertEqual(referenceFace.url.path, testFile.path, "Should reference the file")
        }

        // Then - File should still exist (not cleaned up)
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: testFile.path),
            "Non-temporary file should NOT be cleaned up"
        )
    }
}

// MARK: - ReferenceFaceError Tests

extension ReferenceFaceTests {
    func testReferenceFaceErrorDescription() {
        // Given
        let invalidArgumentError = ReferenceFaceError.invalidArgument("Test message")
        let conversionFailedError = ReferenceFaceError.conversionFailed("Conversion message")

        // Then
        XCTAssertEqual(
            invalidArgumentError.errorDescription,
            "Invalid argument: Test message",
            "Should provide correct error description"
        )
        XCTAssertEqual(
            conversionFailedError.errorDescription,
            "Conversion failed: Conversion message",
            "Should provide correct error description"
        )
    }
}
