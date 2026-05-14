//
//  InvoiceFilePickerDelegateTests.swift
//  TruoraValidationsSDKTests
//
//  Created by Truora on 22/04/26.
//

import MobileCoreServices
import UIKit
import XCTest
@testable import TruoraValidationsSDK

@MainActor final class InvoiceFilePickerDelegateTests: XCTestCase {
    private var sut: InvoiceFilePickerDelegate!
    private var mockPresenter: MockInvoiceViewToPresenter!
    private var tempFiles: [URL] = []

    override func setUp() {
        super.setUp()
        mockPresenter = MockInvoiceViewToPresenter()
        sut = InvoiceFilePickerDelegate(presenter: mockPresenter)
    }

    override func tearDown() {
        sut = nil
        mockPresenter = nil
        for url in tempFiles {
            try? FileManager.default.removeItem(at: url)
        }
        tempFiles.removeAll()
        super.tearDown()
    }

    // MARK: - didPick

    func testDidPick_withEmptyURLs_callsPickerCancelled() async {
        // When
        sut.documentPicker(Self.makePicker(), didPickDocumentsAt: [])
        await mockPresenter.waitForPickerCancelled(count: 1)

        // Then
        XCTAssertEqual(mockPresenter.pickerCancelledCount, 1)
        XCTAssertEqual(mockPresenter.fileSelectedCount, 0)
    }

    func testDidPick_validSmallFile_callsFileSelectedWithData() async throws {
        // Given
        let payload = Data([0xFF, 0xD8, 0xAB, 0xCD])
        let url = try makeTempFile(extension: "jpg", data: payload)

        // When
        sut.documentPicker(Self.makePicker(), didPickDocumentsAt: [url])
        await mockPresenter.waitForFileSelected(count: 1)

        // Then
        XCTAssertEqual(mockPresenter.lastFileSelectedData, payload)
        XCTAssertEqual(mockPresenter.lastFileSelectedContentType, "image/jpeg")
    }

    func testDidPick_oversizedDocument_callsFileSelectionFailedWith100MBLimitMessage() async throws {
        // Given — >100 MB PDF. Sparse file via `truncate` avoids writing real bytes.
        let url = try makeSparseFile(extension: "pdf", sizeBytes: 101 * 1024 * 1024)

        // When
        sut.documentPicker(Self.makePicker(), didPickDocumentsAt: [url])
        await mockPresenter.waitForFileSelectionFailed(count: 1)

        // Then
        XCTAssertEqual(mockPresenter.fileSelectionFailedCount, 1)
        XCTAssertTrue(
            mockPresenter.lastFailureMessage?.contains("100 MB") ?? false,
            "Expected 100 MB limit message, got: \(mockPresenter.lastFailureMessage ?? "nil")"
        )
        XCTAssertEqual(mockPresenter.fileSelectedCount, 0)
    }

    func testDidPick_oversizedImage_callsFileSelectionFailedWith20MBLimitMessage() async throws {
        // Given — >20 MB JPG. Sparse file avoids allocating the real bytes.
        let url = try makeSparseFile(extension: "jpg", sizeBytes: 21 * 1024 * 1024)

        // When
        sut.documentPicker(Self.makePicker(), didPickDocumentsAt: [url])
        await mockPresenter.waitForFileSelectionFailed(count: 1)

        // Then
        XCTAssertEqual(mockPresenter.fileSelectionFailedCount, 1)
        XCTAssertTrue(
            mockPresenter.lastFailureMessage?.contains("20 MB") ?? false,
            "Expected 20 MB limit message, got: \(mockPresenter.lastFailureMessage ?? "nil")"
        )
        XCTAssertEqual(mockPresenter.fileSelectedCount, 0)
    }

    func testDidPick_largeDocumentBelowDocLimit_isAccepted() async throws {
        // Given — 50 MB PDF: above the 20 MB image cap but under the 100 MB document
        // cap. Confirms per-type limits are applied (image rule doesn't leak into docs).
        let url = try makeSparseFile(extension: "pdf", sizeBytes: 50 * 1024 * 1024)

        // When
        sut.documentPicker(Self.makePicker(), didPickDocumentsAt: [url])
        await mockPresenter.waitForFileSelected(count: 1)

        // Then
        XCTAssertEqual(mockPresenter.fileSelectedCount, 1)
        XCTAssertEqual(mockPresenter.lastFileSelectedContentType, "application/pdf")
        XCTAssertEqual(mockPresenter.fileSelectionFailedCount, 0)
    }

