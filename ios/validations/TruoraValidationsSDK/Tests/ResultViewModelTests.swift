//
//  ResultViewModelTests.swift
//  TruoraValidationsSDKTests
//
//  Created by Truora on 11/11/25.
//

import SwiftUI
import TruoraShared
import XCTest
@testable import TruoraValidationsSDK

class ResultViewModelTests: XCTestCase {
    var viewModel: ResultViewModel!
    fileprivate var mockPresenter: MockResultPresenter!

    override func setUp() {
        super.setUp()
        viewModel = ResultViewModel()
        mockPresenter = MockResultPresenter()
        viewModel.presenter = mockPresenter
    }

    override func tearDown() {
        viewModel = nil
        mockPresenter = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialState() {
        // Given/When
        let resultViewModel = ResultViewModel()

        // Then - Initial state should be loading
        XCTAssertTrue(resultViewModel.showLoadingScreen)
        XCTAssertFalse(resultViewModel.isButtonLoading)
    }

    // MARK: - onAppear Tests

    func testOnAppearCallsPresenter() {
        // When - SwiftUI's onAppear maps to VIPER's viewDidLoad
        viewModel.onAppear()

        // Then - Verify onAppear() triggers presenter.viewDidLoad()
        XCTAssertTrue(mockPresenter.viewDidLoadCalled)
    }

    // MARK: - doneTapped Tests

    func testDoneTappedCallsPresenter() {
        // When
        viewModel.doneTapped()

        // Then
        XCTAssertTrue(mockPresenter.doneTappedCalled)
    }

    // MARK: - ShowLoading Tests

    func testShowLoadingSetsLoadingState() {
        // When
        viewModel.showLoading()

        // Allow async dispatch to complete
        let expectation = self.expectation(description: "Wait for dispatch")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Then
            XCTAssertTrue(self.viewModel.showLoadingScreen)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 0.5)
    }

    // MARK: - ShowResult Tests

    func testShowResultWithSuccess() {
        // Given
        let result = ValidationResult(
            validationId: "test-id",
            status: .success,
            confidence: 0.95
        )

        // When
        viewModel.showResult(result)

        // Allow async dispatch to complete
        let expectation = self.expectation(description: "Wait for dispatch")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Then
            XCTAssertFalse(self.viewModel.showLoadingScreen)
            XCTAssertEqual(self.viewModel.validationResultType, ValidationResultType.success)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 0.5)
    }

    func testShowResultWithFailure() {
        // Given
        let result = ValidationResult(
            validationId: "test-id",
            status: .failed,
            confidence: nil
        )

        // When
        viewModel.showResult(result)

        // Allow async dispatch to complete
        let expectation = self.expectation(description: "Wait for dispatch")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Then
            XCTAssertFalse(self.viewModel.showLoadingScreen)
            XCTAssertEqual(self.viewModel.validationResultType, ValidationResultType.failure)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 0.5)
    }

    // MARK: - ShowCompleted Tests

    func testShowCompletedSetsCompletedState() {
        // When
        viewModel.showCompleted()

        // Allow async dispatch to complete
        let expectation = self.expectation(description: "Wait for dispatch")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Then
            XCTAssertFalse(self.viewModel.showLoadingScreen)
            XCTAssertEqual(self.viewModel.validationResultType, ValidationResultType.completed)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 0.5)
    }

    // MARK: - SetLoadingButtonState Tests

    func testSetLoadingButtonStateTrue() {
        // When
        viewModel.setLoadingButtonState(true)

        // Allow async dispatch to complete
        let expectation = self.expectation(description: "Wait for dispatch")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Then
            XCTAssertTrue(self.viewModel.isButtonLoading)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 0.5)
    }

    func testSetLoadingButtonStateFalse() {
        // Given - First set to true, then set to false
        viewModel.setLoadingButtonState(true)

        let expectation = self.expectation(description: "Wait for state changes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Verify initial state was set
            XCTAssertTrue(self.viewModel.isButtonLoading)

            // When - Set to false
            self.viewModel.setLoadingButtonState(false)

            // Then - Wait for second state change
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                XCTAssertFalse(self.viewModel.isButtonLoading)
                expectation.fulfill()
            }
        }
        waitForExpectations(timeout: 1.0)
    }

    // MARK: - ValidationResultType Mapping Tests

    func testValidationResultTypeForLoadingState() {
        // Given - Default state is loading
        let resultViewModel = ResultViewModel()

        // When/Then - Loading state should return completed as placeholder
        XCTAssertEqual(resultViewModel.validationResultType, ValidationResultType.completed)
        XCTAssertTrue(resultViewModel.showLoadingScreen)
    }

    func testValidationResultTypeForSuccessResult() {
        // Given
        let result = ValidationResult(
            validationId: "test-id",
            status: .success,
            confidence: 0.95
        )
        viewModel.showResult(result)

        // Allow async dispatch to complete
        let expectation = self.expectation(description: "Wait for dispatch")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Then
            XCTAssertEqual(self.viewModel.validationResultType, ValidationResultType.success)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 0.5)
    }

    func testValidationResultTypeForFailedResult() {
        // Given
        let result = ValidationResult(
            validationId: "test-id",
            status: .failed,
            confidence: nil
        )
        viewModel.showResult(result)

        // Allow async dispatch to complete
        let expectation = self.expectation(description: "Wait for dispatch")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Then
            XCTAssertEqual(self.viewModel.validationResultType, ValidationResultType.failure)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 0.5)
    }

    func testValidationResultTypeForPendingResult() {
        // Given
        let result = ValidationResult(
            validationId: "test-id",
            status: .pending,
            confidence: nil
        )
        viewModel.showResult(result)

        // Allow async dispatch to complete
        let expectation = self.expectation(description: "Wait for dispatch")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Then
            XCTAssertEqual(self.viewModel.validationResultType, ValidationResultType.completed)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 0.5)
    }

    func testValidationResultTypeForProcessingResult() {
        // Given
        let result = ValidationResult(
            validationId: "test-id",
            status: .processing,
            confidence: nil
        )
        viewModel.showResult(result)

        // Allow async dispatch to complete
        let expectation = self.expectation(description: "Wait for dispatch")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Then
            XCTAssertEqual(self.viewModel.validationResultType, ValidationResultType.completed)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 0.5)
    }

    // MARK: - Formatted Date Tests

    func testFormattedDateReturnsNonEmptyString() {
        // When
        let formattedDate = viewModel.formattedDate

        // Then
        XCTAssertFalse(formattedDate.isEmpty)
    }

    func testFormattedDateUsesLongStyle() {
        // When
        let formattedDate = viewModel.formattedDate

        // Then - Verify formatted date matches expected long date style format
        let expectedFormatter = DateFormatter()
        expectedFormatter.dateStyle = .long
        expectedFormatter.timeStyle = .none
        let expectedDate = expectedFormatter.string(from: Date())

        XCTAssertEqual(formattedDate, expectedDate, "Date should be formatted with long date style")
    }
}

// MARK: - Mock Presenter

private class MockResultPresenter: ResultViewToPresenter {
    var viewDidLoadCalled = false
    var doneTappedCalled = false

    func viewDidLoad() {
        viewDidLoadCalled = true
    }

    func doneTapped() {
        doneTappedCalled = true
    }
}
