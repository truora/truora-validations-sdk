//
//  ResultPresenterTests.swift
//  TruoraValidationsSDKTests
//
//  Created by Truora on 21/12/25.
//

import TruoraShared
import XCTest
@testable import TruoraValidationsSDK

class ResultPresenterTests: XCTestCase {
    var sut: ResultPresenter!
    fileprivate var mockView: MockResultView!
    fileprivate var mockInteractor: MockResultInteractor!
    fileprivate var mockRouter: MockResultRouter!
    fileprivate var mockDelegate: MockValidationDelegate!

    override func setUp() {
        super.setUp()
        mockView = MockResultView()
        mockInteractor = MockResultInteractor()
        let navController = UINavigationController()
        mockRouter = MockResultRouter(navigationController: navController)
        mockDelegate = MockValidationDelegate()
        ValidationConfig.shared.reset()
    }

    override func tearDown() {
        sut = nil
        mockView = nil
        mockInteractor = nil
        mockRouter = nil
        mockDelegate = nil
        ValidationConfig.shared.reset()
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitializationWithShouldWaitTrue() {
        // When
        sut = createPresenter(shouldWaitForResults: true)

        // Then
        XCTAssertNotNil(sut)
    }

    func testInitializationWithShouldWaitFalse() {
        // When
        sut = createPresenter(shouldWaitForResults: false)

        // Then
        XCTAssertNotNil(sut)
    }

    // MARK: - ViewDidLoad Tests (shouldWaitForResults = true)

    func testViewDidLoad_whenShouldWaitTrue_showsLoadingAndStartsPolling() {
        // Given
        sut = createPresenter(shouldWaitForResults: true)

        // When
        sut.viewDidLoad()

        // Then
        XCTAssertTrue(mockView.showLoadingCalled, "Should show loading")
        XCTAssertTrue(mockInteractor.startPollingCalled, "Should start polling")
    }

    // MARK: - ViewDidLoad Tests (shouldWaitForResults = false)

    func testViewDidLoad_whenShouldWaitFalse_showsCompletedAndStartsPolling() {
        // Given
        sut = createPresenter(shouldWaitForResults: false)

        // When
        sut.viewDidLoad()

        // Then
        XCTAssertTrue(mockView.showCompletedCalled, "Should show completed")
        XCTAssertTrue(mockInteractor.startPollingCalled, "Should start polling in background")
    }

    func testViewDidLoad_whenDocument_forcesWaitEvenIfConfigFalse() {
        // Given
        sut = createPresenter(loadingType: .document, shouldWaitForResults: false)

        // When
        sut.viewDidLoad()

        // Then
        XCTAssertTrue(mockView.showLoadingCalled, "Document should always show loading")
        XCTAssertFalse(mockView.showCompletedCalled, "Document should not show completed immediately")
        XCTAssertTrue(mockInteractor.startPollingCalled, "Document should start polling")
    }

    // MARK: - DoneTapped Tests (shouldWaitForResults = true)

    func testDoneTapped_whenShouldWaitTrue_andNoResult_doesNotDismiss() {
        // Given
        sut = createPresenter(shouldWaitForResults: true)

        // When
        sut.doneTapped()

        // Then
        XCTAssertFalse(mockRouter.dismissFlowCalled, "Should not dismiss without result")
    }

    func testDoneTapped_whenShouldWaitTrue_andHasResult_dismissesAndCallsDelegate() async throws {
        // Given
        sut = createPresenter(shouldWaitForResults: true)

        try await ValidationConfig.shared.configure(
            apiKey: "test-key",
            accountId: "test-account",
            delegate: mockDelegate.closure
        )

        let result = ValidationResult(
            validationId: "test-id",
            status: .success,
            confidence: 0.95
        )
        sut.pollingCompleted(result: result)

        // When
        sut.doneTapped()

        // Then
        XCTAssertTrue(mockRouter.dismissFlowCalled, "Should dismiss flow")

        let expectation = self.expectation(description: "Wait for delegate")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            XCTAssertTrue(self.mockDelegate.completeCalled, "Should call delegate")
            XCTAssertEqual(self.mockDelegate.lastResult?.validationId, "test-id")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 0.5)
    }

    // MARK: - DoneTapped Tests (shouldWaitForResults = false)

    func testDoneTapped_whenShouldWaitFalse_dismissesImmediately() {
        // Given
        sut = createPresenter(shouldWaitForResults: false)

        // When
        sut.doneTapped()

        // Then
        XCTAssertTrue(mockRouter.dismissFlowCalled, "Should dismiss immediately")
    }

