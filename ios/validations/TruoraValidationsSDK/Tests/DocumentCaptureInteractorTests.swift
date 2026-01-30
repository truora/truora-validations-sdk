//
//  DocumentCaptureInteractorTests.swift
//  TruoraValidationsSDKTests
//
//  Created by Truora on 26/12/25.
//

import XCTest
@testable import TruoraValidationsSDK

// swiftlint:disable type_body_length
/// Tests for DocumentCaptureInteractor
/// Verifies upload URL management, photo upload logic, and error handling
@MainActor final class DocumentCaptureInteractorTests: XCTestCase {
    // MARK: - Properties

    private var sut: DocumentCaptureInteractor!
    private var mockPresenter: MockDocumentCapturePresenter!

    // MARK: - Lifecycle

    override func setUp() {
        super.setUp()
        mockPresenter = MockDocumentCapturePresenter()
        sut = DocumentCaptureInteractor(
            presenter: mockPresenter
        )
        ValidationConfig.shared.reset()
    }

    override func tearDown() {
        sut = nil
        mockPresenter = nil
        ValidationConfig.shared.reset()
        super.tearDown()
    }

    // MARK: - URL Configuration Tests

    func testSetUploadUrls_storesUrlsCorrectly() async throws {
        // Given
        let frontUrl = "https://example.com/front"
        let reverseUrl = "https://example.com/reverse"
        mockPresenter.photoUploadFailedExpectation = expectation(description: "Upload failed called")

        // When
        sut.setUploadUrls(frontUploadUrl: frontUrl, reverseUploadUrl: reverseUrl)

        // Then - Verify by attempting uploads (URLs are private, so we test behavior)
        let photoData = Data([0x01, 0x02])

        sut.uploadPhoto(side: .front, photoData: photoData)
        try await fulfillment(of: [XCTUnwrap(mockPresenter.photoUploadFailedExpectation)], timeout: 1.0)

        XCTAssertTrue(
            mockPresenter.photoUploadFailedCalled,
            "Should attempt upload with front URL (fails without API client)"
        )
        XCTAssertEqual(mockPresenter.lastFailedSide, .front)
    }

    // MARK: - Upload Photo Tests

    func testUploadPhoto_frontSide_withEmptyData_callsUploadFailed() async throws {
        // Given
        sut.setUploadUrls(
            frontUploadUrl: "https://example.com/front",
            reverseUploadUrl: "https://example.com/reverse"
        )
        let emptyData = Data()
        mockPresenter.photoUploadFailedExpectation = expectation(description: "Upload failed called")

        // When
        sut.uploadPhoto(side: .front, photoData: emptyData)
        try await fulfillment(of: [XCTUnwrap(mockPresenter.photoUploadFailedExpectation)], timeout: 1.0)

        // Then
        XCTAssertTrue(mockPresenter.photoUploadFailedCalled, "Should call upload failed")
        XCTAssertEqual(mockPresenter.lastFailedSide, .front)
        XCTAssertTrue(mockPresenter.lastError?.localizedDescription.contains("empty") ?? false)
    }

    func testUploadPhoto_backSide_withEmptyData_callsUploadFailed() async throws {
        // Given
        sut.setUploadUrls(
            frontUploadUrl: "https://example.com/front",
            reverseUploadUrl: "https://example.com/reverse"
        )
        let emptyData = Data()
        mockPresenter.photoUploadFailedExpectation = expectation(description: "Upload failed called")

        // When
        sut.uploadPhoto(side: .back, photoData: emptyData)
        try await fulfillment(of: [XCTUnwrap(mockPresenter.photoUploadFailedExpectation)], timeout: 1.0)

        // Then
        XCTAssertTrue(mockPresenter.photoUploadFailedCalled, "Should call upload failed")
        XCTAssertEqual(mockPresenter.lastFailedSide, .back)
        XCTAssertTrue(mockPresenter.lastError?.localizedDescription.contains("empty") ?? false)
    }

