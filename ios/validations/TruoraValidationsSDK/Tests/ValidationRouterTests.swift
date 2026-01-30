//
//  ValidationRouterTests.swift
//  TruoraValidationsSDKTests
//
//  Created by Truora on 11/11/25.
//

import SwiftUI
import UIKit
import XCTest
@testable import TruoraValidationsSDK

@MainActor class ValidationRouterTests: XCTestCase {
    var router: ValidationRouter!
    var mockNavigationController: UINavigationController!
    fileprivate var mockDelegate: MockValidationDelegateForRouter!

    /// Minimal valid JPEG data (1x1 pixel red image)
    private static let minimalJPEGData: Data = {
        let jpegBytes: [UInt8] = [
            0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
            0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43,
            0x00, 0x08, 0x06, 0x06, 0x07, 0x06, 0x05, 0x08, 0x07, 0x07, 0x07, 0x09,
            0x09, 0x08, 0x0A, 0x0C, 0x14, 0x0D, 0x0C, 0x0B, 0x0B, 0x0C, 0x19, 0x12,
            0x13, 0x0F, 0x14, 0x1D, 0x1A, 0x1F, 0x1E, 0x1D, 0x1A, 0x1C, 0x1C, 0x20,
            0x24, 0x2E, 0x27, 0x20, 0x22, 0x2C, 0x23, 0x1C, 0x1C, 0x28, 0x37, 0x29,
            0x2C, 0x30, 0x31, 0x34, 0x34, 0x34, 0x1F, 0x27, 0x39, 0x3D, 0x38, 0x32,
            0x3C, 0x2E, 0x33, 0x34, 0x32, 0xFF, 0xC0, 0x00, 0x0B, 0x08, 0x00, 0x01,
            0x00, 0x01, 0x01, 0x01, 0x11, 0x00, 0xFF, 0xC4, 0x00, 0x1F, 0x00, 0x00,
            0x01, 0x05, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
            0x09, 0x0A, 0x0B, 0xFF, 0xC4, 0x00, 0xB5, 0x10, 0x00, 0x02, 0x01, 0x03,
            0x03, 0x02, 0x04, 0x03, 0x05, 0x05, 0x04, 0x04, 0x00, 0x00, 0x01, 0x7D,
            0x01, 0x02, 0x03, 0x00, 0x04, 0x11, 0x05, 0x12, 0x21, 0x31, 0x41, 0x06,
            0x13, 0x51, 0x61, 0x07, 0x22, 0x71, 0x14, 0x32, 0x81, 0x91, 0xA1, 0x08,
            0x23, 0x42, 0xB1, 0xC1, 0x15, 0x52, 0xD1, 0xF0, 0x24, 0x33, 0x62, 0x72,
            0x82, 0x09, 0x0A, 0x16, 0x17, 0x18, 0x19, 0x1A, 0x25, 0x26, 0x27, 0x28,
            0x29, 0x2A, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3A, 0x43, 0x44, 0x45,
            0x46, 0x47, 0x48, 0x49, 0x4A, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59,
            0x5A, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6A, 0x73, 0x74, 0x75,
            0x76, 0x77, 0x78, 0x79, 0x7A, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89,
            0x8A, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9A, 0xA2, 0xA3,
            0xA4, 0xA5, 0xA6, 0xA7, 0xA8, 0xA9, 0xAA, 0xB2, 0xB3, 0xB4, 0xB5, 0xB6,
            0xB7, 0xB8, 0xB9, 0xBA, 0xC2, 0xC3, 0xC4, 0xC5, 0xC6, 0xC7, 0xC8, 0xC9,
            0xCA, 0xD2, 0xD3, 0xD4, 0xD5, 0xD6, 0xD7, 0xD8, 0xD9, 0xDA, 0xE1, 0xE2,
            0xE3, 0xE4, 0xE5, 0xE6, 0xE7, 0xE8, 0xE9, 0xEA, 0xF1, 0xF2, 0xF3, 0xF4,
            0xF5, 0xF6, 0xF7, 0xF8, 0xF9, 0xFA, 0xFF, 0xDA, 0x00, 0x08, 0x01, 0x01,
            0x00, 0x00, 0x3F, 0x00, 0xFB, 0xD5, 0xDB, 0x20, 0xA8, 0xF1, 0x4C, 0xA3,
            0x9A, 0x65, 0xFF, 0xD9
        ]
        return Data(jpegBytes)
    }()

    override func setUp() {
        super.setUp()
        ValidationConfig.shared.reset()
        mockNavigationController = UINavigationController()
        mockDelegate = MockValidationDelegateForRouter()
        router = ValidationRouter(navigationController: mockNavigationController)
    }

    override func tearDown() {
        router = nil
        mockNavigationController = nil
        mockDelegate = nil
        ValidationConfig.shared.reset()
        super.tearDown()
    }

    // MARK: - Navigate to Passive Capture Tests

