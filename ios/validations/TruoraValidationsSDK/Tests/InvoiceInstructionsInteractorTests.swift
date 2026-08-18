//
//  InvoiceInstructionsInteractorTests.swift
//  TruoraValidationsSDKTests
//
//  Created by Truora on 22/04/26.
//

import XCTest
@testable import TruoraValidationsSDK

// swiftlint:disable file_length type_body_length
@MainActor final class InvoiceInstructionsInteractorTests: XCTestCase {
    private var mockPresenter: MockInvoiceInstructionsPresenter!
    private var mockLogger: MockTruoraLogger!

    override func setUp() {
        super.setUp()
        ValidationConfig.shared.reset()
        mockPresenter = MockInvoiceInstructionsPresenter()
        mockLogger = MockTruoraLogger()
    }

    override func tearDown() {
        mockPresenter = nil
        mockLogger = nil
        ValidationConfig.shared.reset()
        super.tearDown()
    }

    // MARK: - createValidation

    func testCreateValidation_withoutRetryOfId_buildsRequestWithNilRetryOfId() async {
        // Given
        var captured: NativeValidationRequest?
        let expectation = expectation(description: "validationCreated")
        mockPresenter.onValidationCreated = { expectation.fulfill() }
        let sut = makeSUT(country: "MX", createHandler: { request in
            captured = request
            return Self.mockCreateResponse()
        })

        // When
        sut.createValidation(accountId: "acc-1", retryOfId: nil)
        await fulfillment(of: [expectation], timeout: 1.0)

        // Then
        XCTAssertNil(captured?.retryOfId)
    }

    func testCreateValidation_withRetryOfId_buildsRequestWithThatId() async {
        // Given
        var captured: NativeValidationRequest?
        let expectation = expectation(description: "validationCreated")
        mockPresenter.onValidationCreated = { expectation.fulfill() }
        let sut = makeSUT(country: "MX", createHandler: { request in
            captured = request
            return Self.mockCreateResponse()
        })

        // When
        sut.createValidation(accountId: "acc-1", retryOfId: "VLD-abc")
        await fulfillment(of: [expectation], timeout: 1.0)

        // Then
        XCTAssertEqual(captured?.retryOfId, "VLD-abc")
    }

    func testCreateValidation_buildRequestContents() async {
        // Given
        ValidationConfig.shared.invoiceConfig.setTimeout(42)
        var captured: NativeValidationRequest?
        let expectation = expectation(description: "validationCreated")
        mockPresenter.onValidationCreated = { expectation.fulfill() }
        let sut = makeSUT(country: "MX", createHandler: { request in
            captured = request
            return Self.mockCreateResponse()
        })

        // When
        sut.createValidation(accountId: "acc-1", retryOfId: nil)
        await fulfillment(of: [expectation], timeout: 1.0)

        // Then
        XCTAssertEqual(captured?.type, "document-validation")
        XCTAssertEqual(captured?.documentType, "invoice")
        XCTAssertEqual(captured?.country, "mx", "country should be lowercased")
        XCTAssertEqual(captured?.accountId, "acc-1")
        XCTAssertTrue(captured?.userAuthorized ?? false)
        XCTAssertTrue(captured?.checkManualReviewAvailability ?? false)
        XCTAssertEqual(captured?.timeout, 42)
    }

    func testCreateValidation_onSuccess_notifiesPresenter() async {
        // Given
        let response = Self.mockCreateResponse(validationId: "VLD-success")
        let expectation = expectation(description: "validationCreated")
        mockPresenter.onValidationCreated = { expectation.fulfill() }
        let sut = makeSUT(country: "MX", createHandler: { _ in response })

        // When
        sut.createValidation(accountId: "acc-1", retryOfId: nil)
        await fulfillment(of: [expectation], timeout: 1.0)

        // Then
        XCTAssertTrue(mockPresenter.validationCreatedCalled)
        XCTAssertEqual(mockPresenter.lastResponse?.validationId, "VLD-success")
    }