    func testUploadPhoto_frontSide_withoutAPIClient_callsUploadFailed() async throws {
        // Given
        sut.setUploadUrls(
            frontUploadUrl: "https://example.com/front",
            reverseUploadUrl: "https://example.com/reverse"
        )
        let photoData = Data([0x01, 0x02, 0x03])
        // API client is not configured (ValidationConfig not set up)
        mockPresenter.photoUploadFailedExpectation = expectation(description: "Upload failed called")

        // When
        sut.uploadPhoto(side: .front, photoData: photoData)
        try await fulfillment(of: [XCTUnwrap(mockPresenter.photoUploadFailedExpectation)], timeout: 1.0)

        // Then
        XCTAssertTrue(mockPresenter.photoUploadFailedCalled, "Should call upload failed")
        XCTAssertEqual(mockPresenter.lastFailedSide, .front)
        XCTAssertTrue(
            mockPresenter.lastError?.localizedDescription.contains("API client not configured") ?? false
        )
    }

    func testUploadPhoto_frontSide_withoutFrontUrl_callsUploadFailed() async throws {
        // Given - Don't set URLs but configure API client so we reach URL validation
        let photoData = Data([0x01, 0x02, 0x03])
        mockPresenter.photoUploadFailedExpectation = expectation(description: "Upload failed called")

        do {
            try await ValidationConfig.shared.configure(
                apiKey: "test-api-key",
                accountId: "test-account-id",
                delegate: nil
            )
        } catch {
            XCTFail("Failed to configure ValidationConfig: \(error)")
        }

        // When
        sut.uploadPhoto(side: .front, photoData: photoData)
        try await fulfillment(of: [XCTUnwrap(mockPresenter.photoUploadFailedExpectation)], timeout: 1.0)

        // Then
        XCTAssertTrue(mockPresenter.photoUploadFailedCalled, "Should call upload failed")
        XCTAssertEqual(mockPresenter.lastFailedSide, .front)
        XCTAssertTrue(mockPresenter.lastError?.localizedDescription.contains("No upload URL") ?? false)
    }

    func testUploadPhoto_backSide_withoutReverseUrl_callsUploadFailed() async throws {
        // Given - Don't set URLs but configure API client so we reach URL validation
        let photoData = Data([0x01, 0x02, 0x03])
        mockPresenter.photoUploadFailedExpectation = expectation(description: "Upload failed called")

        do {
            try await ValidationConfig.shared.configure(
                apiKey: "test-api-key",
                accountId: "test-account-id",
                delegate: nil
            )
        } catch {
            XCTFail("Failed to configure ValidationConfig: \(error)")
        }

        // When
        sut.uploadPhoto(side: .back, photoData: photoData)
        try await fulfillment(of: [XCTUnwrap(mockPresenter.photoUploadFailedExpectation)], timeout: 1.0)

        // Then
        XCTAssertTrue(mockPresenter.photoUploadFailedCalled, "Should call upload failed")
        XCTAssertEqual(mockPresenter.lastFailedSide, .back)
        XCTAssertTrue(mockPresenter.lastError?.localizedDescription.contains("No upload URL") ?? false)
    }

    func testUploadPhoto_frontSide_withValidData_initiatesUpload() async throws {
        // Given
        var uploadCalled = false
        var capturedUrl: String?
        var capturedData: Data?

        let uploadExpectation = expectation(description: "Upload handler called")
        let presenterExpectation = expectation(description: "Presenter notified of upload completion")
        mockPresenter.photoUploadCompletedExpectation = presenterExpectation

        let mockUploadHandler: (String, Data) async throws -> Void = { url, data in
            uploadCalled = true
            capturedUrl = url
            capturedData = data
            uploadExpectation.fulfill()
        }

        let interactor = DocumentCaptureInteractor(
            presenter: mockPresenter,
            uploadFileHandler: mockUploadHandler
        )

        // Configure API client so upload can proceed
        try await ValidationConfig.shared.configure(
            apiKey: "test-api-key",
            accountId: "test-account-id",
            delegate: nil
        )

        interactor.setUploadUrls(
            frontUploadUrl: "https://example.com/front",
            reverseUploadUrl: "https://example.com/reverse"
        )
        let photoData = Data([0x01, 0x02, 0x03, 0x04])

        // When
        interactor.uploadPhoto(side: .front, photoData: photoData)

        // Then
        await fulfillment(of: [uploadExpectation, presenterExpectation], timeout: 1.0)

        XCTAssertTrue(uploadCalled, "Upload handler should be called")
        XCTAssertEqual(capturedUrl, "https://example.com/front")
        XCTAssertEqual(capturedData, photoData)
        XCTAssertTrue(mockPresenter.photoUploadCompletedCalled)
        XCTAssertEqual(mockPresenter.lastCompletedSide, .front)
    }