    func testNavigateToPassiveCaptureWithValidData() async throws {
        try await ValidationConfig.shared.configure(
            apiKey: "test-api-key",
            accountId: "test-account-id",
            delegate: mockDelegate.closure
        )

        let validationId = "test-validation-id"
        let uploadUrl = "https://example.com/upload"

        XCTAssertNoThrow(try router.navigateToPassiveCapture(validationId: validationId, uploadUrl: uploadUrl))
    }

    func testNavigateToPassiveCaptureWithNilUploadUrl() async throws {
        try await ValidationConfig.shared.configure(
            apiKey: "test-api-key",
            accountId: "test-account-id",
            delegate: mockDelegate.closure
        )

        let validationId = "test-validation-id"

        XCTAssertNoThrow(try router.navigateToPassiveCapture(validationId: validationId, uploadUrl: nil))
    }

    func testNavigateToPassiveCaptureWithEmptyUploadUrlThrowsError() {
        let validationId = "test-validation-id"
        let emptyUrl = ""

        XCTAssertThrowsError(try router.navigateToPassiveCapture(validationId: validationId, uploadUrl: emptyUrl))
    }

    func testNavigateToPassiveCaptureWithInvalidUploadUrlThrowsError() {
        let validationId = "test-validation-id"
        let invalidUrl = "not-a-valid-url"

        XCTAssertThrowsError(try router.navigateToPassiveCapture(validationId: validationId, uploadUrl: invalidUrl))
    }

    // MARK: - Navigate to Result Tests

    func testNavigateToResultWithValidData() {
        let validationId = "test-validation-id"

        XCTAssertNoThrow(try router.navigateToResult(validationId: validationId, loadingType: .face))
    }

    func testNavigateToResultWithDocumentLoadingType() {
        let validationId = "test-validation-id"

        XCTAssertNoThrow(try router.navigateToResult(validationId: validationId, loadingType: .document))
    }

    // MARK: - Navigate to Passive Intro Tests

    func testNavigateToPassiveIntroWithConfiguration() async throws {
        try await ValidationConfig.shared.configure(
            apiKey: "test-api-key",
            accountId: "test-account-id",
            delegate: mockDelegate.closure
        )

        XCTAssertNoThrow(try router.navigateToPassiveIntro())
    }

    // MARK: - Navigate to Document Capture Tests

    func testNavigateToDocumentCaptureWithValidData() {
        let validationId = "test-validation-id"
        let frontUrl = "https://example.com/front"
        let reverseUrl = "https://example.com/reverse"

        XCTAssertNoThrow(try router.navigateToDocumentCapture(
            validationId: validationId,
            frontUploadUrl: frontUrl,
            reverseUploadUrl: reverseUrl
        ))
    }

    func testNavigateToDocumentCaptureWithSingleSidedDocument() {
        let validationId = "test-validation-id"
        let frontUrl = "https://example.com/front"

        XCTAssertNoThrow(try router.navigateToDocumentCapture(
            validationId: validationId,
            frontUploadUrl: frontUrl,
            reverseUploadUrl: nil
        ))
    }

    func testNavigateToDocumentCaptureWithInvalidFrontUrlThrowsError() {
        let validationId = "test-validation-id"
        let invalidUrl = "invalid-url"

        XCTAssertThrowsError(try router.navigateToDocumentCapture(
            validationId: validationId,
            frontUploadUrl: invalidUrl,
            reverseUploadUrl: nil
        ))
    }

    // MARK: - Navigate to Document Feedback Tests

    func testNavigateToDocumentFeedback() {
        let scenario = FeedbackScenario.documentNotFound
        let imageData = Self.minimalJPEGData
        let retriesLeft = 2

        XCTAssertNoThrow(try router.navigateToDocumentFeedback(
            feedback: scenario,
            capturedImageData: imageData,
            retriesLeft: retriesLeft
        ))
    }

    // MARK: - Enrollment Tests

    func testStartReferenceFaceEnrollmentWithValidConfig() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let fileUrl = tempDir.appendingPathComponent("test.jpg")
        try "test".data(using: .utf8)?.write(to: fileUrl)

        let referenceFace = try ReferenceFace.from(fileUrl)

        try await ValidationConfig.shared.configure(
            apiKey: "test-key",
            accountId: "test-account"
        )
        _ = ValidationConfig.shared.faceConfig.useReferenceFace(referenceFace)

        let task = router.startReferenceFaceEnrollmentForTest()
        XCTAssertNotNil(task)

        try? FileManager.default.removeItem(at: fileUrl)
    }

    func testStartReferenceFaceEnrollmentWithoutReferenceFaceReturnsNil() async throws {
        try await ValidationConfig.shared.configure(
            apiKey: "test-key",
            accountId: "test-account"
        )

        let task = router.startReferenceFaceEnrollmentForTest()
        XCTAssertNil(task)
    }

    func testStartReferenceFaceEnrollmentWithoutAccountIdReturnsNil() {
        let task = router.startReferenceFaceEnrollmentForTest()
        XCTAssertNil(task)
    }
}

// MARK: - Mock Delegate

@MainActor private class MockValidationDelegateForRouter {
    var closure: (TruoraValidationResult<ValidationResult>) -> Void {
        { _ in }
    }
}
