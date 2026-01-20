//
//  EnrollmentStatusPresenterTests.swift
//  TruoraValidationsSDKTests
//
//  Created by Truora on 11/11/25.
//

import XCTest
@testable import TruoraValidationsSDK

class EnrollmentStatusPresenterTests: XCTestCase {
    var presenter: EnrollmentStatusPresenter!
    fileprivate var mockView: MockEnrollmentStatusView!
    fileprivate var mockInteractor: MockEnrollmentStatusInteractor!
    fileprivate var mockRouter: MockValidationRouter!

    override func setUp() {
        super.setUp()
        mockView = MockEnrollmentStatusView()
        mockInteractor = MockEnrollmentStatusInteractor()
        let navController = UINavigationController()
        mockRouter = MockValidationRouter(navigationController: navController)

        presenter = EnrollmentStatusPresenter(
            view: mockView,
            interactor: mockInteractor,
            router: mockRouter,
            enrollmentId: "test-enrollment-id"
        )
    }

    override func tearDown() {
        presenter = nil
        mockView = nil
        mockInteractor = nil
        mockRouter = nil
        super.tearDown()
    }

    // MARK: - View Lifecycle Tests

    func testViewDidLoad() {
        // When
        presenter.viewDidLoad()

        // Then
        XCTAssertTrue(mockView.showLoadingCalled)
        XCTAssertTrue(mockInteractor.checkEnrollmentStatusCalled)
        XCTAssertEqual(mockInteractor.lastEnrollmentId, "test-enrollment-id")
    }

    // MARK: - Enrollment Check Completed Tests

    func testEnrollmentCheckCompletedWithSuccessfulNavigation() {
        // Given
        let status = "approved"
        let expectation = XCTestExpectation(description: "Navigation delayed")

        // When
        presenter.enrollmentCheckCompleted(status: status)

        // Then
        XCTAssertTrue(mockView.hideLoadingCalled)
        XCTAssertTrue(mockView.updateStatusCalled)
        XCTAssertTrue(mockView.lastStatusMessage?.contains("approved") ?? false)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            XCTAssertTrue(self.mockRouter.navigateToPassiveIntroCalled)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testEnrollmentCheckCompletedWithNilRouter() {
        // Given
        presenter.router = nil
        let status = "approved"
        let expectation = XCTestExpectation(description: "Error handling delayed")

        // When
        presenter.enrollmentCheckCompleted(status: status)

        // Then
        XCTAssertTrue(mockView.hideLoadingCalled)
        XCTAssertTrue(mockView.updateStatusCalled)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            XCTAssertTrue(self.mockView.showErrorCalled, "showError should have been called")
            XCTAssertTrue(
                self.mockView.lastErrorMessage?.contains("Navigation failed") ?? false,
                "Error message should contain 'Navigation failed', got: \(self.mockView.lastErrorMessage ?? "nil")"
            )
            XCTAssertTrue(
                self.mockView.lastErrorMessage?.contains("Router not configured") ?? false,
                "Error message should contain 'Router not configured', got: \(self.mockView.lastErrorMessage ?? "nil")"
            )
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testEnrollmentCheckCompletedWithNavigationError() {
        // Given
        mockRouter.shouldThrowError = true
        let status = "approved"
        let expectation = XCTestExpectation(description: "Error handling delayed")

        // When
        presenter.enrollmentCheckCompleted(status: status)

        // Then
        XCTAssertTrue(mockView.hideLoadingCalled)
        XCTAssertTrue(mockView.updateStatusCalled)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            XCTAssertTrue(self.mockView.showErrorCalled)
            XCTAssertTrue(self.mockView.lastErrorMessage?.contains("Navigation failed") ?? false)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Enrollment Check Failed Tests

    func testEnrollmentCheckFailed() {
        // Given
        let errorMessage = "Network error"

        // When
        presenter.enrollmentCheckFailed(error: errorMessage)

        // Then
        XCTAssertTrue(mockView.hideLoadingCalled)
        XCTAssertTrue(mockView.showErrorCalled)
        XCTAssertTrue(mockView.lastErrorMessage?.contains(errorMessage) ?? false)
    }
}

// MARK: - Mock View

private class MockEnrollmentStatusView: EnrollmentStatusPresenterToView {
    var showLoadingCalled = false
    var hideLoadingCalled = false
    var updateStatusCalled = false
    var showErrorCalled = false
    var lastStatusMessage: String?
    var lastErrorMessage: String?

    func showLoading() {
        showLoadingCalled = true
    }

    func hideLoading() {
        hideLoadingCalled = true
    }

    func updateStatus(_ message: String) {
        updateStatusCalled = true
        lastStatusMessage = message
    }

    func showError(_ message: String) {
        showErrorCalled = true
        lastErrorMessage = message
    }
}

// MARK: - Mock Interactor

private class MockEnrollmentStatusInteractor: EnrollmentStatusPresenterToInteractor {
    var checkEnrollmentStatusCalled = false
    var lastEnrollmentId: String?

    func checkEnrollmentStatus(enrollmentId: String) {
        checkEnrollmentStatusCalled = true
        lastEnrollmentId = enrollmentId
    }
}

// MARK: - Mock Router

private class MockValidationRouter: ValidationRouter {
    var navigateToPassiveIntroCalled = false
    var shouldThrowError = false

    override func navigateToPassiveIntro() throws {
        navigateToPassiveIntroCalled = true
        if shouldThrowError {
            throw ValidationError.internalError("Router not configured")
        }
    }
}
