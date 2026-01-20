//
//  UploadBaseImageInteractorTests.swift
//  TruoraValidationsSDKTests
//
//  Created by Truora on 11/11/25.
//

import UIKit
import XCTest
@testable import TruoraValidationsSDK

/// Tests for UploadBaseImageInteractor
/// Verifies image upload coordination and presenter communication
final class UploadBaseImageInteractorTests: XCTestCase {
    // MARK: - Properties

    private var sut: UploadBaseImageInteractor!
    private var mockPresenter: MockUploadBaseImagePresenter!
    private var enrollmentData: EnrollmentData!

    // MARK: - Lifecycle

    override func setUp() {
        super.setUp()
        mockPresenter = MockUploadBaseImagePresenter()
        enrollmentData = EnrollmentData(
            enrollmentId: "test-enrollment-id",
            accountId: "test-account-id",
            uploadUrl: "https://example.com/upload",
            createdAt: Date()
        )
        sut = UploadBaseImageInteractor(
            presenter: mockPresenter,
            enrollmentData: enrollmentData
        )
    }

    override func tearDown() {
        sut = nil
        mockPresenter = nil
        enrollmentData = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialization_storesEnrollmentData() {
        // When
        let interactor = UploadBaseImageInteractor(
            presenter: mockPresenter,
            enrollmentData: enrollmentData
        )

        // Then
        XCTAssertNotNil(interactor, "Interactor should be initialized")
        XCTAssertEqual(
            interactor.enrollmentData.enrollmentId,
            "test-enrollment-id",
            "Should store enrollment data"
        )
    }

    // MARK: - Upload Image Tests

    func testUploadImage_notifiesPresenterOnCompletion() {
        // Given
        guard let testImage = UIImage(systemName: "photo") else {
            XCTFail("Failed to create test image")
            return
        }

        let expectation = self.expectation(description: "Upload completion")
        mockPresenter.onUploadCompleted = {
            expectation.fulfill()
        }

        // When
        sut.uploadImage(testImage)

        // Then
        wait(for: [expectation], timeout: 2.0)
        XCTAssertTrue(
            mockPresenter.uploadCompletedCalled,
            "Should notify presenter when upload completes"
        )
    }

    func testUploadImage_withNilPresenter_doesNotCrash() {
        // Given
        sut.presenter = nil
        guard let testImage = UIImage(systemName: "photo") else {
            XCTFail("Failed to create test image")
            return
        }

        // When
        sut.uploadImage(testImage)

        // Then
        XCTAssertNotNil(sut, "Should handle nil presenter gracefully")
    }

    func testUploadImage_withDifferentImageSizes_handlesCorrectly() {
        // Given
        let sizes: [CGSize] = [
            CGSize(width: 100, height: 100),
            CGSize(width: 1000, height: 1000),
            CGSize(width: 50, height: 200)
        ]

        for size in sizes {
            // Reset for each iteration
            setUp()

            guard let testImage = createTestImage(size: size) else {
                XCTFail("Failed to create test image with size \(size)")
                continue
            }

            let expectation = self.expectation(description: "Upload for size \(size)")
            mockPresenter.onUploadCompleted = {
                expectation.fulfill()
            }

            // When
            sut.uploadImage(testImage)

            // Then
            wait(for: [expectation], timeout: 2.0)
            XCTAssertTrue(
                mockPresenter.uploadCompletedCalled,
                "Should handle image of size \(size)"
            )
        }
    }

    // MARK: - Helper Methods

    private func createTestImage(size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContext(size)
        defer { UIGraphicsEndImageContext() }

        let context = UIGraphicsGetCurrentContext()
        context?.setFillColor(UIColor.blue.cgColor)
        context?.fill(CGRect(origin: .zero, size: size))

        return UIGraphicsGetImageFromCurrentImageContext()
    }
}

// MARK: - Mock Presenter

private final class MockUploadBaseImagePresenter: UploadBaseImageInteractorToPresenter {
    private(set) var uploadCompletedCalled = false
    private(set) var uploadFailedCalled = false
    private(set) var lastError: ValidationError?
    var onUploadCompleted: (() -> Void)?

    func uploadCompleted() {
        uploadCompletedCalled = true
        onUploadCompleted?()
    }

    func uploadFailed(_ error: ValidationError) {
        uploadFailedCalled = true
        lastError = error
    }
}
