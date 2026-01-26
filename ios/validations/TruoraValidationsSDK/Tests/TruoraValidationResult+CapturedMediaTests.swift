//
//  TruoraValidationResult+CapturedMediaTests.swift
//  TruoraValidationsSDKTests
//
//  Created by Truora on 21/11/25.
//

import XCTest
@testable import TruoraValidationsSDK

extension TruoraValidationResultTests {
    // MARK: - CapturedMedia Tests

    func testCapturedMediaInitialization() {
        // Given
        let timestamp = Date()

        // When
        let media = CapturedMedia(
            type: .photo,
            timestamp: timestamp
        )

        // Then
        XCTAssertEqual(media.type, .photo, "Should have correct type")
        XCTAssertNil(media.image, "Should have no image by default")
        XCTAssertNil(media.videoData, "Should have no video data by default")
        XCTAssertNil(media.videoURL, "Should have no video URL by default")
        XCTAssertNil(media.metadata, "Should have no metadata by default")
        XCTAssertEqual(media.timestamp, timestamp, "Should have correct timestamp")
    }

    func testCapturedMediaWithAllProperties() {
        // Given
        let timestamp = Date()
        let metadata = CaptureMetadata(
            duration: 5.0,
            resolution: CGSize(width: 1920, height: 1080),
            fileSize: 1024,
            additionalInfo: ["key": "value"]
        )

        // When
        let media = CapturedMedia(
            type: .video,
            videoData: Data([0x00, 0x01]),
            videoURL: URL(string: "file:///video.mp4"),
            metadata: metadata,
            timestamp: timestamp
        )

        // Then
        XCTAssertEqual(media.type, .video, "Should have video type")
        XCTAssertNotNil(media.videoData, "Should have video data")
        XCTAssertNotNil(media.videoURL, "Should have video URL")
        XCTAssertNotNil(media.metadata, "Should have metadata")
        XCTAssertEqual(media.timestamp, timestamp, "Should have timestamp")
    }

    func testCapturedMediaEquality() {
        // Given
        let timestamp = Date()
        let url = URL(string: "file:///video.mp4")
        let metadata = CaptureMetadata(duration: 5.0)

        let media1 = CapturedMedia(
            type: .video,
            videoURL: url,
            metadata: metadata,
            timestamp: timestamp
        )
        let media2 = CapturedMedia(
            type: .video,
            videoURL: url,
            metadata: metadata,
            timestamp: timestamp
        )

        // Then
        XCTAssertEqual(media1, media2, "Should be equal with same properties")
    }

    func testCapturedMediaInequality() {
        // Given
        let timestamp = Date()
        let media1 = CapturedMedia(type: .photo, timestamp: timestamp)
        let media2 = CapturedMedia(type: .video, timestamp: timestamp)

        // Then
        XCTAssertNotEqual(media1, media2, "Should not be equal with different types")
    }
}
