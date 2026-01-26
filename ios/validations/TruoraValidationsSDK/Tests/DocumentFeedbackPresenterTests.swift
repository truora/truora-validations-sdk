//
//  DocumentFeedbackPresenterTests.swift
//  TruoraValidationsSDKTests
//
//  Created by Truora on 06/01/26.
//

import XCTest

@testable import TruoraValidationsSDK

final class DocumentFeedbackPresenterTests: XCTestCase {
    private var sut: DocumentFeedbackPresenter!
    private var mockView: MockDocumentFeedbackView!
    private var mockRouter: MockDocumentFeedbackRouter!

    override func setUp() {
        super.setUp()
        mockView = MockDocumentFeedbackView()
        let navController = UINavigationController()
        mockRouter = MockDocumentFeedbackRouter(navigationController: navController)

        sut = DocumentFeedbackPresenter(
            view: mockView,
            router: mockRouter
        )
    }

    override func tearDown() {
        sut = nil
        mockView = nil
        mockRouter = nil
        super.tearDown()
    }

    func testInitialization_storesWeakReferences() {
        XCTAssertNotNil(sut.view)
        XCTAssertNotNil(sut.router)
    }

    func testViewDidLoad_executesWithoutError() {
        XCTAssertNoThrow(sut.viewDidLoad())
    }

    func testRetryTapped_dismissesFeedback() {
        sut.retryTapped()

        XCTAssertTrue(mockRouter.dismissDocumentFeedbackCalled)
    }

    func testTipsTapped_executesWithoutError() {
        XCTAssertNoThrow(sut.tipsTapped())
        XCTAssertFalse(mockRouter.dismissDocumentFeedbackCalled)
    }

    func testDismissed_dismissesFeedback() {
        sut.dismissed()

        XCTAssertTrue(mockRouter.dismissDocumentFeedbackCalled)
    }

    func testWeakReferences_allowViewDeallocation() {
        autoreleasepool {
            var view: MockDocumentFeedbackView? = MockDocumentFeedbackView()
            let navController = UINavigationController()
            let router = MockDocumentFeedbackRouter(navigationController: navController)
            let presenter = DocumentFeedbackPresenter(view: view!, router: router)

            weak var weakView = view
            view = nil

            XCTAssertNil(weakView, "View should be deallocated when no strong references exist")
            XCTAssertNil(presenter.view, "Presenter should have nil view after deallocation")
        }
    }

    func testWeakReferences_allowRouterDeallocation() {
        autoreleasepool {
            let view = MockDocumentFeedbackView()
            var router: MockDocumentFeedbackRouter? = {
                let navController = UINavigationController()
                return MockDocumentFeedbackRouter(navigationController: navController)
            }()
            let presenter = DocumentFeedbackPresenter(view: view, router: router!)

            weak var weakRouter = router
            router = nil

            XCTAssertNil(weakRouter, "Router should be deallocated when no strong references exist")
            XCTAssertNil(presenter.router, "Presenter should have nil router after deallocation")
        }
    }
}

// MARK: - Mocks

private final class MockDocumentFeedbackView: DocumentFeedbackPresenterToView {}

private final class MockDocumentFeedbackRouter: ValidationRouter {
    private(set) var dismissDocumentFeedbackCalled = false

    override func dismissDocumentFeedback(completion: (() -> Void)? = nil) {
        dismissDocumentFeedbackCalled = true
        completion?()
    }
}