    // MARK: - PollingCompleted Tests (shouldWaitForResults = true)

    func testPollingCompleted_whenShouldWaitTrue_showsResult() {
        // Given
        sut = createPresenter(shouldWaitForResults: true)
        let result = ValidationResult(
            validationId: "test-id",
            status: .success,
            confidence: 0.95
        )

        // When
        sut.pollingCompleted(result: result)

        // Then
        XCTAssertTrue(mockView.showResultCalled, "Should show result")
        XCTAssertEqual(mockView.lastResult?.status, .success)
    }

    // MARK: - PollingCompleted Tests (shouldWaitForResults = false)

    func testPollingCompleted_whenShouldWaitFalse_callsDelegateAutomatically() async throws {
        // Given
        sut = createPresenter(shouldWaitForResults: false)

        try await ValidationConfig.shared.configure(
            apiKey: "test-key",
            accountId: "test-account",
            delegate: mockDelegate.closure
        )

        let result = ValidationResult(
            validationId: "test-id",
            status: .success,
            confidence: 0.95
        )

        // When
        sut.pollingCompleted(result: result)

        // Then
        XCTAssertFalse(mockView.showResultCalled, "Should not update UI")

        let expectation = self.expectation(description: "Wait for delegate")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            XCTAssertTrue(self.mockDelegate.completeCalled, "Should call delegate automatically")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 0.5)
    }

    // MARK: - PollingFailed Tests

    func testPollingFailed_whenShouldWaitTrue_showsFailedResult() {
        // Given
        sut = createPresenter(shouldWaitForResults: true)
        let error = ValidationError.apiError("Test error")

        // When
        sut.pollingFailed(error: error)

        // Then
        XCTAssertTrue(mockView.showResultCalled, "Should show failed result")
        XCTAssertEqual(mockView.lastResult?.status, .failed)
    }

    func testPollingFailed_whenShouldWaitFalse_callsDelegateWithError() async throws {
        // Given
        sut = createPresenter(shouldWaitForResults: false)

        try await ValidationConfig.shared.configure(
            apiKey: "test-key",
            accountId: "test-account",
            delegate: mockDelegate.closure
        )

        let error = ValidationError.apiError("Test error")

        // When
        sut.pollingFailed(error: error)

        // Then
        let expectation = self.expectation(description: "Wait for delegate")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            XCTAssertTrue(self.mockDelegate.failureCalled, "Should call delegate with error")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 0.5)
    }

    // MARK: - Helpers

    private func createPresenter(
        loadingType: LoadingType = .face,
        shouldWaitForResults: Bool
    ) -> ResultPresenter {
        let presenter = ResultPresenter(
            validationId: "test-validation-id",
            loadingType: loadingType,
            shouldWaitForResults: shouldWaitForResults
        )
        presenter.view = mockView
        presenter.interactor = mockInteractor
        presenter.router = mockRouter
        return presenter
    }
}

// MARK: - Mock View

private class MockResultView: ResultPresenterToView {
    var showLoadingCalled = false
    var showResultCalled = false
    var showCompletedCalled = false
    var setLoadingButtonStateCalled = false
    var lastResult: ValidationResult?
    var lastButtonLoadingState: Bool?

    func showLoading() {
        showLoadingCalled = true
    }

    func showResult(_ result: ValidationResult) {
        showResultCalled = true
        lastResult = result
    }

    func showCompleted() {
        showCompletedCalled = true
    }

    func setLoadingButtonState(_ isLoading: Bool) {
        setLoadingButtonStateCalled = true
        lastButtonLoadingState = isLoading
    }
}

// MARK: - Mock Interactor

private class MockResultInteractor: ResultPresenterToInteractor {
    var startPollingCalled = false
    var cancelPollingCalled = false

    func startPolling() {
        startPollingCalled = true
    }

    func cancelPolling() {
        cancelPollingCalled = true
    }
}

// MARK: - Mock Router

private class MockResultRouter: ValidationRouter {
    var dismissFlowCalled = false

    override func dismissFlow() {
        dismissFlowCalled = true
    }
}

// MARK: - Mock Delegate

private class MockValidationDelegate {
    var completeCalled = false
    var failureCalled = false
    var lastResult: ValidationResult?
    var lastError: ValidationError?

    var closure: (TruoraValidationResult<ValidationResult>) -> Void {
        { [weak self] result in
            switch result {
            case .complete(let validationResult):
                self?.completeCalled = true
                self?.lastResult = validationResult
            case .failure(let error):
                self?.failureCalled = true
                self?.lastError = error
            case .capture:
                break
            }
        }
    }
}