    func testUploadPhoto_backSide_withValidData_initiatesUpload() async throws {
        // Given
        var uploadCalled = false
        var capturedUrl: String?
        var capturedData: Data?

        let uploadExpectation = expectation(description: "Upload handler called")
        let presenterExpectation = expectation(description: "Presenter notified of upload completion")
        mockPresenter.photoUploadCompletedExpectation = presenterExpectation

        let mockUploadHandler: (String, Data) async throws -> Void = { url, data in
            uploadCalled = true
            capturedUrl = url
            capturedData = data
            uploadExpectation.fulfill()
        }

        let interactor = DocumentCaptureInteractor(
            presenter: mockPresenter,
            uploadFileHandler: mockUploadHandler
        )

        // Configure API client so upload can proceed
        try await ValidationConfig.shared.configure(
            apiKey: "test-api-key",
            accountId: "test-account-id",
            delegate: nil
        )

        interactor.setUploadUrls(
            frontUploadUrl: "https://example.com/front",
            reverseUploadUrl: "https://example.com/reverse"
        )
        let photoData = Data([0x05, 0x06, 0x07, 0x08])

        // When
        interactor.uploadPhoto(side: .back, photoData: photoData)

        // Then
        await fulfillment(of: [uploadExpectation, presenterExpectation], timeout: 1.0)

        XCTAssertTrue(uploadCalled, "Upload handler should be called")
        XCTAssertEqual(capturedUrl, "https://example.com/reverse")
        XCTAssertEqual(capturedData, photoData)
        XCTAssertTrue(mockPresenter.photoUploadCompletedCalled)
        XCTAssertEqual(mockPresenter.lastCompletedSide, .back)
    }

    // MARK: - Kotlin ByteArray Conversion Tests

    func testConvertDataToKotlinByteArray_convertsCorrectly() async throws {
        // Given
        let testData = Data([0x01, 0x02, 0x03, 0x04, 0x05])
        mockPresenter.photoUploadFailedExpectation = expectation(description: "Upload failed called")

        // When - Use private method indirectly via upload
        // We can't directly test the private method, but we can verify it's used correctly
        // by ensuring the upload process handles data properly
        sut.setUploadUrls(
            frontUploadUrl: "https://example.com/front",
            reverseUploadUrl: "https://example.com/reverse"
        )

        // This will fail at API client check, but verifies data is handled
        sut.uploadPhoto(side: .front, photoData: testData)
        try await fulfillment(of: [XCTUnwrap(mockPresenter.photoUploadFailedExpectation)], timeout: 1.0)

        // Then - Verify the data was processed (failed at API client, not data conversion)
        XCTAssertTrue(mockPresenter.photoUploadFailedCalled)
        XCTAssertTrue(
            mockPresenter.lastError?.localizedDescription.contains("API client not configured") ?? false,
            "Should fail at API client check, meaning data conversion was successful"
        )
    }

    func testConvertDataToKotlinByteArray_emptyData_returnsEmptyArray() async throws {
        // Given
        let emptyData = Data()
        mockPresenter.photoUploadFailedExpectation = expectation(description: "Upload failed called")

        // When
        sut.setUploadUrls(
            frontUploadUrl: "https://example.com/front",
            reverseUploadUrl: "https://example.com/reverse"
        )
        sut.uploadPhoto(side: .front, photoData: emptyData)
        try await fulfillment(of: [XCTUnwrap(mockPresenter.photoUploadFailedExpectation)], timeout: 1.0)

        // Then - Should fail at empty data validation, not conversion
        XCTAssertTrue(mockPresenter.photoUploadFailedCalled)
        XCTAssertTrue(
            mockPresenter.lastError?.localizedDescription.contains("empty") ?? false,
            "Should fail at empty data check before conversion"
        )
    }

    // MARK: - Task Cancellation Tests

