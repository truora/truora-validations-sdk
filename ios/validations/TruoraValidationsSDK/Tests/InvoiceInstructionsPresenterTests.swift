//
//  InvoiceInstructionsPresenterTests.swift
//  TruoraValidationsSDKTests
//
//  Created by Truora on 22/04/26.
//

import XCTest
@testable import TruoraValidationsSDK

// swiftlint:disable file_length type_body_length
@MainActor final class InvoiceInstructionsPresenterTests: XCTestCase {
    private var sut: InvoiceInstructionsPresenter!
    private var mockView: MockInvoiceInstructionsView!
    private var mockInteractor: MockInvoiceInstructionsInteractor!
    private var mockRouter: MockInvoiceRouter!

    override func setUp() {
        super.setUp()
        ValidationConfig.shared.reset()
        mockView = MockInvoiceInstructionsView()
        mockInteractor = MockInvoiceInstructionsInteractor()
        mockRouter = MockInvoiceRouter(navigationController: TruoraNavigationController())
        sut = InvoiceInstructionsPresenter(
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
        ValidationConfig.shared.reset()
        super.tearDown()
    }

    // MARK: - viewDidLoad

    func testViewDidLoad_firstCall_logsAndCreatesValidation() async throws {
        try await ValidationConfig.shared.configure(apiKey: "k", accountId: "acc-1")

        await sut.viewDidLoad()

        XCTAssertEqual(mockInteractor.logViewRenderedCount, 1)
        XCTAssertEqual(mockInteractor.createValidationCallCount, 1)
        XCTAssertEqual(mockInteractor.lastCreateAccountId, "acc-1")
        XCTAssertNil(mockInteractor.lastCreateRetryOfId)
        XCTAssertTrue(mockView.showLoadingCalled)
    }

    func testViewDidLoad_secondCall_noPendingRetry_doesNotRecreate() async throws {
        // Given — first call succeeds and sets uploadUrl via validationCreated
        try await ValidationConfig.shared.configure(apiKey: "k", accountId: "acc-1")
        await sut.viewDidLoad()
        await sut.validationCreated(
            response: Self.response(frontUrl: "https://example.com/upload", validationId: "VLD-1")
        )

        // When — second viewDidLoad with no retry queued
        await sut.viewDidLoad()

        // Then — createValidation stays at 1
        XCTAssertEqual(mockInteractor.createValidationCallCount, 1)
    }

    func testViewDidLoad_secondCall_stillLogsViewRendered() async throws {
        try await ValidationConfig.shared.configure(apiKey: "k", accountId: "acc-1")
        await sut.viewDidLoad()
        await sut.validationCreated(
            response: Self.response(frontUrl: "https://example.com/upload", validationId: "VLD-1")
        )

        await sut.viewDidLoad()

        XCTAssertEqual(mockInteractor.logViewRenderedCount, 2, "Telemetry should fire on every appearance")
    }

    func testViewDidLoad_withPendingRetryId_clearsStateAndCreatesWithRetryOfId() async throws {
        // Given — first call succeeds, then the router is flagged for retry
        try await ValidationConfig.shared.configure(apiKey: "k", accountId: "acc-1")
        await sut.viewDidLoad()
        await sut.validationCreated(
            response: Self.response(frontUrl: "https://example.com/upload", validationId: "VLD-1")
        )
        mockRouter.pendingInvoiceRetryValidationId = "VLD-old"

        // When
        await sut.viewDidLoad()

        // Then
        XCTAssertEqual(mockInteractor.createValidationCallCount, 2)
        XCTAssertEqual(mockInteractor.lastCreateRetryOfId, "VLD-old")
        XCTAssertNil(mockRouter.pendingInvoiceRetryValidationId, "pending retry id must be consumed")

        // And the stale upload URL must be cleared so `fileSelected` can't upload against it
        await sut.fileSelected(data: Data([0x01]), contentType: "image/jpeg")
        XCTAssertTrue(mockView.showErrorCalled)
        XCTAssertEqual(mockView.lastErrorMessage, "Missing upload URL")
    }

    func testViewDidLoad_missingAccountId_showsError() async {
        // No configure() call — accountId is nil
        await sut.viewDidLoad()

        XCTAssertTrue(mockView.showErrorCalled)
        XCTAssertEqual(mockView.lastErrorMessage, "Missing account ID")
        XCTAssertEqual(mockInteractor.createValidationCallCount, 0)
    }

    func testViewDidLoad_missingInteractor_showsError() async throws {
        try await ValidationConfig.shared.configure(apiKey: "k", accountId: "acc-1")
        // Explicitly drop the interactor
        sut = InvoiceInstructionsPresenter(view: mockView, interactor: nil, router: mockRouter)

        await sut.viewDidLoad()

        XCTAssertTrue(mockView.showErrorCalled)
        XCTAssertEqual(mockView.lastErrorMessage, "Interactor not configured")
    }

    // MARK: - Actions

    func testUploadFileTapped_callsRouterPresentFilePicker_andLogs() async {
        await sut.uploadFileTapped()

        XCTAssertEqual(mockInteractor.logUploadFileClickedCount, 1)
        XCTAssertTrue(mockRouter.presentInvoiceFilePickerCalled)
    }

    func testTakePhotoTapped_callsRouterPresentCamera_andLogs() async {
        await sut.takePhotoTapped()

        XCTAssertEqual(mockInteractor.logTakePhotoClickedCount, 1)
        XCTAssertTrue(mockRouter.presentInvoiceCameraCalled)
    }

    func testCancelTapped_callsHandleCancellation() async {
        await sut.cancelTapped()

        XCTAssertEqual(mockInteractor.logCancelClickedCount, 1)
        XCTAssertTrue(mockRouter.handleCancellationCalled)
        XCTAssertEqual(mockRouter.handleCancellationLastLoadingType, .invoice)
    }

    // MARK: - fileSelected

    func testFileSelected_happyPath_uploadsSetsCapturedDataAndNavigatesToResult() async throws {
        try await ValidationConfig.shared.configure(apiKey: "k", accountId: "acc-1")
        await sut.viewDidLoad()
        await sut.validationCreated(
            response: Self.response(frontUrl: "https://example.com/upload", validationId: "VLD-1")
        )

        let jpg = Data([0xFF, 0xD8])
        await sut.fileSelected(data: jpg, contentType: "image/jpeg")

        XCTAssertEqual(mockInteractor.uploadFileCallCount, 1)
        XCTAssertEqual(mockInteractor.lastUploadUrl, "https://example.com/upload")
        XCTAssertEqual(mockRouter.invoiceCapturedImageData, jpg, "JPEG raw bytes stored for preview")
        XCTAssertTrue(mockRouter.navigateToResultCalled)
        XCTAssertEqual(mockRouter.navigateToResultLoadingType, .invoice)
        XCTAssertEqual(mockRouter.navigateToResultValidationId, "VLD-1")
    }

    func testFileSelected_pdfFile_storesRasterizedPreview() async throws {
        try await ValidationConfig.shared.configure(apiKey: "k", accountId: "acc-1")
        await sut.viewDidLoad()
        await sut.validationCreated(
            response: Self.response(frontUrl: "https://example.com/upload", validationId: "VLD-1")
        )

        let pdf = InvoicePreviewGeneratorTests.makeTestPDF(pageCount: 1)
        await sut.fileSelected(data: pdf, contentType: "application/pdf")

        XCTAssertNotNil(mockRouter.invoiceCapturedImageData)
        XCTAssertNotEqual(
            mockRouter.invoiceCapturedImageData,
            pdf,
            "PDF must be rasterized, not stored raw"
        )
    }

    func testFileSelected_jpgFile_storesRawData() async throws {
        try await ValidationConfig.shared.configure(apiKey: "k", accountId: "acc-1")
        await sut.viewDidLoad()
        await sut.validationCreated(
            response: Self.response(frontUrl: "https://example.com/upload", validationId: "VLD-1")
        )

        let jpg = Data([0xFF, 0xD8, 0xFF, 0xE0])
        await sut.fileSelected(data: jpg, contentType: "image/jpeg")

        XCTAssertEqual(mockRouter.invoiceCapturedImageData, jpg)
    }

    func testFileSelected_missingUploadUrl_showsError() async {
        await sut.fileSelected(data: Data([0x01]), contentType: "image/jpeg")

        XCTAssertTrue(mockView.showErrorCalled)
        XCTAssertEqual(mockView.lastErrorMessage, "Missing upload URL")
        XCTAssertEqual(mockInteractor.uploadFileCallCount, 0)
    }

    func testFileSelected_expiredUploadUrl_showsExpiredError() async {
        // Given — upload URL whose `Expires` query param is in the past
        let expiredUrl = "https://example.com/upload?Expires=1000000000"
        await sut.validationCreated(
            response: Self.response(frontUrl: expiredUrl, validationId: "VLD-1")
        )

        // When
        await sut.fileSelected(data: Data([0x01]), contentType: "image/jpeg")

        // Then
        XCTAssertTrue(mockView.showErrorCalled)
        XCTAssertEqual(mockView.lastErrorMessage, "Validation expired. The time limit was exceeded.")
        XCTAssertEqual(mockInteractor.uploadFileCallCount, 0)
    }

    func testFileSelected_missingInteractor_showsError() async {
        // Given — presenter configured with nil interactor
        sut = InvoiceInstructionsPresenter(view: mockView, interactor: nil, router: mockRouter)
        await sut.validationCreated(
            response: Self.response(frontUrl: "https://example.com/upload", validationId: "VLD-1")
        )

        // When
        await sut.fileSelected(data: Data([0x01]), contentType: "image/jpeg")

        // Then
        XCTAssertTrue(mockView.showErrorCalled)
        XCTAssertEqual(mockView.lastErrorMessage, "Interactor not configured")
    }

    func testFileSelected_missingRouter_showsError() async {
        // Given — router released
        await sut.validationCreated(
            response: Self.response(frontUrl: "https://example.com/upload", validationId: "VLD-1")
        )
        sut.router = nil

        // When
        await sut.fileSelected(data: Data([0x01]), contentType: "image/jpeg")

        // Then
        XCTAssertTrue(mockView.showErrorCalled)
        XCTAssertEqual(mockView.lastErrorMessage, "Missing router or validation ID")
    }

    func testFileSelected_navigateFails_showsErrorDescription() async throws {
        try await ValidationConfig.shared.configure(apiKey: "k", accountId: "acc-1")
        await sut.viewDidLoad()
        await sut.validationCreated(
            response: Self.response(frontUrl: "https://example.com/upload", validationId: "VLD-1")
        )
        mockRouter.navigateToResultShouldThrow = TruoraException.sdk(
            SDKError(type: .internalError, details: "boom")
        )

        await sut.fileSelected(data: Data([0x01]), contentType: "image/jpeg")

        XCTAssertTrue(mockView.showErrorCalled)
        XCTAssertTrue(mockView.lastErrorMessage?.contains("boom") ?? false)
    }

    // MARK: - Interactor callbacks

    func testValidationCreated_withValidFrontUrl_storesUrlAndId_hidesLoading() async {
        // When
        await sut.validationCreated(
            response: Self.response(frontUrl: "https://example.com/upload", validationId: "VLD-1")
        )

        // Then — hides loading, no error. The stored URL/id are verified indirectly via fileSelected
        XCTAssertTrue(mockView.hideLoadingCalled)
        XCTAssertFalse(mockView.showErrorCalled)

        // Selecting a file should now succeed (no missing-URL error)
        await sut.fileSelected(data: Data([0x01]), contentType: "image/jpeg")
        XCTAssertEqual(mockInteractor.lastUploadUrl, "https://example.com/upload")
    }

    func testValidationCreated_missingFrontUrl_hidesLoadingAndShowsError() async {
        await sut.validationCreated(response: Self.response(frontUrl: nil, validationId: "VLD-1"))

        XCTAssertTrue(mockView.hideLoadingCalled)
        XCTAssertTrue(mockView.showErrorCalled)
        XCTAssertEqual(mockView.lastErrorMessage, "Missing upload URL")
    }

    func testValidationFailed_callsHandleError_hidesLoading() async {
        let error = TruoraException.network(message: "down", underlyingError: nil)

        await sut.validationFailed(error)

        XCTAssertTrue(mockView.hideLoadingCalled)
        XCTAssertTrue(mockRouter.handleErrorCalled)
    }

    func testFileUploadCompleted_noOp() async {
        await sut.fileUploadCompleted()
        // Verifies no crash — there's no observable side effect by design.
        XCTAssertFalse(mockView.showErrorCalled)
    }

    func testFileUploadFailed_popsToInstructions_thenShowsError() async {
        await sut.fileUploadFailed(.network(message: "upload-down", underlyingError: nil))

        XCTAssertTrue(mockRouter.popToInvoiceInstructionsCalled)
        XCTAssertTrue(mockView.showErrorCalled)
        XCTAssertTrue(mockView.lastErrorMessage?.contains("upload-down") ?? false)
    }

    // MARK: - Picker callbacks

    func testPickerCancelled_logsEvent() async {
        await sut.pickerCancelled()

        XCTAssertEqual(mockInteractor.logPickerCancelledCount, 1)
    }

    func testFileSelectionFailed_showsMessageError() async {
        await sut.fileSelectionFailed(message: "too big")

        XCTAssertTrue(mockView.showErrorCalled)
        XCTAssertEqual(mockView.lastErrorMessage, "too big")
    }

    // MARK: - Helpers

    private static func response(
        frontUrl: String?,
        validationId: String
    ) -> NativeValidationCreateResponse {
        NativeValidationCreateResponse(
            validationId: validationId,
            instructions: NativeValidationInstructions(
                fileUploadLink: nil,
                frontUrl: frontUrl,
                reverseUrl: nil
            )
        )
    }
}

// MARK: - Mock View

@MainActor private final class MockInvoiceInstructionsView: InvoiceInstructionsPresenterToView {
    private(set) var showLoadingCalled = false
    private(set) var hideLoadingCalled = false
    private(set) var showErrorCalled = false
    private(set) var lastErrorMessage: String?

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

@MainActor private final class MockInvoiceInstructionsInteractor: InvoiceInstructionsPresenterToInteractor {
    private(set) var createValidationCallCount = 0
    private(set) var lastCreateAccountId: String?
    private(set) var lastCreateRetryOfId: String?
    private(set) var uploadFileCallCount = 0
    private(set) var lastUploadUrl: String?
    private(set) var logViewRenderedCount = 0
    private(set) var logUploadFileClickedCount = 0
    private(set) var logTakePhotoClickedCount = 0
    private(set) var logCancelClickedCount = 0
    private(set) var logPickerCancelledCount = 0

