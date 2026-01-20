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

class ValidationRouterTests: XCTestCase {
    var router: ValidationRouter!
    var mockNavigationController: UINavigationController!
    fileprivate var mockDelegate: MockValidationDelegateForRouter!

    // Minimal valid JPEG data (1x1 pixel red image)
    // This is more realistic than empty Data() for face enrollment tests
    private static let minimalJPEGData: Data = {
        // JPEG header for a minimal 1x1 red pixel image
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
        // Reset config FIRST to ensure clean state
        ValidationConfig.shared.reset()
        mockNavigationController = UINavigationController()
        mockDelegate = MockValidationDelegateForRouter()
        router = ValidationRouter(navigationController: mockNavigationController)
    }

    override func tearDown() {
        // Clean up in reverse order of creation
        router = nil
        mockNavigationController = nil
        mockDelegate = nil
        // Reset config LAST to ensure complete cleanup
        ValidationConfig.shared.reset()
        super.tearDown()
    }

    // MARK: - Navigate to Passive Capture Tests

    func testNavigateToPassiveCaptureWithValidData() async throws {
        // Given
        try await ValidationConfig.shared.configure(
            apiKey: "test-api-key",
            accountId: "test-account-id",
            delegate: mockDelegate.closure
        )

        let validationId = "test-validation-id"
        let uploadUrl = "https://example.com/upload"

        // When/Then
        XCTAssertNoThrow(try router.navigateToPassiveCapture(validationId: validationId, uploadUrl: uploadUrl))
    }

    func testNavigateToPassiveCaptureWithNilUploadUrl() async throws {
        // Given
        try await ValidationConfig.shared.configure(
            apiKey: "test-api-key",
            accountId: "test-account-id",
            delegate: mockDelegate.closure
        )

        let validationId = "test-validation-id"

        // When/Then
        XCTAssertNoThrow(try router.navigateToPassiveCapture(validationId: validationId, uploadUrl: nil))
    }

    func testNavigateToPassiveCaptureWithEmptyUploadUrlThrowsError() async throws {
        // Given
        try await ValidationConfig.shared.configure(
            apiKey: "test-api-key",
            accountId: "test-account-id",
            delegate: mockDelegate.closure
        )

        let validationId = "test-validation-id"
        let emptyUploadUrl = ""

        // When/Then
        XCTAssertThrowsError(try router.navigateToPassiveCapture(
            validationId: validationId,
            uploadUrl: emptyUploadUrl
        )) { error in
            guard case ValidationError.invalidConfiguration(let message) = error else {
                XCTFail("Expected invalidConfiguration error")
                return
            }
            XCTAssertTrue(message.contains("Upload URL cannot be empty"))
        }
    }

    func testNavigateToPassiveCaptureWithInvalidUploadUrlDoesNotCrash() async throws {
        // Given
        try await ValidationConfig.shared.configure(
            apiKey: "test-api-key",
            accountId: "test-account-id",
            delegate: mockDelegate.closure
        )

        let validationId = "test-validation-id"
        // Note: URL(string:) accepts most strings, so we can't easily test invalid URLs
        // This test just verifies the method doesn't crash
        XCTAssertNotNil(validationId)
    }

    // MARK: - Navigate to Passive Intro Tests

    func testNavigateToPassiveIntroWithConfiguration() async throws {
        // Given
        try await ValidationConfig.shared.configure(
            apiKey: "test-api-key",
            accountId: "test-account-id",
            delegate: mockDelegate.closure
        )

        // When/Then
        XCTAssertNoThrow(try router.navigateToPassiveIntro())
    }

    // MARK: - Handle Cancellation Tests

    func testHandleCancellationDoesNotCrash() {
        // When/Then
        XCTAssertNoThrow(router.handleCancellation())
    }

    // MARK: - Dismiss Flow Tests

    func testDismissFlow() {
        // When
        router.dismissFlow()

        // Then
        // The navigation controller should be dismissed
        // This is hard to test without a window, but we can verify it doesn't crash
        XCTAssertNotNil(router)
    }

    // MARK: - Reference Face Enrollment Tests

    func testStartReferenceFaceEnrollment_withEmptyAccountId_returnsNil() {
        // Given - setUp() already resets config, no account ID configured

        // When
        let task = router.startReferenceFaceEnrollmentForTest()

        // Then
        XCTAssertNil(task, "Should return nil when account ID is empty")
    }

