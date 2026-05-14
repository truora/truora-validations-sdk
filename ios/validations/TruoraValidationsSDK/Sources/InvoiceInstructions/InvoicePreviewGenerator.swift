//
//  InvoicePreviewGenerator.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 21/04/26.
//

import Foundation
import PDFKit
import UIKit

/// Builds the preview Data that the invoice feedback screen renders with
/// `UIImage(data:)`. For image content the raw bytes are returned as-is;
/// PDFs are rasterized to a PNG of the first page so the feedback preview
/// path (which only understands image data) can display them.
enum InvoicePreviewGenerator {
    private static let pdfContentType = "application/pdf"
    private static let pdfRenderScale: CGFloat = 2.0

    static func previewImageData(from data: Data, contentType: String) -> Data? {
        if contentType.lowercased() == pdfContentType {
            return renderPDFFirstPage(data: data)
        }
        // For JPG/PNG/GIF the caller can hand `data` straight to UIImage(data:).
        return data
    }

    private static func renderPDFFirstPage(data: Data) -> Data? {
        guard let document = PDFDocument(data: data) else {
            debugLog("⚠️ InvoicePreviewGenerator: PDFDocument(data:) returned nil (byteCount=\(data.count))")
            return nil
        }
        guard let page = document.page(at: 0) else {
            debugLog("⚠️ InvoicePreviewGenerator: PDF has no page at index 0 (pageCount=\(document.pageCount))")
            return nil
        }
        let pageBounds = page.bounds(for: .mediaBox)
        let size = CGSize(
            width: pageBounds.width * pdfRenderScale,
            height: pageBounds.height * pdfRenderScale
        )
        let thumbnail = page.thumbnail(of: size, for: .mediaBox)
        guard let png = thumbnail.pngData() else {
            debugLog("⚠️ InvoicePreviewGenerator: UIImage.pngData() returned nil for rendered first page")
            return nil
        }
        return png
    }
}
