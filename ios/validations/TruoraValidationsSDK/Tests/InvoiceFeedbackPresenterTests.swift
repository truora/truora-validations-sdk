//
//  InvoiceFeedbackPresenterTests.swift
//  TruoraValidationsSDKTests
//
//  Created by Truora on 22/04/26.
//

import XCTest
@testable import TruoraValidationsSDK

@MainActor final class InvoiceFeedbackPresenterTests: XCTestCase {
    private var mockView: MockInvoiceFeedbackView!
    private var mockRouter: MockInvoiceFeedbackRouter!

    override func setUp() {
        super.setUp()
        mockView = MockInvoiceFeedbackView()
        mockRouter = MockInvoiceFeedbackRouter(navigationController: TruoraNavigationController())
    }

    override func tearDown() {
        mockView = nil
        mockRouter = nil
        super.tearDown()
    }

    // MARK: - init

    func testInit_storesWeakReferences() {
        let sut = makeSUT()

        XCTAssertNotNil(sut.view)
        XCTAssertNotNil(sut.router)
    }

    // MARK: - viewDidLoad

    func testViewDidLoad_executesWithoutError() async {
        let sut = makeSUT()
        await sut.viewDidLoad()
        // No observable side effect — just ensures the no-op doesn't throw/crash
    }

    // MARK: - retryTapped

    func testRetryTapped_dismissOnlyBehavior_callsDismissInvoiceFeedback() async {
        let sut = makeSUT(retryBehavior: .dismissOnly)

        await sut.retryTapped()

        XCTAssertTrue(mockRouter.dismissInvoiceFeedbackCalled)
        XCTAssertFalse(mockRouter.dismissInvoiceFeedbackAndPopCalled)
    }

    func testRetryTapped_popToIntroBehavior_callsDismissAndPop() async {
        let sut = makeSUT(retryBehavior: .popToInvoiceInstructions)

        await sut.retryTapped()

        XCTAssertTrue(mockRouter.dismissInvoiceFeedbackAndPopCalled)
        XCTAssertFalse(mockRouter.dismissInvoiceFeedbackCalled)
    }

    // MARK: - tipsTapped

    func testTipsTapped_doesNotDismiss() async {
        let sut = makeSUT()

        await sut.tipsTapped()

        XCTAssertFalse(mockRouter.dismissInvoiceFeedbackCalled)
        XCTAssertFalse(mockRouter.dismissInvoiceFeedbackAndPopCalled)
    }

    // MARK: - dismissed

    func testDismissed_dismissOnlyBehavior_callsDismissInvoiceFeedback() async {
        let sut = makeSUT(retryBehavior: .dismissOnly)

        await sut.dismissed()

        XCTAssertTrue(mockRouter.dismissInvoiceFeedbackCalled)
        XCTAssertFalse(mockRouter.dismissInvoiceFeedbackAndPopCalled)
    }

    func testDismissed_popToIntroBehavior_callsDismissAndPop() async {
        // Guards against swipe/gesture-dismiss leaving Result on the nav stack
        // when feedback was shown from the Result screen.
        let sut = makeSUT(retryBehavior: .popToInvoiceInstructions)

        await sut.dismissed()

        XCTAssertTrue(mockRouter.dismissInvoiceFeedbackAndPopCalled)
        XCTAssertFalse(mockRouter.dismissInvoiceFeedbackCalled)
    }

    // MARK: - cancelTapped

    func testCancelTapped_delegatesToInvoiceFeedbackCancellation() async {
        // The presenter routes through `handleInvoiceFeedbackCancellation` so the
        // confirmation alert appears on the feedback modal itself (instead of the
        // nav controller after a dismiss — which flashed "Verificando").
        let sut = makeSUT()

        await sut.cancelTapped()

        XCTAssertTrue(mockRouter.handleInvoiceFeedbackCancellationCalled)
        XCTAssertEqual(mockRouter.callOrder, ["handleInvoiceFeedbackCancellation"])
    }

    func testCancelTapped_doesNotDismissFeedbackUpfront() async {
        // Feedback stays on screen until the user confirms on the alert. The router's
        // handleInvoiceFeedbackCancellation owns the dismiss/exit decision.
        let sut = makeSUT()

        await sut.cancelTapped()

        XCTAssertFalse(mockRouter.dismissInvoiceFeedbackCalled)
        XCTAssertFalse(mockRouter.dismissInvoiceFeedbackAndPopCalled)
    }

    // MARK: - Weak reference tests

    func testWeakReferences_allowViewDeallocation() {
        autoreleasepool {
            var view: MockInvoiceFeedbackView? = MockInvoiceFeedbackView()
            let router = MockInvoiceFeedbackRouter(navigationController: TruoraNavigationController())
            let presenter = InvoiceFeedbackPresenter(view: view!, router: router)

            weak var weakView = view
            view = nil

            XCTAssertNil(weakView, "View should deallocate")
            XCTAssertNil(presenter.view)
        }
    }

    func testWeakReferences_allowRouterDeallocation() {
        autoreleasepool {
            let view = MockInvoiceFeedbackView()
            var router: MockInvoiceFeedbackRouter? = MockInvoiceFeedbackRouter(
                navigationController: TruoraNavigationController()
            )
            let presenter = InvoiceFeedbackPresenter(view: view, router: router!)

            weak var weakRouter = router
            router = nil

            XCTAssertNil(weakRouter, "Router should deallocate")
            XCTAssertNil(presenter.router)
        }
    }

    // MARK: - Helpers

    private func makeSUT(
        retryBehavior: InvoiceFeedbackRetryBehavior = .dismissOnly
    ) -> InvoiceFeedbackPresenter {
        InvoiceFeedbackPresenter(
            view: mockView,
            router: mockRouter,
            retryBehavior: retryBehavior
        )
    }
}

// MARK: - Mocks

@MainActor private final class MockInvoiceFeedbackView: InvoiceFeedbackPresenterToView {}

@MainActor private final class MockInvoiceFeedbackRouter: ValidationRouter {
    private(set) var dismissInvoiceFeedbackCalled = false
    private(set) var dismissInvoiceFeedbackAndPopCalled = false
    private(set) var handleInvoiceFeedbackCancellationCalled = false
    private(set) var callOrder: [String] = []

    override func dismissInvoiceFeedback(completion: (() -> Void)? = nil) {
        dismissInvoiceFeedbackCalled = true
        callOrder.append("dismissInvoiceFeedback")
        completion?()
    }

    override func dismissInvoiceFeedbackAndPopToIntro() {
        dismissInvoiceFeedbackAndPopCalled = true
        callOrder.append("dismissInvoiceFeedbackAndPop")
    }

    override func handleInvoiceFeedbackCancellation() {
        handleInvoiceFeedbackCancellationCalled = true
        callOrder.append("handleInvoiceFeedbackCancellation")
    }
}