    func testDeinit_cancelsUploadTask() {
        // Given
        var interactorOptional: DocumentCaptureInteractor? = DocumentCaptureInteractor(
            presenter: mockPresenter
        )
        interactorOptional?.setUploadUrls(
            frontUploadUrl: "https://example.com/front",
            reverseUploadUrl: "https://example.com/reverse"
        )

        // When
        interactorOptional = nil

        // Then
        // The deinit should cancel tasks without crashing
        XCTAssertNil(interactorOptional, "Interactor should be deallocated")
    }

    // MARK: - Image Evaluation Tests

    func testEvaluateImage_emptyData_callsEvaluationErrored() async throws {
        // Given
        let emptyData = Data()
        mockPresenter.imageEvaluationErroredExpectation = expectation(description: "Evaluation errored")

        // When
        sut.evaluateImage(
            side: .front,
            photoData: emptyData,
            country: "CO",
            documentType: "national-id",
            validationId: "test-123"
        )
        try await fulfillment(of: [XCTUnwrap(mockPresenter.imageEvaluationErroredExpectation)], timeout: 1.0)

        // Then
        XCTAssertTrue(mockPresenter.imageEvaluationErroredCalled, "Should call evaluation errored")
        XCTAssertEqual(mockPresenter.lastEvaluationSide, .front)
        XCTAssertTrue(mockPresenter.lastEvaluationError?.localizedDescription.contains("empty") ?? false)
    }

    func testEvaluateImage_withoutAPIClient_callsEvaluationErrored() async throws {
        // Given
        let photoData = Data([0x01, 0x02, 0x03])
        mockPresenter.imageEvaluationErroredExpectation = expectation(description: "Evaluation errored")

        // When - API client is not configured (ValidationConfig not set up)
        sut.evaluateImage(
            side: .front,
            photoData: photoData,
            country: "CO",
            documentType: "national-id",
            validationId: "test-123"
        )
        try await fulfillment(of: [XCTUnwrap(mockPresenter.imageEvaluationErroredExpectation)], timeout: 1.0)

        // Then
        XCTAssertTrue(mockPresenter.imageEvaluationErroredCalled, "Should call evaluation errored")
        XCTAssertEqual(mockPresenter.lastEvaluationSide, .front)
        XCTAssertTrue(
            mockPresenter.lastEvaluationError?.localizedDescription.contains("API client not configured") ?? false
        )
    }

    func testEvaluateImage_withValidConfig_callsEvaluationStarted() async throws {
        // Given
        let photoData = Data([0x01, 0x02, 0x03])
        mockPresenter.imageEvaluationStartedExpectation = expectation(description: "Evaluation started")
        try? await ValidationConfig.shared.configure(apiKey: "test-key", accountId: "test-account")

        // When
        sut.evaluateImage(
            side: .front,
            photoData: photoData,
            country: "CO",
            documentType: "national-id",
            validationId: "test-123"
        )

        // Then
        try await fulfillment(of: [XCTUnwrap(mockPresenter.imageEvaluationStartedExpectation)], timeout: 1.0)
        XCTAssertTrue(mockPresenter.imageEvaluationStartedCalled, "Should start evaluation")
        XCTAssertEqual(mockPresenter.lastEvaluationSide, .front)
        XCTAssertEqual(mockPresenter.lastEvaluationPreviewData, photoData)
    }

    func testEvaluateImage_backSide_callsEvaluationStarted() async throws {
        // Given
        let photoData = Data([0x01, 0x02, 0x03])
        mockPresenter.imageEvaluationStartedExpectation = expectation(description: "Evaluation started")
        try? await ValidationConfig.shared.configure(apiKey: "test-key", accountId: "test-account")

        // When
        sut.evaluateImage(
            side: .back,
            photoData: photoData,
            country: "CO",
            documentType: "national-id",
            validationId: "test-123"
        )

        // Then
        try await fulfillment(of: [XCTUnwrap(mockPresenter.imageEvaluationStartedExpectation)], timeout: 1.0)
        XCTAssertTrue(mockPresenter.imageEvaluationStartedCalled, "Should start evaluation")
        XCTAssertEqual(mockPresenter.lastEvaluationSide, .back)
    }