    func createValidation(accountId: String, retryOfId: String?) {
        createValidationCallCount += 1
        lastCreateAccountId = accountId
        lastCreateRetryOfId = retryOfId
    }

    func uploadFile(uploadUrl: String, fileData: Data, contentType: String) {
        uploadFileCallCount += 1
        lastUploadUrl = uploadUrl
    }

    func logViewRendered() async {
        logViewRenderedCount += 1
    }

    func logUploadFileButtonClicked() async {
        logUploadFileClickedCount += 1
    }

    func logTakePhotoButtonClicked() async {
        logTakePhotoClickedCount += 1
    }

    func logCancelButtonClicked() async {
        logCancelClickedCount += 1
    }

    func logPickerCancelled() async {
        logPickerCancelledCount += 1
    }
}

// MARK: - Mock Router

@MainActor private final class MockInvoiceRouter: ValidationRouter {
    var navigateToResultCalled = false
    var navigateToResultLoadingType: ResultLoadingType?
    var navigateToResultValidationId: String?
    var navigateToResultShouldThrow: Error?

    var presentInvoiceFilePickerCalled = false
    var presentInvoiceCameraCalled = false
    var handleCancellationCalled = false
    var handleCancellationLastLoadingType: ResultLoadingType?
    var handleErrorCalled = false
    var popToInvoiceInstructionsCalled = false

    override func navigateToResult(
        validationId: String,
        loadingType: ResultLoadingType = .face,
        isCanceled: Bool = false
    ) throws {
        navigateToResultCalled = true
        navigateToResultLoadingType = loadingType
        navigateToResultValidationId = validationId
        if let navigateToResultShouldThrow { throw navigateToResultShouldThrow }
    }

    override func presentInvoiceFilePicker(presenter: InvoiceInstructionsViewToPresenter) {
        presentInvoiceFilePickerCalled = true
    }

    override func presentInvoiceCamera(presenter: InvoiceInstructionsViewToPresenter) {
        presentInvoiceCameraCalled = true
    }

    override func handleCancellation(loadingType: ResultLoadingType) {
        handleCancellationCalled = true
        handleCancellationLastLoadingType = loadingType
    }

    override func handleError(_ error: TruoraException) {
        handleErrorCalled = true
    }

    override func popToInvoiceInstructions() async {
        popToInvoiceInstructionsCalled = true
    }
}

// swiftlint:enable file_length type_body_length