    func testDidPick_unreadableFile_callsFileSelectionFailedWithGenericMessage() async {
        // Given — URL pointing at a non-existent file
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-\(UUID().uuidString).pdf")

        // When
        sut.documentPicker(Self.makePicker(), didPickDocumentsAt: [missing])
        await mockPresenter.waitForFileSelectionFailed(count: 1)

        // Then
        XCTAssertEqual(mockPresenter.fileSelectionFailedCount, 1)
        XCTAssertTrue(
            mockPresenter.lastFailureMessage?.contains("Could not read") ?? false,
            "Expected read failure message, got: \(mockPresenter.lastFailureMessage ?? "nil")"
        )
    }

    func testDidPick_pdfFile_propagatesPDFContentType() async throws {
        let url = try makeTempFile(extension: "pdf", data: Data([0x25, 0x50, 0x44, 0x46]))

        sut.documentPicker(Self.makePicker(), didPickDocumentsAt: [url])
        await mockPresenter.waitForFileSelected(count: 1)

        XCTAssertEqual(mockPresenter.lastFileSelectedContentType, "application/pdf")
    }

    func testDidPick_jpgFile_propagatesJPEGContentType() async throws {
        let url = try makeTempFile(extension: "jpg", data: Data([0xFF, 0xD8]))

        sut.documentPicker(Self.makePicker(), didPickDocumentsAt: [url])
        await mockPresenter.waitForFileSelected(count: 1)

        XCTAssertEqual(mockPresenter.lastFileSelectedContentType, "image/jpeg")
    }

    func testDidPick_multipleURLs_usesFirstOnly() async throws {
        let first = try makeTempFile(extension: "png", data: Data([0x89]))
        let second = try makeTempFile(extension: "pdf", data: Data([0x25, 0x50, 0x44, 0x46]))

        sut.documentPicker(Self.makePicker(), didPickDocumentsAt: [first, second])
        await mockPresenter.waitForFileSelected(count: 1)

        XCTAssertEqual(mockPresenter.lastFileSelectedContentType, "image/png")
        XCTAssertEqual(mockPresenter.fileSelectedCount, 1, "Only first URL should be processed")
    }

    // MARK: - documentPickerWasCancelled

    func testWasCancelled_callsPickerCancelled() async {
        sut.documentPickerWasCancelled(Self.makePicker())
        await mockPresenter.waitForPickerCancelled(count: 1)

        XCTAssertEqual(mockPresenter.pickerCancelledCount, 1)
    }

    // MARK: - contentType(for:) — pure function

    func testContentType_pdf_returnsApplicationPdf() {
        XCTAssertEqual(
            InvoiceFilePickerDelegate.contentType(for: URL(fileURLWithPath: "/tmp/x.pdf")),
            "application/pdf"
        )
    }

    func testContentType_jpg_returnsImageJpeg() {
        XCTAssertEqual(
            InvoiceFilePickerDelegate.contentType(for: URL(fileURLWithPath: "/tmp/x.jpg")),
            "image/jpeg"
        )
    }

    func testContentType_jpeg_returnsImageJpeg() {
        XCTAssertEqual(
            InvoiceFilePickerDelegate.contentType(for: URL(fileURLWithPath: "/tmp/x.jpeg")),
            "image/jpeg"
        )
    }

    func testContentType_png_returnsImagePng() {
        XCTAssertEqual(
            InvoiceFilePickerDelegate.contentType(for: URL(fileURLWithPath: "/tmp/x.png")),
            "image/png"
        )
    }

    func testContentType_gif_returnsImageGif() {
        XCTAssertEqual(
            InvoiceFilePickerDelegate.contentType(for: URL(fileURLWithPath: "/tmp/x.gif")),
            "image/gif"
        )
    }

    func testContentType_csv_returnsTextCsv() {
        XCTAssertEqual(
            InvoiceFilePickerDelegate.contentType(for: URL(fileURLWithPath: "/tmp/x.csv")),
            "text/csv"
        )
    }

    func testContentType_txt_returnsTextPlain() {
        XCTAssertEqual(
            InvoiceFilePickerDelegate.contentType(for: URL(fileURLWithPath: "/tmp/x.txt")),
            "text/plain"
        )
    }

    func testContentType_doc_returnsApplicationMsword() {
        XCTAssertEqual(
            InvoiceFilePickerDelegate.contentType(for: URL(fileURLWithPath: "/tmp/x.doc")),
            "application/msword"
        )
    }

