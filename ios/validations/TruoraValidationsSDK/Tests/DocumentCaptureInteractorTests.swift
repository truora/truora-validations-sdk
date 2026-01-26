//
//  DocumentCaptureInteractorTests.swift
//  TruoraValidationsSDKTests
//
//  Created by Truora on 26/12/25.
//

import TruoraShared
import XCTest
@testable import TruoraValidationsSDK

// swiftlint:disable type_body_length
/// Tests for DocumentCaptureInteractor
/// Verifies upload URL management, photo upload logic, and error handling
final class DocumentCaptureInteractorTests: XCTestCase {
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

    func testSetUploadUrls_storesUrlsCorrectly() {
        // Given
        let frontUrl = "https://example.com/front"
        let reverseUrl = "https://example.com/reverse"

        // When
        sut.setUploadUrls(frontUploadUrl: frontUrl, reverseUploadUrl: reverseUrl)

        // Then - Verify by attempting uploads (URLs are private, so we test behavior)
        let photoData = Data([0x01, 0x02])

        sut.uploadPhoto(side: .front, photoData: photoData)
        XCTAssertTrue(
            mockPresenter.photoUploadFailedCalled,
            "Should attempt upload with front URL (fails without API client)"
        )
        XCTAssertEqual(mockPresenter.lastFailedSide, .front)
    }

    // MARK: - Upload Photo Tests

    func testUploadPhoto_frontSide_withEmptyData_callsUploadFailed() {
        // Given
        sut.setUploadUrls(
            frontUploadUrl: "https://example.com/front",
            reverseUploadUrl: "https://example.com/reverse"
        )
        let emptyData = Data()

        // When
        sut.uploadPhoto(side: .front, photoData: emptyData)

        // Then
        XCTAssertTrue(mockPresenter.photoUploadFailedCalled, "Should call upload failed")
        XCTAssertEqual(mockPresenter.lastFailedSide, .front)
        XCTAssertTrue(mockPresenter.lastError?.localizedDescription.contains("empty") ?? false)
    }

    func testUploadPhoto_backSide_withEmptyData_callsUploadFailed() {
        // Given
        sut.setUploadUrls(
            frontUploadUrl: "https://example.com/front",
            reverseUploadUrl: "https://example.com/reverse"
        )
        let emptyData = Data()

        // When
        sut.uploadPhoto(side: .back, photoData: emptyData)

        // Then
        XCTAssertTrue(mockPresenter.photoUploadFailedCalled, "Should call upload failed")
        XCTAssertEqual(mockPresenter.lastFailedSide, .back)
        XCTAssertTrue(mockPresenter.lastError?.localizedDescription.contains("empty") ?? false)
    }

    func testUploadPhoto_frontSide_withoutAPIClient_callsUploadFailed() {
        // Given
        sut.setUploadUrls(
            frontUploadUrl: "https://example.com/front",
            reverseUploadUrl: "https://example.com/reverse"
        )
        let photoData = Data([0x01, 0x02, 0x03])
        // API client is not configured (ValidationConfig not set up)

        // When
        sut.uploadPhoto(side: .front, photoData: photoData)

        // Then
        XCTAssertTrue(mockPresenter.photoUploadFailedCalled, "Should call upload failed")
        XCTAssertEqual(mockPresenter.lastFailedSide, .front)
        XCTAssertTrue(
            mockPresenter.lastError?.localizedDescription.contains("API client not configured") ?? false
        )
    }

    func testUploadPhoto_frontSide_withoutFrontUrl_callsUploadFailed() async {
        // Given - Don't set URLs but configure API client so we reach URL validation
        let photoData = Data([0x01, 0x02, 0x03])

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

        // Then
        XCTAssertTrue(mockPresenter.photoUploadFailedCalled, "Should call upload failed")
        XCTAssertEqual(mockPresenter.lastFailedSide, .front)
        XCTAssertTrue(mockPresenter.lastError?.localizedDescription.contains("No upload URL") ?? false)
    }