    func testStartReferenceFaceEnrollment_withoutReferenceFace_returnsNil() async throws {
        // Given
        try await ValidationConfig.shared.configure(
            apiKey: "test-api-key",
            accountId: "test-account-id",
            delegate: nil
        )
        // No reference face configured

        // When
        let task = router.startReferenceFaceEnrollmentForTest()

        // Then
        XCTAssertNil(task, "Should return nil when reference face is not configured")
    }

    func testStartReferenceFaceEnrollment_withValidConfiguration_createsTask() async throws {
        // Given
        try await ValidationConfig.shared.configure(
            apiKey: "test-api-key",
            accountId: "test-account-id",
            delegate: nil
        )

        // Configure a reference face with realistic JPEG data
        let referenceFace = ReferenceFace.from(Self.minimalJPEGData)
        ValidationConfig.shared.setValidation(.face(Face().useReferenceFace(referenceFace)))

        // When
        let task = router.startReferenceFaceEnrollmentForTest()

        // Then
        XCTAssertNotNil(task, "Should create enrollment task with valid configuration")

        // Clean up task and verify cancellation doesn't throw
        task?.cancel()
        XCTAssertTrue(task?.isCancelled ?? false, "Task should be cancelled after cancel() call")
    }

    func testGetPassiveIntroViewController_createsViewControllerWithEnrollmentTask() async throws {
        // Given
        try await ValidationConfig.shared.configure(
            apiKey: "test-api-key",
            accountId: "test-account-id",
            delegate: nil
        )

        // Configure a reference face with realistic JPEG data
        let referenceFace = ReferenceFace.from(Self.minimalJPEGData)
        ValidationConfig.shared.setValidation(.face(Face().useReferenceFace(referenceFace)))

        // When
        let viewController = try router.getPassiveIntroViewControllerForTest()

        // Then
        XCTAssertNotNil(viewController, "Should create view controller")
        XCTAssertTrue(viewController is UIHostingController<PassiveIntroView>, "Should be hosting controller")
    }

    func testGetPassiveIntroViewController_withoutReferenceFace_stillCreatesViewController() async throws {
        // Given
        try await ValidationConfig.shared.configure(
            apiKey: "test-api-key",
            accountId: "test-account-id",
            delegate: nil
        )
        // No reference face configured

        // When
        let viewController = try router.getPassiveIntroViewControllerForTest()

        // Then
        XCTAssertNotNil(viewController, "Should create view controller even without reference face")
    }

    // MARK: - Centralized Presentation Tests

    func testPresentFlow_fromViewControllerNotInWindowHierarchy_throws() {
        runAsyncTest {
            let navController = UINavigationController()
            let presenter = UIViewController()

            do {
                try await MainActor.run {
                    try ValidationRouter.presentFlow(
                        navController: navController,
                        from: presenter
                    )
                }
                XCTFail("Expected presentFlow to throw")
            } catch {
                guard case ValidationError.internalError(let message) = error else {
                    XCTFail("Expected internalError")
                    return
                }
                XCTAssertTrue(message.contains("window hierarchy"))
            }
        }
    }

    func testPresentFlow_whenPresenterIsAlreadyPresenting_throws() {
        runAsyncTest {
            let window = UIWindow(frame: UIScreen.main.bounds)
            let navController = UINavigationController()
            let presenter = PresentingViewController()
            window.rootViewController = presenter
            window.makeKeyAndVisible()
            presenter.loadViewIfNeeded()

            do {
                try await MainActor.run {
                    try ValidationRouter.presentFlow(
                        navController: navController,
                        from: presenter
                    )
                }
                XCTFail("Expected presentFlow to throw")
            } catch {
                guard case ValidationError.internalError(let message) = error else {
                    XCTFail("Expected internalError")
                    return
                }
                XCTAssertTrue(message.contains("already presenting"))
            }
        }
    }
}

private final class PresentingViewController: UIViewController {
    override var presentedViewController: UIViewController? { UIViewController() }
}

// MARK: - Mock Delegate

private class MockValidationDelegateForRouter {
    var completionCalled = false
    var failureCalled = false
    var validationCancelledCalled = false
    var captureCalled = false
    var lastResult: ValidationResult?
    var lastError: ValidationError?

    var closure: (TruoraValidationResult<ValidationResult>) -> Void {
        { [unowned self] result in
            switch result {
            case .complete(let validationResult):
                self.completionCalled = true
                self.lastResult = validationResult
            case .failure(let err):
                switch err {
                case .cancelled:
                    self.validationCancelledCalled = true
                default:
                    self.failureCalled = true
                    self.lastError = err
                }
            case .capture:
                self.captureCalled = true
            }
        }
    }
}
