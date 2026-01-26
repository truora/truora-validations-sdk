//
//  TruoraValidationResult+CaptureMetadataTests.swift
//  TruoraValidationsSDKTests
//
//  Created by Truora on 21/11/25.
//

import XCTest
@testable import TruoraValidationsSDK

extension TruoraValidationResultTests {
    // MARK: - CaptureMetadata Tests

    func testCaptureMetadataInitialization() {
        // When
        let metadata = CaptureMetadata()

        // Then
        XCTAssertNil(metadata.duration, "Should have no duration by default")
        XCTAssertNil(metadata.resolution, "Should have no resolution by default")
        XCTAssertNil(metadata.fileSize, "Should have no file size by default")
        XCTAssertNil(metadata.additionalInfo, "Should have no additional info by default")
    }

    func testCaptureMetadataWithAllProperties() {
        // Given
        let duration: TimeInterval = 10.5
        let resolution = CGSize(width: 1920, height: 1080)
        let fileSize = 2048
        let additionalInfo = ["format": "mp4", "codec": "h264"]

        // When
        let metadata = CaptureMetadata(
            duration: duration,
            resolution: resolution,
            fileSize: fileSize,
            additionalInfo: additionalInfo
        )

        // Then
        XCTAssertEqual(metadata.duration, duration, "Should have correct duration")
        XCTAssertEqual(metadata.resolution, resolution, "Should have correct resolution")
        XCTAssertEqual(metadata.fileSize, fileSize, "Should have correct file size")
        XCTAssertEqual(metadata.additionalInfo, additionalInfo, "Should have correct additional info")
    }

    func testCaptureMetadataEquality() {
        // Given
        let metadata1 = CaptureMetadata(
            duration: 5.0,
            resolution: CGSize(width: 1920, height: 1080),
            fileSize: 1024
        )
        let metadata2 = CaptureMetadata(
            duration: 5.0,
            resolution: CGSize(width: 1920, height: 1080),
            fileSize: 1024
        )

        // Then
        XCTAssertEqual(metadata1, metadata2, "Should be equal with same properties")
    }
}