    func testContentType_docx_returnsOpenXmlDoc() {
        XCTAssertEqual(
            InvoiceFilePickerDelegate.contentType(for: URL(fileURLWithPath: "/tmp/x.docx")),
            "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        )
    }

    func testContentType_xls_returnsApplicationMsexcel() {
        XCTAssertEqual(
            InvoiceFilePickerDelegate.contentType(for: URL(fileURLWithPath: "/tmp/x.xls")),
            "application/vnd.ms-excel"
        )
    }

    func testContentType_xlsx_returnsOpenXmlSheet() {
        XCTAssertEqual(
            InvoiceFilePickerDelegate.contentType(for: URL(fileURLWithPath: "/tmp/x.xlsx")),
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        )
    }

    func testContentType_unknownExt_returnsOctetStream() {
        XCTAssertEqual(
            InvoiceFilePickerDelegate.contentType(for: URL(fileURLWithPath: "/tmp/x.foo")),
            "application/octet-stream"
        )
    }

    func testContentType_uppercaseExt_isCaseInsensitive() {
        XCTAssertEqual(
            InvoiceFilePickerDelegate.contentType(for: URL(fileURLWithPath: "/tmp/x.PDF")),
            "application/pdf"
        )
        XCTAssertEqual(
            InvoiceFilePickerDelegate.contentType(for: URL(fileURLWithPath: "/tmp/x.JPG")),
            "image/jpeg"
        )
    }

    // MARK: - Supported document types

    func testSupportedDocumentTypes_containsPDF_andImage() {
        let types = InvoiceFilePickerDelegate.supportedDocumentTypes
        XCTAssertTrue(types.contains(kUTTypePDF as String))
        XCTAssertTrue(types.contains(kUTTypeImage as String))
    }

    // MARK: - Helpers

    private static func makePicker() -> UIDocumentPickerViewController {
        UIDocumentPickerViewController(
            documentTypes: InvoiceFilePickerDelegate.supportedDocumentTypes,
            in: .import
        )
    }

    private func makeTempFile(extension ext: String, data: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).\(ext)")
        try data.write(to: url)
        tempFiles.append(url)
        return url
    }

    /// Creates a zero-filled sparse file of the requested size without writing real bytes.
    private func makeSparseFile(extension ext: String, sizeBytes: Int) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).\(ext)")
        FileManager.default.createFile(atPath: url.path, contents: nil)
        let handle = try FileHandle(forWritingTo: url)
        try handle.truncate(atOffset: UInt64(sizeBytes))
        try handle.close()
        tempFiles.append(url)
        return url
    }
}

// MARK: - Mock Presenter

@MainActor private final class MockInvoiceViewToPresenter: InvoiceInstructionsViewToPresenter {
    private(set) var viewDidLoadCount = 0
    private(set) var uploadFileTappedCount = 0
    private(set) var takePhotoTappedCount = 0
    private(set) var cancelTappedCount = 0
    private(set) var fileSelectedCount = 0
    private(set) var pickerCancelledCount = 0
    private(set) var fileSelectionFailedCount = 0

    private(set) var lastFileSelectedData: Data?
    private(set) var lastFileSelectedContentType: String?
    private(set) var lastFailureMessage: String?

    func viewDidLoad() async {
        viewDidLoadCount += 1
    }

    func uploadFileTapped() async {
        uploadFileTappedCount += 1
    }

    func takePhotoTapped() async {
        takePhotoTappedCount += 1
    }

    func cancelTapped() async {
        cancelTappedCount += 1
    }

    func fileSelected(data: Data, contentType: String) async {
        fileSelectedCount += 1
        lastFileSelectedData = data
        lastFileSelectedContentType = contentType
    }

    func pickerCancelled() async {
        pickerCancelledCount += 1
    }

    func fileSelectionFailed(message: String) async {
        fileSelectionFailedCount += 1
        lastFailureMessage = message
    }

    // MARK: - Async wait helpers

    func waitForFileSelected(count: Int, timeout: TimeInterval = 1.0) async {
        await waitUntil(timeout: timeout) { [weak self] in (self?.fileSelectedCount ?? 0) >= count }
    }

    func waitForPickerCancelled(count: Int, timeout: TimeInterval = 1.0) async {
        await waitUntil(timeout: timeout) { [weak self] in (self?.pickerCancelledCount ?? 0) >= count }
    }

    func waitForFileSelectionFailed(count: Int, timeout: TimeInterval = 1.0) async {
        await waitUntil(timeout: timeout) { [weak self] in (self?.fileSelectionFailedCount ?? 0) >= count }
    }

    private func waitUntil(timeout: TimeInterval, condition: @escaping () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
    }
}
