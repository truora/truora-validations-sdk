//
//  InvoicePreviewGeneratorTests.swift
//  TruoraValidationsSDKTests
//
//  Created by Truora on 22/04/26.
//

import PDFKit
import UIKit
import XCTest
@testable import TruoraValidationsSDK

@MainActor final class InvoicePreviewGeneratorTests: XCTestCase {
    // MARK: - Image content types

    func testImageContentType_returnsRawDataUnchanged() {
        // Given
        let raw = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10])

        // When
        let result = InvoicePreviewGenerator.previewImageData(from: raw, contentType: "image/jpeg")

        // Then
        XCTAssertEqual(result, raw)
    }

    func testPNGContentType_returnsRawDataUnchanged() {
        // Given
        let raw = Data([0x89, 0x50, 0x4E, 0x47])

        // When
        let result = InvoicePreviewGenerator.previewImageData(from: raw, contentType: "image/png")

        // Then
        XCTAssertEqual(result, raw)
    }

    // MARK: - PDF rasterization

    func testPDFContentType_rendersFirstPage() {
        // Given
        let pdf = Self.makeTestPDF(pageCount: 1)

        // When
        let result = InvoicePreviewGenerator.previewImageData(from: pdf, contentType: "application/pdf")

        // Then
        XCTAssertNotNil(result, "PDF should rasterize to non-nil PNG data")
        XCTAssertNotNil(UIImage(data: result ?? Data()), "Result must be decodable as UIImage")
    }

    func testPDFContentType_multiPagePDF_rendersOnlyFirstPage() {
        // Given a 3-page PDF where every page has the same size
        let pdf = Self.makeTestPDF(pageCount: 3)

        // When
        let result = InvoicePreviewGenerator.previewImageData(from: pdf, contentType: "application/pdf")

        // Then — since each page shares dimensions, the thumbnail must match page 1's bounds
        guard let data = result, let image = UIImage(data: data) else {
            XCTFail("Expected rasterized PDF data")
            return
        }
        let document = PDFDocument(data: pdf)
        let firstPageBounds = document?.page(at: 0)?.bounds(for: .mediaBox) ?? .zero
        // Generator uses 2x scale internally
        XCTAssertEqual(image.size.width, firstPageBounds.width * 2, accuracy: 1)
        XCTAssertEqual(image.size.height, firstPageBounds.height * 2, accuracy: 1)
    }

    func testPDFContentType_corruptData_returnsNil() {
        // Given
        let garbage = Data([0x00, 0x01, 0x02, 0x03, 0x04])

        // When
        let result = InvoicePreviewGenerator.previewImageData(from: garbage, contentType: "application/pdf")

        // Then
        XCTAssertNil(result)
    }

    func testPDFContentType_emptyData_returnsNil() {
        // When
        let result = InvoicePreviewGenerator.previewImageData(from: Data(), contentType: "application/pdf")

        // Then
        XCTAssertNil(result)
    }

    func testPDFContentType_caseInsensitive() {
        // Given
        let pdf = Self.makeTestPDF(pageCount: 1)

        // When — uppercase content type should still rasterize
        let result = InvoicePreviewGenerator.previewImageData(from: pdf, contentType: "APPLICATION/PDF")

        // Then
        XCTAssertNotNil(result)
        XCTAssertNotNil(UIImage(data: result ?? Data()))
    }

    // MARK: - Helpers

    /// Generates an in-memory PDF with the given number of blank 200×300 pt pages.
    static func makeTestPDF(pageCount: Int) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 200, height: 300)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return renderer.pdfData { context in
            for _ in 0 ..< pageCount {
                context.beginPage()
                UIColor.white.setFill()
                UIRectFill(pageRect)
            }
        }
    }
}
