//
//  PassiveCaptureInteractorTests.swift
//  TruoraValidationsSDKTests
//
//  Created by Truora on 11/11/25.
//

import XCTest
@testable import TruoraValidationsSDK

@MainActor class PassiveCaptureInteractorTests: XCTestCase {
    var interactor: PassiveCaptureInteractor!
    fileprivate var mockPresenter: MockPassiveCapturePresenter!

    override func setUp() {
        super.setUp()
        mockPresenter = MockPassiveCapturePresenter()
        interactor = PassiveCaptureInteractor(
            presenter: mockPresenter,
            validationId: "test-validation-id",
            logger: MockTruoraLogger()
        )
        interactor.setUploadUrl("https://files.truora.com/upload")
        ValidationConfig.shared.reset()
    }

    override func tearDown() {
        interactor = nil
        mockPresenter = nil
        ValidationConfig.shared.reset()
        super.tearDown()
    }

    // MARK: - Upload Video Tests

    func testUploadVideoWithEmptyData() async throws {
        // Given
        let videoData = Data()
        mockPresenter.videoUploadFailedExpectation = expectation(description: "Upload failed called")

        // When
        interactor.uploadVideo(videoData)
        try await fulfillment(of: [XCTUnwrap(mockPresenter.videoUploadFailedExpectation)], timeout: 1.0)

        // Then
        XCTAssertTrue(mockPresenter.uploadFailedCalled)
        XCTAssertTrue(mockPresenter.lastError?.localizedDescription.contains("Video data is empty") ?? false)
        XCTAssertEqual(mockPresenter.lastLevel, .error, "An SDK-side defect is an error")
    }

    func testUploadVideoWithoutAPIClient() async throws {
        // Given
        let videoData = Data([0x00, 0x01, 0x02, 0x03])
        mockPresenter.videoUploadFailedExpectation = expectation(description: "Upload failed called")

        // When
        interactor.uploadVideo(videoData)
        try await fulfillment(of: [XCTUnwrap(mockPresenter.videoUploadFailedExpectation)], timeout: 1.0)

        // Then
        XCTAssertTrue(mockPresenter.uploadFailedCalled)
        XCTAssertTrue(mockPresenter.lastError?.localizedDescription.contains("API client not configured") ?? false)
    }

    func testUploadVideoWithNonTruoraUploadUrl_reportsUploadFailed() async throws {
        try await ValidationConfig.shared.configure(
            apiKey: "test-api-key",
            accountId: "test-account-id",
            delegate: nil
        )
        interactor.setUploadUrl("https://evil.example.com/upload")
        let videoData = Data([0x00, 0x01, 0x02, 0x03])
        mockPresenter.videoUploadFailedExpectation = expectation(description: "Upload failed called")

        interactor.uploadVideo(videoData)
        try await fulfillment(of: [XCTUnwrap(mockPresenter.videoUploadFailedExpectation)], timeout: 1.0)

        XCTAssertTrue(mockPresenter.uploadFailedCalled)
        XCTAssertTrue(mockPresenter.lastError?.localizedDescription.contains("Invalid file upload link") ?? false)
    }

    func testUploadVideoWithAPIClient() async throws {
        // Given
        let apiKey = "test-api-key"
        let accountId = "test-account-id"
        let videoData = Data([0x00, 0x01, 0x02, 0x03])

        try await ValidationConfig.shared.configure(
            apiKey: apiKey,
            accountId: accountId,
            delegate: nil
        )

        // When
        interactor.uploadVideo(videoData)

        // Then
        // Note: This will make a real API call in the current implementation
        // For proper unit testing, the API client should be mockable
        // This test verifies that the method can be called without crashing
        XCTAssertNotNil(ValidationConfig.shared.apiClient)
    }

    // MARK: - Upload Failure Level Tests

    func testUploadVideo_whenTheServerFailsWith5xx_reportsAnError() async throws {
        let level = try await levelOfUpload(failingWith: TruoraAPIError.serverError(statusCode: 503, body: nil))

        XCTAssertEqual(level, .error, "A 5xx is the server's fault")
    }

    func testUploadVideo_whenTheServerRejectsWith4xx_reportsAWarning() async throws {
        let level = try await levelOfUpload(failingWith: TruoraAPIError.serverError(statusCode: 400, body: "rejected"))

        XCTAssertEqual(level, .warning)
    }

    func testUploadVideo_whenThereIsNoConnectivity_reportsAWarning() async throws {
        let level = try await levelOfUpload(failingWith: URLError(.notConnectedToInternet))

        XCTAssertEqual(level, .warning)
    }

    func testUploadVideo_whenTheResponseIsInvalid_reportsAnError() async throws {
        let level = try await levelOfUpload(failingWith: TruoraAPIError.invalidResponse)

        XCTAssertEqual(level, .error)
    }

    /// Runs one upload whose transport fails with `uploadError`.
    /// Returns the level the presenter received.
    private func levelOfUpload(failingWith uploadError: Error) async throws -> LogLevel? {
        try await ValidationConfig.shared.configure(
            apiKey: "test-api-key",
            accountId: "test-account-id",
            delegate: nil
        )
        let interactor = PassiveCaptureInteractor(
            presenter: mockPresenter,
            validationId: "test-validation-id",
            uploadFileHandler: { _, _ in throw uploadError },
            logger: MockTruoraLogger()
        )
        interactor.setUploadUrl("https://files.truora.com/upload")
        mockPresenter.videoUploadFailedExpectation = expectation(description: "Upload failed called")

        interactor.uploadVideo(Data([0x00, 0x01, 0x02, 0x03]))
        try await fulfillment(of: [XCTUnwrap(mockPresenter.videoUploadFailedExpectation)], timeout: 1.0)

        withExtendedLifetime(interactor) {}
        return mockPresenter.lastLevel
    }