    func testCreateValidation_onFailure_notifiesPresenterWithTruoraException() async {
        // Given
        let expectation = expectation(description: "validationFailed")
        mockPresenter.onValidationFailed = { expectation.fulfill() }
        let underlying = TruoraException.sdk(SDKError(type: .invalidConfiguration, details: "nope"))
        let sut = makeSUT(country: "MX", createHandler: { _ in throw underlying })

        // When
        sut.createValidation(accountId: "acc-1", retryOfId: nil)
        await fulfillment(of: [expectation], timeout: 1.0)

        // Then
        XCTAssertTrue(mockPresenter.validationFailedCalled)
        if case .sdk(let err) = mockPresenter.lastError {
            XCTAssertEqual(err.type, .invalidConfiguration)
        } else {
            XCTFail("Expected TruoraException.sdk to pass through unchanged")
        }
    }

    func testCreateValidation_onNetworkError_wrapsAsTruoraException() async {
        // Given
        let expectation = expectation(description: "validationFailed")
        mockPresenter.onValidationFailed = { expectation.fulfill() }
        struct PlainError: LocalizedError {
            var errorDescription: String? {
                "plain"
            }
        }
        let sut = makeSUT(country: "MX", createHandler: { _ in throw PlainError() })

        // When
        sut.createValidation(accountId: "acc-1", retryOfId: nil)
        await fulfillment(of: [expectation], timeout: 1.0)

        // Then
        guard case .network(let message, _) = mockPresenter.lastError else {
            XCTFail("Expected .network exception wrapping plain error")
            return
        }
        XCTAssertTrue(message.contains("plain"))
    }

    func testCreateValidation_twoCallsInARow_cancelsFirst() async {
        // Given — first handler suspends until signaled; second returns immediately
        let firstStarted = expectation(description: "first handler started")
        let firstCancelled = expectation(description: "first handler cancelled")
        let secondCompleted = expectation(description: "second completed")
        mockPresenter.onValidationCreated = { secondCompleted.fulfill() }

        actor Counter { var value = 0
            func bump() {
                value += 1
            }
        }
        let calls = Counter()

        let sut = makeSUT(country: "MX", createHandler: { request in
            await calls.bump()
            if request.retryOfId == "first" {
                firstStarted.fulfill()
                do {
                    try await Task.sleep(nanoseconds: 2_000_000_000)
                } catch {
                    firstCancelled.fulfill()
                    throw CancellationError()
                }
                return Self.mockCreateResponse(validationId: "first-done")
            } else {
                return Self.mockCreateResponse(validationId: "second-done")
            }
        })

        // When — start first (blocks), then start second which should cancel the first
        sut.createValidation(accountId: "acc-1", retryOfId: "first")
        await fulfillment(of: [firstStarted], timeout: 1.0)
        sut.createValidation(accountId: "acc-1", retryOfId: nil)
        await fulfillment(of: [firstCancelled, secondCompleted], timeout: 2.0)

        // Then — only the second call should have notified the presenter
        XCTAssertEqual(mockPresenter.validationCreatedCallCount, 1)
        XCTAssertEqual(mockPresenter.lastResponse?.validationId, "second-done")
    }

    // MARK: - uploadFile

    func testUploadFile_onSuccess_notifiesFileUploadCompleted() async {
        // Given
        let expectation = expectation(description: "fileUploadCompleted")
        mockPresenter.onFileUploadCompleted = { expectation.fulfill() }
        let sut = makeSUT(
            country: "MX",
            uploadHandler: { _, _ in /* success */ }
        )

        // When
        sut.uploadFile(uploadUrl: "https://example.com/u", fileData: Data([0x01]), contentType: "image/jpeg")
        await fulfillment(of: [expectation], timeout: 1.0)

        // Then
        XCTAssertTrue(mockPresenter.fileUploadCompletedCalled)
        XCTAssertFalse(mockPresenter.fileUploadFailedCalled)
    }

