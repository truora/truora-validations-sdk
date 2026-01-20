//
//  TruoraValidationResult+MediaTypeTests.swift
//  TruoraValidationsSDKTests
//
//  Created by Truora on 21/11/25.
//

import XCTest
@testable import TruoraValidationsSDK

extension TruoraValidationResultTests {
    // MARK: - MediaType Tests

    func testMediaTypeRawValues() {
        // Then
        XCTAssertEqual(MediaType.photo.rawValue, "photo", "Photo should have correct raw value")
        XCTAssertEqual(MediaType.video.rawValue, "video", "Video should have correct raw value")
    }

    func testMediaTypeDecoding() throws {
        // Given
        let photoJSON = Data("\"photo\"".utf8)
        let videoJSON = Data("\"video\"".utf8)

        // When
        let photo = try JSONDecoder().decode(MediaType.self, from: photoJSON)
        let video = try JSONDecoder().decode(MediaType.self, from: videoJSON)

        // Then
        XCTAssertEqual(photo, .photo, "Should decode photo correctly")
        XCTAssertEqual(video, .video, "Should decode video correctly")
    }

    func testMediaTypeEncoding() throws {
        // Given
        let photo = MediaType.photo
        let video = MediaType.video

        // When
        let photoData = try JSONEncoder().encode(photo)
        let videoData = try JSONEncoder().encode(video)

        guard let photoString = String(data: photoData, encoding: .utf8) else {
            XCTFail("Failed to convert photoData to String")
            return
        }
        guard let videoString = String(data: videoData, encoding: .utf8) else {
            XCTFail("Failed to convert videoData to String")
            return
        }

        // Then
        XCTAssertEqual(photoString, "\"photo\"", "Should encode photo correctly")
        XCTAssertEqual(videoString, "\"video\"", "Should encode video correctly")
    }
}
