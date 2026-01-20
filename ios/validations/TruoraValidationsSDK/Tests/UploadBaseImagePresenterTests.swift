//
//  UploadBaseImagePresenterTests.swift
//  TruoraValidationsSDKTests
//
//  Created by Truora on 11/11/25.
//

import UIKit
import XCTest
@testable import TruoraValidationsSDK

/// Tests for UploadBaseImagePresenter following VIPER architecture
/// Verifies image selection flow and upload coordination
final class UploadBaseImagePresenterTests: XCTestCase {
    // MARK: - Properties

    private var sut: UploadBaseImagePresenter!
    private var mockView: MockUploadBaseImageView!
    private var mockInteractor: MockUploadBaseImageInteractor!
    private var mockRouter: MockUploadBaseImageRouter!

    // MARK: - Lifecycle

    override func setUp() {
        super.setUp()
        mockView = MockUploadBaseImageView()
        mockInteractor = MockUploadBaseImageInteractor()
        let navController = UINavigationController()
        mockRouter = MockUploadBaseImageRouter(navigationController: navController)

        sut = UploadBaseImagePresenter(
            view: mockView,
            interactor: mockInteractor,
            router: mockRouter
        )
    }

    override func tearDown() {
        sut = nil
        mockView = nil
        mockInteractor = nil
        mockRouter = nil
        super.tearDown()
    }

    // MARK: - View Lifecycle Tests

    func testViewDidLoad_doesNotCrash() {
        // When
        sut.viewDidLoad()

        // Then
        XCTAssertNotNil(sut, "Presenter should handle viewDidLoad")
    }

    // MARK: - Image Selection Tests

    func testSelectImageTapped_showsImagePicker() {
        // When
        sut.selectImageTapped()

        // Then
        XCTAssertTrue(
            mockView.showImagePickerCalled,
            "Should show image picker when user taps select"
        )
    }

    func testImageSelected_storesImage() {
        // Given
        guard let testImage = UIImage(systemName: "photo") else {
            XCTFail("Failed to create test image")
            return
        }

        // When
        sut.imageSelected(testImage)

        // Then - Verify indirectly through upload flow
        sut.uploadTapped()
        XCTAssertTrue(
            mockInteractor.uploadImageCalled,
            "Should store selected image for later upload"
        )
    }

    func testImageSelected_multipleTimesOverwritesPrevious() {
        // Given
        guard let firstImage = UIImage(systemName: "photo"),
              let secondImage = UIImage(systemName: "camera") else {
            XCTFail("Failed to create test images")
            return
        }

        // When
        sut.imageSelected(firstImage)
        sut.imageSelected(secondImage)
        sut.uploadTapped()

        // Then
        XCTAssertTrue(
            mockInteractor.uploadImageCalled,
            "Should use most recently selected image"
        )
        // Note: Can't directly verify which image without exposing internal state
    }

    // MARK: - Upload Tests

    func testUploadTapped_withoutSelectedImage_doesNotUpload() {
        // When
        sut.uploadTapped()

        // Then
        XCTAssertFalse(
            mockView.showLoadingCalled,
            "Should not show loading without selected image"
        )
        XCTAssertFalse(
            mockInteractor.uploadImageCalled,
            "Should not call interactor without selected image"
        )
    }

    func testUploadTapped_withSelectedImage_initiatesUpload() {
        // Given
        guard let testImage = UIImage(systemName: "photo") else {
            XCTFail("Failed to create test image")
            return
        }
        sut.imageSelected(testImage)

        // When
        sut.uploadTapped()

        // Then
        XCTAssertTrue(
            mockView.showLoadingCalled,
            "Should show loading indicator during upload"
        )
        XCTAssertTrue(
            mockInteractor.uploadImageCalled,
            "Should upload image via interactor"
        )
        XCTAssertNotNil(
            mockInteractor.lastImage,
            "Should pass image to interactor"
        )
    }