    func testUploadFile_onFailure_notifiesFileUploadFailedWithWrappedError() async {
        // Given
        let expectation = expectation(description: "fileUploadFailed")
        mockPresenter.onFileUploadFailed = { expectation.fulfill() }
        struct FileError: LocalizedError { var errorDescription: String? {
            "disk"
        } }
        let sut = makeSUT(
            country: "MX",
            uploadHandler: { _, _ in throw FileError() }
        )

        // When
        sut.uploadFile(uploadUrl: "https://example.com/u", fileData: Data([0x01]), contentType: "image/jpeg")
        await fulfillment(of: [expectation], timeout: 1.0)

        // Then
        guard case .sdk(let err) = mockPresenter.lastUploadError else {
            XCTFail("Expected .sdk exception wrapping plain error")
            return
        }
        XCTAssertEqual(err.type, .uploadFailed)
        XCTAssertEqual(err.details, "disk")
    }

    func testUploadFile_onFailureWithTruoraException_passesThroughUnwrapped() async {
        // Given
        let expectation = expectation(description: "fileUploadFailed")
        mockPresenter.onFileUploadFailed = { expectation.fulfill() }
        let original = TruoraException.network(message: "net-down", underlyingError: nil)
        let sut = makeSUT(
            country: "MX",
            uploadHandler: { _, _ in throw original }
        )

        // When
        sut.uploadFile(uploadUrl: "https://example.com/u", fileData: Data([0x01]), contentType: "image/jpeg")
        await fulfillment(of: [expectation], timeout: 1.0)

        // Then
        guard case .network(let message, _) = mockPresenter.lastUploadError else {
            XCTFail("Expected .network to pass through unchanged")
            return
        }
        XCTAssertEqual(message, "net-down")
    }

    func testUploadFile_cancelTaskOnNewCall() async {
        // Given — first upload suspends, second completes quickly
        let firstStarted = expectation(description: "first upload started")
        let firstCancelled = expectation(description: "first upload cancelled")
        let secondCompleted = expectation(description: "second upload completed")
        mockPresenter.onFileUploadCompleted = { secondCompleted.fulfill() }

        let sut = makeSUT(
            country: "MX",
            uploadHandler: { uploadUrl, _ in
                if uploadUrl == "first" {
                    firstStarted.fulfill()
                    do {
                        try await Task.sleep(nanoseconds: 2_000_000_000)
                    } catch {
                        firstCancelled.fulfill()
                        throw CancellationError()
                    }
                }
                // Second upload returns immediately
            }
        )

        // When
        sut.uploadFile(uploadUrl: "first", fileData: Data(), contentType: "image/jpeg")
        await fulfillment(of: [firstStarted], timeout: 1.0)
        sut.uploadFile(uploadUrl: "second", fileData: Data(), contentType: "image/jpeg")
        await fulfillment(of: [firstCancelled, secondCompleted], timeout: 2.0)

        // Then — only the second upload should have notified the presenter
        XCTAssertEqual(mockPresenter.fileUploadCompletedCallCount, 1)
        XCTAssertFalse(mockPresenter.fileUploadFailedCalled)
    }

    // MARK: - Logging

    func testLogViewRendered_emitsCorrectMetadata() async {
        // Given
        let sut = makeSUT(country: "MX")

        // When
        await sut.logViewRendered()

        // Then
        let events = mockLogger.loggedEvents
        XCTAssertEqual(events.count, 1)
        let event = events.first
        // SDKEvent truncates eventName to 35 chars, so compare against the truncated form
        XCTAssertEqual(event?.eventName, String("view_render_invoice_instructions_succeeded".prefix(35)))
        XCTAssertEqual(event?.eventType, .view)
        XCTAssertEqual(metadataString(event, "name"), "invoice_instructions")
        XCTAssertEqual(metadataString(event, "validation_type"), "document_validation")
    }

    func testLogUploadFileButtonClicked_emitsCorrectMetadata() async {
        // Given
        let sut = makeSUT(country: "MX")

        // When
        await sut.logUploadFileButtonClicked()

        // Then
        let event = mockLogger.loggedEvents.first
        XCTAssertEqual(event?.eventName, "view_upload_file_button_clicked")
        XCTAssertEqual(metadataString(event, "name"), "invoice_instructions")
        XCTAssertEqual(metadataString(event, "validation_type"), "document_validation")
        XCTAssertEqual(metadataString(event, "selected_country"), "MX")
        XCTAssertEqual(metadataString(event, "input_method"), "file_upload")
    }

