//
//  InvoiceInstructionsViewModelTests.swift
//  TruoraValidationsSDKTests
//
//  Created by Truora on 22/04/26.
//

import XCTest
@testable import TruoraValidationsSDK

@MainActor final class InvoiceInstructionsViewModelTests: XCTestCase {
    private var sut: InvoiceInstructionsViewModel!
    private var mockPresenter: MockInvoiceInstructionsViewToPresenter!

    override func setUp() {
        super.setUp()
        sut = InvoiceInstructionsViewModel()
        mockPresenter = MockInvoiceInstructionsViewToPresenter()
        sut.presenter = mockPresenter
    }

    override func tearDown() {
        sut = nil
        mockPresenter = nil
        super.tearDown()
    }

    // MARK: - onAppear

    func testOnAppear_callsPresenterViewDidLoad() async {
        // When
        sut.onAppear()
        await mockPresenter.waitForViewDidLoad(count: 1)

        // Then
        XCTAssertEqual(mockPresenter.viewDidLoadCount, 1)
    }

    func testOnAppear_firesEveryCall() async {
        // When
        sut.onAppear()
        sut.onAppear()
        sut.onAppear()
        await mockPresenter.waitForViewDidLoad(count: 3)

        // Then
        XCTAssertEqual(mockPresenter.viewDidLoadCount, 3, "onAppear has no guard — every call should fire")
    }

    // MARK: - Presenter-to-view updates

    func testShowLoading_setsIsLoadingTrue() {
        // When
        sut.showLoading()

        // Then
        XCTAssertTrue(sut.isLoading)
    }

    func testHideLoading_setsIsLoadingFalse() {
        // Given
        sut.showLoading()

        // When
        sut.hideLoading()

        // Then
        XCTAssertFalse(sut.isLoading)
    }

    func testShowError_setsMessageAndFlag() {
        // When
        sut.showError("Oops")

        // Then
        XCTAssertEqual(sut.errorMessage, "Oops")
        XCTAssertTrue(sut.showError)
    }

    // MARK: - Actions

    func testUploadFile_callsPresenterUploadFileTapped() async {
        // When
        sut.uploadFile()
        await mockPresenter.waitForUploadFile(count: 1)

        // Then
        XCTAssertEqual(mockPresenter.uploadFileTappedCount, 1)
    }

    func testTakePhoto_callsPresenterTakePhotoTapped() async {
        // When
        sut.takePhoto()
        await mockPresenter.waitForTakePhoto(count: 1)

        // Then
        XCTAssertEqual(mockPresenter.takePhotoTappedCount, 1)
    }

    func testCancel_callsPresenterCancelTapped() async {
        // When
        sut.cancel()
        await mockPresenter.waitForCancel(count: 1)

        // Then
        XCTAssertEqual(mockPresenter.cancelTappedCount, 1)
    }
}

// MARK: - Mock Presenter

@MainActor private final class MockInvoiceInstructionsViewToPresenter: InvoiceInstructionsViewToPresenter {
    private(set) var viewDidLoadCount = 0
    private(set) var uploadFileTappedCount = 0
    private(set) var takePhotoTappedCount = 0
    private(set) var cancelTappedCount = 0
    private(set) var fileSelectedCount = 0
    private(set) var pickerCancelledCount = 0
    private(set) var fileSelectionFailedCount = 0

    func viewDidLoad() async {
        viewDidLoadCount += 1
    }

    func uploadFileTapped() async {
        uploadFileTappedCount += 1
    }

    func takePhotoTapped() async {
        takePhotoTappedCount += 1
    }

    func cancelTapped() async {
        cancelTappedCount += 1
    }

    func fileSelected(data: Data, contentType: String) async {
        fileSelectedCount += 1
    }

    func pickerCancelled() async {
        pickerCancelledCount += 1
    }

    func fileSelectionFailed(message: String) async {
        fileSelectionFailedCount += 1
    }

    // MARK: - Async wait helpers

    //
    // ViewModel dispatches via `Task { await presenter?.X() }` — polling the main-actor
    // counter avoids a hardcoded sleep while still letting the task land.
    func waitForViewDidLoad(count: Int, timeout: TimeInterval = 1.0) async {
        await waitUntil(timeout: timeout) { [weak self] in (self?.viewDidLoadCount ?? 0) >= count }
    }

    func waitForUploadFile(count: Int, timeout: TimeInterval = 1.0) async {
        await waitUntil(timeout: timeout) { [weak self] in (self?.uploadFileTappedCount ?? 0) >= count }
    }

    func waitForTakePhoto(count: Int, timeout: TimeInterval = 1.0) async {
        await waitUntil(timeout: timeout) { [weak self] in (self?.takePhotoTappedCount ?? 0) >= count }
    }

    func waitForCancel(count: Int, timeout: TimeInterval = 1.0) async {
        await waitUntil(timeout: timeout) { [weak self] in (self?.cancelTappedCount ?? 0) >= count }
    }

    private func waitUntil(timeout: TimeInterval, condition: @escaping () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
    }
}