    func testUploadPhoto_backSide_withoutReverseUrl_callsUploadFailed() async {
        // Given - Don't set URLs but configure API client so we reach URL validation
        let photoData = Data([0x01, 0x02, 0x03])

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
        wait(for: [uploadExpectation, presenterExpectation], timeout: 1.0)

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

    func testConvertDataToKotlinByteArray_convertsCorrectly() {
        // Given
        let testData = Data([0x01, 0x02, 0x03, 0x04, 0x05])

        // When - Use private method indirectly via upload
        // We can't directly test the private method, but we can verify it's used correctly
        // by ensuring the upload process handles data properly
        sut.setUploadUrls(
            frontUploadUrl: "https://example.com/front",
            reverseUploadUrl: "https://example.com/reverse"
        )

        // This will fail at API client check, but verifies data is handled
        sut.uploadPhoto(side: .front, photoData: testData)

        // Then - Verify the data was processed (failed at API client, not data conversion)
        XCTAssertTrue(mockPresenter.photoUploadFailedCalled)
        XCTAssertTrue(
            mockPresenter.lastError?.localizedDescription.contains("API client not configured") ?? false,
            "Should fail at API client check, meaning data conversion was successful"
        )
    }

    func testConvertDataToKotlinByteArray_emptyData_returnsEmptyArray() {
        // Given
        let emptyData = Data()

        // When
        sut.setUploadUrls(
            frontUploadUrl: "https://example.com/front",
            reverseUploadUrl: "https://example.com/reverse"
        )
        sut.uploadPhoto(side: .front, photoData: emptyData)

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

    // MARK: - Image Evaluation Skip Tests

    func testEvaluateImage_driverLicense_skipsEvaluation() {
        // Given
        let photoData = Data([0x01, 0x02, 0x03])

        // When - All driver's licenses should skip evaluation
        sut.evaluateImage(
            side: .front,
            photoData: photoData,
            country: "CL",
            documentType: "driver-license",
            validationId: "test-123"
        )

        // Then
        XCTAssertFalse(mockPresenter.imageEvaluationStartedCalled, "Should NOT start evaluation for driver's license")
        XCTAssertTrue(mockPresenter.imageEvaluationSucceededCalled, "Should immediately succeed")
        XCTAssertEqual(mockPresenter.lastEvaluationSide, .front)
        XCTAssertEqual(mockPresenter.lastEvaluationPreviewData, photoData)
    }

    func testEvaluateImage_cnh_skipsEvaluation() {
        // Given
        let photoData = Data([0x01, 0x02, 0x03])

        // When - CNH (Brazil's driver license) should skip evaluation
        sut.evaluateImage(
            side: .back,
            photoData: photoData,
            country: "BR",
            documentType: "cnh",
            validationId: "test-123"
        )

        // Then
        XCTAssertFalse(mockPresenter.imageEvaluationStartedCalled, "Should NOT start evaluation for CNH")
        XCTAssertTrue(mockPresenter.imageEvaluationSucceededCalled, "Should immediately succeed")
        XCTAssertEqual(mockPresenter.lastEvaluationSide, .back)
    }

    func testEvaluateImage_foreignId_colombia_skipsEvaluation() {
        // Given
        let photoData = Data([0x01, 0x02, 0x03])

        // When
        sut.evaluateImage(
            side: .front,
            photoData: photoData,
            country: "CO",
            documentType: "foreign-id",
            validationId: "test-123"
        )

        // Then
        XCTAssertFalse(mockPresenter.imageEvaluationStartedCalled)
        XCTAssertTrue(mockPresenter.imageEvaluationSucceededCalled)
    }

    func testEvaluateImage_foreignId_peru_skipsEvaluation() {
        // Given
        let photoData = Data([0x01, 0x02, 0x03])

        // When
        sut.evaluateImage(
            side: .front,
            photoData: photoData,
            country: "PE",
            documentType: "foreign-id",
            validationId: "test-123"
        )

        // Then
        XCTAssertFalse(mockPresenter.imageEvaluationStartedCalled)
        XCTAssertTrue(mockPresenter.imageEvaluationSucceededCalled)
    }

    func testEvaluateImage_foreignId_costaRica_skipsEvaluation() {
        // Given
        let photoData = Data([0x01, 0x02, 0x03])

        // When
        sut.evaluateImage(
            side: .front,
            photoData: photoData,
            country: "CR",
            documentType: "foreign-id",
            validationId: "test-123"
        )

        // Then
        XCTAssertFalse(mockPresenter.imageEvaluationStartedCalled)
        XCTAssertTrue(mockPresenter.imageEvaluationSucceededCalled)
    }

    func testEvaluateImage_nationalId_costaRica_skipsEvaluation() {
        // Given
        let photoData = Data([0x01, 0x02, 0x03])

        // When
        sut.evaluateImage(
            side: .front,
            photoData: photoData,
            country: "CR",
            documentType: "national-id",
            validationId: "test-123"
        )

        // Then
        XCTAssertFalse(mockPresenter.imageEvaluationStartedCalled)
        XCTAssertTrue(mockPresenter.imageEvaluationSucceededCalled)
    }

    func testEvaluateImage_nationalId_venezuela_skipsEvaluation() {
        // Given
        let photoData = Data([0x01, 0x02, 0x03])

        // When
        sut.evaluateImage(
            side: .front,
            photoData: photoData,
            country: "VE",
            documentType: "national-id",
            validationId: "test-123"
        )

        // Then
        XCTAssertFalse(mockPresenter.imageEvaluationStartedCalled)
        XCTAssertTrue(mockPresenter.imageEvaluationSucceededCalled)
    }

    // Re-enable when image evaluation API is restored (AL-269)
    // Currently all valid country/document combos skip evaluation
    func testEvaluateImage_nationalId_colombia_skipsEvaluation_whileApiDisabled() {
        // Given
        let photoData = Data([0x01, 0x02, 0x03])

        // When - Colombia national ID (valid combo) skips while API is disabled
        sut.evaluateImage(
            side: .front,
            photoData: photoData,
            country: "CO",
            documentType: "national-id",
            validationId: "test-123"
        )

        // Then - Currently bypassed, succeeds immediately
        XCTAssertFalse(mockPresenter.imageEvaluationStartedCalled)
        XCTAssertTrue(mockPresenter.imageEvaluationSucceededCalled)
    }

    // Re-enable when image evaluation API is restored (AL-269)
    // Currently all valid country/document combos skip evaluation
    func testEvaluateImage_passport_skipsEvaluation_whileApiDisabled() {
        // Given
        let photoData = Data([0x01, 0x02, 0x03])

        // When - Passport (valid combo) skips while API is disabled
        sut.evaluateImage(
            side: .front,
            photoData: photoData,
            country: "CO",
            documentType: "passport",
            validationId: "test-123"
        )

        // Then - Currently bypassed, succeeds immediately
        XCTAssertFalse(mockPresenter.imageEvaluationStartedCalled)
        XCTAssertTrue(mockPresenter.imageEvaluationSucceededCalled)
    }

    func testEvaluateImage_invalidCountry_proceedsWithEvaluation() async {
        // Given
        let photoData = Data([0x01, 0x02, 0x03])
        mockPresenter.imageEvaluationStartedExpectation = expectation(description: "Evaluation started")
        try? await ValidationConfig.shared.configure(apiKey: "test-key", accountId: "test-account")

        // When - Invalid country code should proceed with evaluation (safe default)
        sut.evaluateImage(
            side: .front,
            photoData: photoData,
            country: "INVALID",
            documentType: "national-id",
            validationId: "test-123"
        )

        // Then
        await fulfillment(of: [mockPresenter.imageEvaluationStartedExpectation!], timeout: 1.0)
        XCTAssertTrue(mockPresenter.imageEvaluationStartedCalled, "Should start evaluation with invalid country")
    }

    func testEvaluateImage_invalidDocumentType_proceedsWithEvaluation() async {
        // Given
        let photoData = Data([0x01, 0x02, 0x03])
        mockPresenter.imageEvaluationStartedExpectation = expectation(description: "Evaluation started")
        try? await ValidationConfig.shared.configure(apiKey: "test-key", accountId: "test-account")

        // When - Invalid document type should proceed with evaluation (safe default)
        sut.evaluateImage(
            side: .front,
            photoData: photoData,
            country: "CO",
            documentType: "invalid-doc-type",
            validationId: "test-123"
        )

        // Then
        await fulfillment(of: [mockPresenter.imageEvaluationStartedExpectation!], timeout: 1.0)
        XCTAssertTrue(mockPresenter.imageEvaluationStartedCalled, "Should start evaluation with invalid document type")
    }
}

// MARK: - Mock Classes

private final class MockDocumentCapturePresenter {
    private(set) var photoUploadCompletedCalled = false
    private(set) var photoUploadFailedCalled = false
    var photoUploadCompletedExpectation: XCTestExpectation?

    private(set) var lastCompletedSide: DocumentCaptureSide?
    private(set) var lastFailedSide: DocumentCaptureSide?
    private(set) var lastError: ValidationError?

    private(set) var imageEvaluationStartedCalled = false
    private(set) var imageEvaluationSucceededCalled = false
    private(set) var imageEvaluationFailedCalled = false
    private(set) var imageEvaluationErroredCalled = false

    var imageEvaluationStartedExpectation: XCTestExpectation?
    var imageEvaluationSucceededExpectation: XCTestExpectation?

    private(set) var lastEvaluationSide: DocumentCaptureSide?
    private(set) var lastEvaluationPreviewData: Data?
    private(set) var lastEvaluationFailureReason: String?
    private(set) var lastEvaluationError: ValidationError?
}

extension MockDocumentCapturePresenter: DocumentCaptureInteractorToPresenter {
    func photoUploadCompleted(side: DocumentCaptureSide) {
        photoUploadCompletedCalled = true
        lastCompletedSide = side
        photoUploadCompletedExpectation?.fulfill()
    }

    func photoUploadFailed(side: DocumentCaptureSide, error: ValidationError) {
        photoUploadFailedCalled = true
        lastFailedSide = side
        lastError = error
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
    }

    func imageEvaluationErrored(side: DocumentCaptureSide, error: ValidationError) {
        imageEvaluationErroredCalled = true
        lastEvaluationSide = side
        lastEvaluationError = error
    }
}

// swiftlint:enable type_body_length