    func testLogTakePhotoButtonClicked_emitsCorrectMetadata() async {
        // Given
        let sut = makeSUT(country: "MX")

        // When
        await sut.logTakePhotoButtonClicked()

        // Then
        let event = mockLogger.loggedEvents.first
        XCTAssertEqual(event?.eventName, "view_take_photo_button_clicked")
        XCTAssertEqual(metadataString(event, "input_method"), "camera")
        XCTAssertEqual(metadataString(event, "selected_country"), "MX")
    }

    func testLogCancelButtonClicked_emitsCorrectMetadata() async {
        // Given
        let sut = makeSUT(country: "MX")

        // When
        await sut.logCancelButtonClicked()

        // Then
        let event = mockLogger.loggedEvents.first
        XCTAssertEqual(event?.eventName, "view_cancel_button_clicked")
        XCTAssertEqual(metadataString(event, "name"), "invoice_instructions")
        XCTAssertEqual(metadataString(event, "validation_type"), "document_validation")
    }

    func testLogPickerCancelled_emitsCorrectMetadata() async {
        // Given
        let sut = makeSUT(country: "MX")

        // When
        await sut.logPickerCancelled()

        // Then
        let event = mockLogger.loggedEvents.first
        XCTAssertEqual(event?.eventName, "view_picker_cancelled")
        XCTAssertEqual(metadataString(event, "name"), "invoice_instructions")
    }

    // MARK: - Helpers

    private func makeSUT(
        country: String,
        createHandler: ((NativeValidationRequest) async throws -> NativeValidationCreateResponse)? = nil,
        uploadHandler: ((String, Data) async throws -> Void)? = nil
    ) -> InvoiceInstructionsInteractor {
        InvoiceInstructionsInteractor(
            presenter: mockPresenter,
            country: country,
            createValidationHandler: createHandler,
            uploadFileHandler: uploadHandler,
            logger: mockLogger
        )
    }

    private static func mockCreateResponse(
        validationId: String = "VLD-1"
    ) -> NativeValidationCreateResponse {
        NativeValidationCreateResponse(
            validationId: validationId,
            instructions: NativeValidationInstructions(
                fileUploadLink: nil,
                frontUrl: "https://example.com/upload",
                reverseUrl: nil
            )
        )
    }

    private func metadataString(_ event: SDKEvent?, _ key: String) -> String? {
        guard let value = event?.metadata[key] else { return nil }
        if case .string(let str) = value {
            return str
        }
        return nil
    }
}

// MARK: - Mock Presenter

@MainActor private final class MockInvoiceInstructionsPresenter: InvoiceInstructionsInteractorToPresenter {
    private(set) var validationCreatedCalled = false
    private(set) var validationCreatedCallCount = 0
    private(set) var validationFailedCalled = false
    private(set) var fileUploadCompletedCalled = false
    private(set) var fileUploadCompletedCallCount = 0
    private(set) var fileUploadFailedCalled = false
    private(set) var lastResponse: NativeValidationCreateResponse?
    private(set) var lastError: TruoraException?
    private(set) var lastUploadError: TruoraException?

    var onValidationCreated: (() -> Void)?
    var onValidationFailed: (() -> Void)?
    var onFileUploadCompleted: (() -> Void)?
    var onFileUploadFailed: (() -> Void)?

    func validationCreated(response: NativeValidationCreateResponse) async {
        validationCreatedCalled = true
        validationCreatedCallCount += 1
        lastResponse = response
        onValidationCreated?()
    }

    func validationFailed(_ error: TruoraException) async {
        validationFailedCalled = true
        lastError = error
        onValidationFailed?()
    }

    func fileUploadCompleted() async {
        fileUploadCompletedCalled = true
        fileUploadCompletedCallCount += 1
        onFileUploadCompleted?()
    }

    func fileUploadFailed(_ error: TruoraException) async {
        fileUploadFailedCalled = true
        lastUploadError = error
        onFileUploadFailed?()
    }
}

// swiftlint:enable file_length type_body_length
