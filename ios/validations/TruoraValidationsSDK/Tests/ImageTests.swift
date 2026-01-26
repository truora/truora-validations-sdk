//
//  ImageTests.swift
//  SDKTests
//
//  Created by Brayan Escobar on 10/11/25.
//

import XCTest
@testable import TruoraValidationsSDK

final class ImageTests: XCTestCase {
    func testFromURL_shouldCreateImageWithURL() {
        let url = "https://example.com/image.jpg"

        let image = Image.fromURL(url)

        XCTAssertEqual(image.url, url)
        XCTAssertNil(image.filePath)
    }

    func testFromFile_shouldCreateImageWithFilePath() {
        let filePath = "/path/to/local/image.jpg"

        let image = Image.fromFile(filePath)

        XCTAssertEqual(image.filePath, filePath)
        XCTAssertNil(image.url)
    }
}