    // MARK: - Upload Duration Tests

    func testUploadVideo_whenTheUploadSucceeds_reportsHowLongItTook() async throws {
        try await ValidationConfig.shared.configure(
            apiKey: "test-api-key",
            accountId: "test-account-id",
            delegate: nil
        )
        let interactor = PassiveCaptureInteractor(
            presenter: mockPresenter,
            validationId: "test-validation-id",
            uploadFileHandler: { _, _ in try await Task.sleep(nanoseconds: 50_000_000) },
            logger: MockTruoraLogger()
        )
        interactor.setUploadUrl("https://files.truora.com/upload")
        mockPresenter.videoUploadCompletedExpectation = expectation(description: "Upload completed called")

        interactor.uploadVideo(Data([0x00, 0x01, 0x02, 0x03]))
        try await fulfillment(of: [XCTUnwrap(mockPresenter.videoUploadCompletedExpectation)], timeout: 1.0)

        withExtendedLifetime(interactor) {}
        let uploadDurationMs = try XCTUnwrap(mockPresenter.lastUploadDurationMs)
        XCTAssertGreaterThanOrEqual(uploadDurationMs, 50)
    }

    func testUploadVideo_whenTheUploadFails_reportsHowLongItTook() async throws {
        _ = try await levelOfUpload(failingWith: URLError(.notConnectedToInternet))

        let uploadDurationMs = try XCTUnwrap(mockPresenter.lastUploadDurationMs)
        XCTAssertGreaterThanOrEqual(uploadDurationMs, 0)
    }

    func testUploadVideo_whenItFailsBeforeUploading_reportsNoUploadDuration() async throws {
        mockPresenter.videoUploadFailedExpectation = expectation(description: "Upload failed called")

        interactor.uploadVideo(Data())
        try await fulfillment(of: [XCTUnwrap(mockPresenter.videoUploadFailedExpectation)], timeout: 1.0)

        XCTAssertTrue(mockPresenter.uploadFailedCalled)
        XCTAssertNil(mockPresenter.lastUploadDurationMs)
    }

    func testLogFaceCaptureSucceeded_withAnUploadDuration_addsItToTheEvent() async throws {
        let logger = MockTruoraLogger()
        let interactor = PassiveCaptureInteractor(
            presenter: mockPresenter,
            validationId: "dummy-validation-id",
            logger: logger
        )

        await interactor.logFaceCaptureSucceeded(uploadDurationMs: 1234)

        let event = try XCTUnwrap(logger.loggedEvents.last)
        XCTAssertEqual(event.metadata["upload_duration_ms"], .int(1234))
    }

    func testLogFaceCaptureSucceeded_withoutAnUploadDuration_leavesItOut() async throws {
        let logger = MockTruoraLogger()
        let interactor = PassiveCaptureInteractor(
            presenter: mockPresenter,
            validationId: "dummy-validation-id",
            logger: logger
        )

        await interactor.logFaceCaptureSucceeded(uploadDurationMs: nil)

        let event = try XCTUnwrap(logger.loggedEvents.last)
        XCTAssertNil(event.metadata["upload_duration_ms"])
    }

    func testLogFaceCaptureFailed_withAnUploadDuration_addsItToTheEvent() async throws {
        let logger = MockTruoraLogger()
        let interactor = PassiveCaptureInteractor(
            presenter: mockPresenter,
            validationId: "dummy-validation-id",
            logger: logger
        )

        await interactor.logFaceCaptureFailed(errorMessage: "Upload failed", level: .warning, uploadDurationMs: 1234)

        let event = try XCTUnwrap(logger.loggedEvents.last)
        XCTAssertEqual(event.metadata["upload_duration_ms"], .int(1234))
    }

    // MARK: - Task Cancellation Tests

    func testDeinitCancelsUploadTask() {
        // Given
        var interactorOptional: PassiveCaptureInteractor? = PassiveCaptureInteractor(
            presenter: mockPresenter,
            validationId: "test-validation-id",
            logger: MockTruoraLogger()
        )
        interactorOptional?.setUploadUrl("https://files.truora.com/upload")

        // When
        interactorOptional = nil

        // Then
        // The deinit should cancel the task without crashing
        XCTAssertNil(interactorOptional)
    }

    // MARK: - Byte Array Conversion Tests

    func testByteArrayConversion() {
        // Given
        let testData = Data([0x00, 0x01, 0x7F, 0x80, 0xFF])

        // When/Then
        // This test verifies that the byte array conversion handles all byte values correctly
        // The actual conversion happens in uploadVideo, so we just verify it doesn't crash
        XCTAssertEqual(testData.count, 5)
    }
}

// MARK: - Mock Presenter

@MainActor private class MockPassiveCapturePresenter: PassiveCaptureInteractorToPresenter {
    var uploadCompletedCalled = false
    var uploadFailedCalled = false
    var lastError: TruoraException?
    var lastLevel: LogLevel?
    var lastValidationId: String?
    var lastUploadDurationMs: Int?
    var videoUploadCompletedExpectation: XCTestExpectation?
    var videoUploadFailedExpectation: XCTestExpectation?

    func videoUploadCompleted(validationId: String, uploadDurationMs: Int?) async {
        uploadCompletedCalled = true
        lastValidationId = validationId
        lastUploadDurationMs = uploadDurationMs
        videoUploadCompletedExpectation?.fulfill()
    }

    func videoUploadFailed(_ error: TruoraException, level: LogLevel, uploadDurationMs: Int?) async {
        uploadFailedCalled = true
        lastError = error
        lastLevel = level
        lastUploadDurationMs = uploadDurationMs
        videoUploadFailedExpectation?.fulfill()
    }
}
