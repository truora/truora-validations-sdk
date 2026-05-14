//
//  InvoiceFeedbackViewModelTests.swift
//  TruoraValidationsSDKTests
//
//  Created by Truora on 22/04/26.
//

import XCTest
@testable import TruoraValidationsSDK

@MainActor final class InvoiceFeedbackViewModelTests: XCTestCase {
    private var mockPresenter: MockInvoiceFeedbackPresenter!

    override func setUp() {
        super.setUp()
        mockPresenter = MockInvoiceFeedbackPresenter()
    }

    override func tearDown() {
        mockPresenter = nil
        super.tearDown()
    }

    // MARK: - init

    func testInit_storesAllProperties() {
        // Given
        let data = Data([0xFF, 0xD8])

        // When
        let sut = InvoiceFeedbackViewModel(
            feedback: .missingText,
            capturedImageData: data,
            retriesLeft: 2,
            country: "MX"
        )

        // Then
        XCTAssertEqual(sut.feedback, .missingText)
        XCTAssertEqual(sut.capturedImageData, data)
        XCTAssertEqual(sut.retriesLeft, 2)
        XCTAssertEqual(sut.country, "MX")
    }

    func testInit_defaultsShowTipsFalse() {
        let sut = InvoiceFeedbackViewModel(
            feedback: .documentNotRecognized,
            capturedImageData: nil,
            retriesLeft: 0,
            country: "CO"
        )

        XCTAssertFalse(sut.showTips)
    }

    // MARK: - Lifecycle

    func testOnAppear_callsPresenterViewDidLoad() async {
        // Given
        let sut = makeSUT()
        sut.presenter = mockPresenter

        // When
        sut.onAppear()
        await mockPresenter.waitForViewDidLoad(count: 1)

        // Then
        XCTAssertEqual(mockPresenter.viewDidLoadCount, 1)
    }

    func testOnAppear_withNilPresenter_logsWarning_noCrash() async {
        // Given — presenter intentionally nil
        let sut = makeSUT()

        // When / Then — does not crash
        sut.onAppear()
        try? await Task.sleep(nanoseconds: 50_000_000)
    }

    func testOnDisappear_noOp() async {
        // Given
        let sut = makeSUT()
        sut.presenter = mockPresenter

        // When
        sut.onDisappear()
        try? await Task.sleep(nanoseconds: 50_000_000)

        // Then — none of the presenter methods fire
        XCTAssertEqual(mockPresenter.viewDidLoadCount, 0)
        XCTAssertEqual(mockPresenter.retryTappedCount, 0)
        XCTAssertEqual(mockPresenter.cancelTappedCount, 0)
    }

    // MARK: - Actions

    func testRetryTapped_callsPresenterRetryTapped() async {
        let sut = makeSUT()
        sut.presenter = mockPresenter

        sut.retryTapped()
        await mockPresenter.waitForRetryTapped(count: 1)

        XCTAssertEqual(mockPresenter.retryTappedCount, 1)
    }

    func testTipsTapped_setsShowTipsTrue() {
        let sut = makeSUT()
        sut.presenter = mockPresenter

        sut.tipsTapped()

        XCTAssertTrue(sut.showTips)
    }

    func testCancelTapped_callsPresenterCancelTapped() async {
        let sut = makeSUT()
        sut.presenter = mockPresenter

        sut.cancelTapped()
        await mockPresenter.waitForCancelTapped(count: 1)

        XCTAssertEqual(mockPresenter.cancelTappedCount, 1)
    }

    // MARK: - Helpers

    private func makeSUT(
        feedback: FeedbackScenario = .missingText,
        capturedImageData: Data? = nil,
        retriesLeft: Int = 2,
        country: String = "MX"
    ) -> InvoiceFeedbackViewModel {
        InvoiceFeedbackViewModel(
            feedback: feedback,
            capturedImageData: capturedImageData,
            retriesLeft: retriesLeft,
            country: country
        )
    }
}

// MARK: - Mock Presenter

@MainActor private final class MockInvoiceFeedbackPresenter: InvoiceFeedbackViewToPresenter {
    private(set) var viewDidLoadCount = 0
    private(set) var retryTappedCount = 0
    private(set) var tipsTappedCount = 0
    private(set) var dismissedCount = 0
    private(set) var cancelTappedCount = 0

    func viewDidLoad() async {
        viewDidLoadCount += 1
    }

    func retryTapped() async {
        retryTappedCount += 1
    }

    func tipsTapped() async {
        tipsTappedCount += 1
    }

    func dismissed() async {
        dismissedCount += 1
    }

    func cancelTapped() async {
        cancelTappedCount += 1
    }

    func waitForViewDidLoad(count: Int, timeout: TimeInterval = 1.0) async {
        await waitUntil(timeout: timeout) { [weak self] in (self?.viewDidLoadCount ?? 0) >= count }
    }

    func waitForRetryTapped(count: Int, timeout: TimeInterval = 1.0) async {
        await waitUntil(timeout: timeout) { [weak self] in (self?.retryTappedCount ?? 0) >= count }
    }

    func waitForCancelTapped(count: Int, timeout: TimeInterval = 1.0) async {
        await waitUntil(timeout: timeout) { [weak self] in (self?.cancelTappedCount ?? 0) >= count }
    }

    private func waitUntil(timeout: TimeInterval, condition: @escaping () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
    }
}
