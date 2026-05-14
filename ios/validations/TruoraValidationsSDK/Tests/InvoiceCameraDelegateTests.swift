//
//  InvoiceCameraDelegateTests.swift
//  TruoraValidationsSDKTests
//
//  Created by Truora on 22/04/26.
//

import UIKit
import XCTest
@testable import TruoraValidationsSDK

@MainActor final class InvoiceCameraDelegateTests: XCTestCase {
    private var sut: InvoiceCameraDelegate!
    private var mockPresenter: MockInvoiceCameraPresenter!

    override func setUp() {
        super.setUp()
        mockPresenter = MockInvoiceCameraPresenter()
        sut = InvoiceCameraDelegate(presenter: mockPresenter)
    }

    override func tearDown() {
        sut = nil
        mockPresenter = nil
        super.tearDown()
    }

    // MARK: - didFinishPickingMediaWithInfo

    func testDidFinishPicking_withValidImage_callsFileSelectedWithJpegData() async {
        // Given
        let image = Self.makeSolidImage(size: CGSize(width: 4, height: 4))
        let picker = SpyImagePicker()

        // When
        sut.imagePickerController(picker, didFinishPickingMediaWithInfo: [.originalImage: image])
        await mockPresenter.waitForFileSelected(count: 1)

        // Then
        XCTAssertEqual(mockPresenter.lastContentType, "image/jpeg")
        XCTAssertNotNil(mockPresenter.lastData)
        // Round-trip: the emitted data must decode back to a UIImage
        XCTAssertNotNil(UIImage(data: mockPresenter.lastData ?? Data()))
        XCTAssertTrue(picker.dismissCalled, "Picker should be dismissed before async callback")
    }

    func testDidFinishPicking_withValidImage_usesJPEGCompression() async {
        // Given — a multicolor image so PNG is bigger than JPEG (quality 0.85 shrinks it)
        let image = Self.makeGradientImage(size: CGSize(width: 64, height: 64))
        let picker = SpyImagePicker()

        // When
        sut.imagePickerController(picker, didFinishPickingMediaWithInfo: [.originalImage: image])
        await mockPresenter.waitForFileSelected(count: 1)

        // Then — emitted bytes are JPEG-decodable and smaller than the equivalent PNG
        guard let jpegBytes = mockPresenter.lastData else {
            XCTFail("Expected jpeg data")
            return
        }
        XCTAssertNotNil(UIImage(data: jpegBytes))
        if let pngBytes = image.pngData() {
            XCTAssertLessThan(jpegBytes.count, pngBytes.count, "JPEG compression should reduce size")
        }
    }

    func testDidFinishPicking_withoutOriginalImage_callsFileSelectionFailed() async {
        // Given — empty info dict
        let picker = SpyImagePicker()

        // When
        sut.imagePickerController(picker, didFinishPickingMediaWithInfo: [:])
        await mockPresenter.waitForFileSelectionFailed(count: 1)

        // Then
        XCTAssertEqual(mockPresenter.fileSelectionFailedCount, 1)
        XCTAssertTrue(
            mockPresenter.lastFailureMessage?.contains("captured photo") ?? false,
            "Expected camera failure message, got: \(mockPresenter.lastFailureMessage ?? "nil")"
        )
        XCTAssertEqual(mockPresenter.fileSelectedCount, 0)
    }

    func testDidFinishPicking_withNonImageInfo_callsFileSelectionFailed() async {
        // Given — `originalImage` holds a non-UIImage value
        let picker = SpyImagePicker()

        // When
        sut.imagePickerController(
            picker,
            didFinishPickingMediaWithInfo: [.originalImage: "not-an-image"]
        )
        await mockPresenter.waitForFileSelectionFailed(count: 1)

        // Then
        XCTAssertEqual(mockPresenter.fileSelectionFailedCount, 1)
        XCTAssertEqual(mockPresenter.fileSelectedCount, 0)
    }

    // MARK: - imagePickerControllerDidCancel

    func testDidCancel_callsPickerCancelled() async {
        // Given
        let picker = SpyImagePicker()

        // When
        sut.imagePickerControllerDidCancel(picker)
        await mockPresenter.waitForPickerCancelled(count: 1)

        // Then
        XCTAssertEqual(mockPresenter.pickerCancelledCount, 1)
        XCTAssertTrue(picker.dismissCalled)
    }

    // MARK: - Helpers

    private static func makeSolidImage(size: CGSize) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    /// Gradient image compresses much better as JPEG than PNG.
    private static func makeGradientImage(size: CGSize) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { context in
            let ctx = context.cgContext
            let colors = [UIColor.red.cgColor, UIColor.blue.cgColor] as CFArray
            let space = CGColorSpaceCreateDeviceRGB()
            if let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1]) {
                ctx.drawLinearGradient(
                    gradient,
                    start: .zero,
                    end: CGPoint(x: size.width, y: size.height),
                    options: []
                )
            }
        }
    }
}

// MARK: - Spy Picker

@MainActor private final class SpyImagePicker: UIImagePickerController {
    private(set) var dismissCalled = false

    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        dismissCalled = true
        completion?()
    }
}

// MARK: - Mock Presenter

@MainActor private final class MockInvoiceCameraPresenter: InvoiceInstructionsViewToPresenter {
    private(set) var fileSelectedCount = 0
    private(set) var pickerCancelledCount = 0
    private(set) var fileSelectionFailedCount = 0
    private(set) var lastData: Data?
    private(set) var lastContentType: String?
    private(set) var lastFailureMessage: String?

    func viewDidLoad() async {}
    func uploadFileTapped() async {}
    func takePhotoTapped() async {}
    func cancelTapped() async {}

    func fileSelected(data: Data, contentType: String) async {
        fileSelectedCount += 1
        lastData = data
        lastContentType = contentType
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