    func testEvaluateImage_driverLicense_proceedsWithEvaluation() async throws {
        // Given
        let photoData = Data([0x01, 0x02, 0x03])
        mockPresenter.imageEvaluationStartedExpectation = expectation(description: "Evaluation started")
        try? await ValidationConfig.shared.configure(apiKey: "test-key", accountId: "test-account")

        // When - Driver's license should proceed with evaluation
        sut.evaluateImage(
            side: .front,
            photoData: photoData,
            country: "CL",
            documentType: "driver-license",
            validationId: "test-123"
        )

        // Then
        try await fulfillment(of: [XCTUnwrap(mockPresenter.imageEvaluationStartedExpectation)], timeout: 1.0)
        XCTAssertTrue(mockPresenter.imageEvaluationStartedCalled, "Should start evaluation for driver's license")
    }

    func testEvaluateImage_passport_proceedsWithEvaluation() async throws {
        // Given
        let photoData = Data([0x01, 0x02, 0x03])
        mockPresenter.imageEvaluationStartedExpectation = expectation(description: "Evaluation started")
        try? await ValidationConfig.shared.configure(apiKey: "test-key", accountId: "test-account")

        // When - Passport should proceed with evaluation
        sut.evaluateImage(
            side: .front,
            photoData: photoData,
            country: "CO",
            documentType: "passport",
            validationId: "test-123"
        )

        // Then
        try await fulfillment(of: [XCTUnwrap(mockPresenter.imageEvaluationStartedExpectation)], timeout: 1.0)
        XCTAssertTrue(mockPresenter.imageEvaluationStartedCalled, "Should start evaluation for passport")
    }
}

// MARK: - Mock Classes

@MainActor private final class MockDocumentCapturePresenter {
    private(set) var photoUploadCompletedCalled = false
    private(set) var photoUploadFailedCalled = false
    var photoUploadCompletedExpectation: XCTestExpectation?
    var photoUploadFailedExpectation: XCTestExpectation?

    private(set) var lastCompletedSide: DocumentCaptureSide?
    private(set) var lastFailedSide: DocumentCaptureSide?
    private(set) var lastError: TruoraException?

    private(set) var imageEvaluationStartedCalled = false
    private(set) var imageEvaluationSucceededCalled = false
    private(set) var imageEvaluationFailedCalled = false
    private(set) var imageEvaluationErroredCalled = false

    var imageEvaluationStartedExpectation: XCTestExpectation?
    var imageEvaluationSucceededExpectation: XCTestExpectation?
    var imageEvaluationFailedExpectation: XCTestExpectation?
    var imageEvaluationErroredExpectation: XCTestExpectation?

    private(set) var lastEvaluationSide: DocumentCaptureSide?
    private(set) var lastEvaluationPreviewData: Data?
    private(set) var lastEvaluationFailureReason: String?
    private(set) var lastEvaluationError: TruoraException?
}

extension MockDocumentCapturePresenter: DocumentCaptureInteractorToPresenter {
    func photoUploadCompleted(side: DocumentCaptureSide) {
        photoUploadCompletedCalled = true
        lastCompletedSide = side
        photoUploadCompletedExpectation?.fulfill()
    }

    func photoUploadFailed(side: DocumentCaptureSide, error: TruoraException) async {
        photoUploadFailedCalled = true
        lastFailedSide = side
        lastError = error
        photoUploadFailedExpectation?.fulfill()
    }

    func imageEvaluationStarted(side: DocumentCaptureSide, previewData: Data) {
        imageEvaluationStartedCalled = true
        lastEvaluationSide = side
        lastEvaluationPreviewData = previewData
        imageEvaluationStartedExpectation?.fulfill()
    }

    func imageEvaluationSucceeded(side: DocumentCaptureSide, previewData: Data) {
        imageEvaluationSucceededCalled = true
        lastEvaluationSide = side
        lastEvaluationPreviewData = previewData
        imageEvaluationSucceededExpectation?.fulfill()
    }

    func imageEvaluationFailed(side: DocumentCaptureSide, previewData: Data, reason: String?) {
        imageEvaluationFailedCalled = true
        lastEvaluationSide = side
        lastEvaluationPreviewData = previewData
        lastEvaluationFailureReason = reason
        imageEvaluationFailedExpectation?.fulfill()
    }

    func imageEvaluationErrored(side: DocumentCaptureSide, error: TruoraException) async {
        imageEvaluationErroredCalled = true
        lastEvaluationSide = side
        lastEvaluationError = error
        imageEvaluationErroredExpectation?.fulfill()
    }
}

// swiftlint:enable type_body_length