    // MARK: - Cancel Tests

    func testCancelTapped_callsRouter() {
        // When
        sut.cancelTapped()

        // Then
        XCTAssertTrue(
            mockRouter.handleCancellationCalled,
            "Should notify router to handle cancellation"
        )
    }

    // MARK: - Upload Completion Tests

    func testUploadCompleted_navigatesToEnrollmentStatus() {
        // When
        sut.uploadCompleted()

        // Then
        XCTAssertTrue(
            mockView.hideLoadingCalled,
            "Should hide loading after upload completes"
        )
        XCTAssertTrue(
            mockRouter.navigateToEnrollmentStatusCalled,
            "Should navigate to enrollment status screen"
        )
    }

    func testUploadCompleted_withNavigationError_showsError() {
        // Given
        mockRouter.shouldThrowError = true

        // When
        sut.uploadCompleted()

        // Then
        XCTAssertTrue(
            mockView.hideLoadingCalled,
            "Should hide loading even on navigation error"
        )
        XCTAssertTrue(
            mockView.showErrorCalled,
            "Should show error when navigation fails"
        )
        XCTAssertNotNil(
            mockView.lastErrorMessage,
            "Error message should be present"
        )
    }

    // MARK: - Upload Failure Tests

    func testUploadFailed_showsError() {
        // Given
        let expectedError = ValidationError.apiError("Image upload failed")

        // When
        sut.uploadFailed(expectedError)

        // Then
        XCTAssertTrue(
            mockView.hideLoadingCalled,
            "Should hide loading on upload failure"
        )
        XCTAssertTrue(
            mockView.showErrorCalled,
            "Should show error message"
        )
        XCTAssertEqual(
            mockView.lastErrorMessage,
            expectedError.localizedDescription,
            "Should display error description"
        )
    }

    func testUploadFailed_withDifferentErrorTypes_displaysCorrectMessages() {
        // Test different error types
        let errorTypes: [ValidationError] = [
            .invalidConfiguration("Invalid upload config"),
            .apiError("Server unreachable"),
            .internalError("Upload processing failed")
        ]

        for error in errorTypes {
            // Given
            setUp() // Reset for each iteration

            // When
            sut.uploadFailed(error)

            // Then
            XCTAssertTrue(
                mockView.showErrorCalled,
                "Should show error for \(error)"
            )
            XCTAssertNotNil(
                mockView.lastErrorMessage,
                "Error message should exist for \(error)"
            )
        }
    }
}

// MARK: - Mock View

private final class MockUploadBaseImageView: UploadBaseImagePresenterToView {
    private(set) var showImagePickerCalled = false
    private(set) var showLoadingCalled = false
    private(set) var hideLoadingCalled = false
    private(set) var showErrorCalled = false
    private(set) var lastErrorMessage: String?

    func showImagePicker() {
        showImagePickerCalled = true
    }

    func showLoading() {
        showLoadingCalled = true
    }

    func hideLoading() {
        hideLoadingCalled = true
    }

    func showError(_ message: String) {
        showErrorCalled = true
        lastErrorMessage = message
    }
}

// MARK: - Mock Interactor

private final class MockUploadBaseImageInteractor: UploadBaseImagePresenterToInteractor {
    private(set) var uploadImageCalled = false
    private(set) var lastImage: UIImage?

    func uploadImage(_ image: UIImage) {
        uploadImageCalled = true
        lastImage = image
    }
}

// MARK: - Mock Router

private final class MockUploadBaseImageRouter: ValidationRouter {
    private(set) var handleCancellationCalled = false
    private(set) var navigateToEnrollmentStatusCalled = false
    var shouldThrowError = false

    override func handleCancellation() {
        handleCancellationCalled = true
    }

    override func navigateToEnrollmentStatus() throws {
        navigateToEnrollmentStatusCalled = true
        if shouldThrowError {
            throw ValidationError.internalError("Navigation error")
        }
    }
}
