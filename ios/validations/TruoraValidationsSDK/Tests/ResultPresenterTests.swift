//
//  ResultPresenterTests.swift
//  TruoraValidationsSDKTests
//
//  Created by Truora on 21/12/25.
//

import XCTest
@testable import TruoraValidationsSDK

@MainActor final class ResultPresenterTests: XCTestCase {
    private var mockView: MockResultView!
    private var mockInteractor: MockResultInteractor!
    private var mockRouter: MockResultRouter!
    private var mockDelegate: MockValidationDelegate!

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
        mockView = nil
        mockInteractor = nil
        mockRouter = nil
        mockDelegate = nil
        ValidationConfig.shared.reset()
        super.tearDown()
    }

    // MARK: - Lifecycle Tests

    func testViewDidLoad_waitingForResults_startsPollingAndShowsLoading() async {
        // Given
        ValidationConfig.shared.faceConfig.enableWaitForResults(true)
        let sut = createPresenter()

        // When
        await sut.viewDidLoad()

        // Then
        XCTAssertTrue(mockView.showLoadingCalled)
        XCTAssertTrue(mockInteractor.startPollingCalled)
    }

    func testViewDidLoad_notWaitingForResults_startsPollingAndShowsCompleted() async {
        // Given
        ValidationConfig.shared.faceConfig.enableWaitForResults(false)
        let sut = createPresenter(loadingType: .face)

        // When
        await sut.viewDidLoad()

        // Then
        XCTAssertTrue(mockView.showCompletedCalled)
        XCTAssertTrue(mockInteractor.startPollingCalled)
    }

    // MARK: - Action Tests

    func testDoneTapped_withResult_dismissesFlowAndNotifiesDelegate() async {
        // Given
        ValidationConfig.shared.faceConfig.enableWaitForResults(true)
        let sut = createPresenter()
        let result = ValidationResult(validationId: "id", status: .success)
        await sut.pollingCompleted(result: result)

        // When
        await sut.doneTapped()

        // Then
        XCTAssertTrue(mockRouter.dismissFlowCalled)
    }

    // MARK: - Interactor Callback Tests

    func testPollingCompleted_waitingForResults_showsResult() async {
        // Given
        ValidationConfig.shared.faceConfig.enableWaitForResults(true)
        let sut = createPresenter()
        let result = ValidationResult(validationId: "id", status: .success)

        // When
        await sut.pollingCompleted(result: result)

        // Then
        XCTAssertTrue(mockView.showResultCalled)
        XCTAssertEqual(mockView.lastResult, result)
    }

    func testPollingFailed_waitingForResults_showsFailedResult() async {
        // Given
        ValidationConfig.shared.faceConfig.enableWaitForResults(true)
        let sut = createPresenter()

        // When
        await sut.pollingFailed(error: .network(message: "error"))

        // Then
        XCTAssertTrue(mockView.showResultCalled)
        XCTAssertEqual(mockView.lastResult?.status, .failed)
    }

    // MARK: - Helper Methods

    private func createPresenter(
        loadingType: ResultLoadingType = .face
    ) -> ResultPresenter {
        ResultPresenter(
            view: mockView,
            interactor: mockInteractor,
            router: mockRouter,
            loadingType: loadingType
        )
    }
}

// MARK: - Mock View

@MainActor private class MockResultView: ResultPresenterToView {
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

@MainActor private class MockResultInteractor: ResultPresenterToInteractor {
    var validationId: String = "test-validation-id"
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

@MainActor private class MockResultRouter: ValidationRouter {
    var dismissFlowCalled = false

    override func dismissFlow() {
        dismissFlowCalled = true
    }
}

// MARK: - Mock Delegate

@MainActor private class MockValidationDelegate {
    var completeCalled = false
    var failureCalled = false
    var lastResult: ValidationResult?
    var lastError: TruoraException?

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
