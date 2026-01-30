//
//  DocumentSelectionPresenterTests.swift
//  TruoraValidationsSDKTests
//
//  Created by Truora on 07/01/26.
//

import AVFoundation
import XCTest
@testable import TruoraValidationsSDK

@MainActor final class DocumentSelectionPresenterTests: XCTestCase {
    private var sut: DocumentSelectionPresenter!
    private var mockView: MockDocumentSelectionView!
    private var mockInteractor: MockDocumentSelectionInteractor!
    private var mockRouter: MockDocumentSelectionRouter!

    override func setUp() {
        super.setUp()
        mockView = MockDocumentSelectionView()
        mockInteractor = MockDocumentSelectionInteractor()
        let navController = UINavigationController()
        mockRouter = MockDocumentSelectionRouter(navigationController: navController)
    }

    override func tearDown() {
        sut = nil
        mockView = nil
        mockInteractor = nil
        mockRouter = nil
        super.tearDown()
    }

    func testViewDidLoad_fetchesCountries_andDoesNotShowAlertWhenAuthorized() async {
        let cameraChecker = MockCameraPermissionChecker(
            status: .authorized,
            requestAccessResult: nil
        )
        sut = DocumentSelectionPresenter(
            view: mockView,
            interactor: mockInteractor,
            router: mockRouter,
            cameraPermissionChecker: cameraChecker
        )

        await sut.viewDidLoad()

        XCTAssertTrue(mockInteractor.fetchSupportedCountriesCalled)
        XCTAssertFalse(mockView.displayCameraPermissionAlertCalled)
    }

    func testViewDidLoad_showsAlertWhenDenied() async {
        let cameraChecker = MockCameraPermissionChecker(
            status: .denied,
            requestAccessResult: nil
        )
        sut = DocumentSelectionPresenter(
            view: mockView,
            interactor: mockInteractor,
            router: mockRouter,
            cameraPermissionChecker: cameraChecker
        )

        await sut.viewDidLoad()

        XCTAssertTrue(mockView.displayCameraPermissionAlertCalled)
    }

    func testContinueTapped_withoutSelections_setsErrorsAndDoesNotNavigate() async {
        let cameraChecker = MockCameraPermissionChecker(status: .authorized, requestAccessResult: nil)
        sut = DocumentSelectionPresenter(
            view: mockView,
            interactor: mockInteractor,
            router: mockRouter,
            cameraPermissionChecker: cameraChecker
        )

        await sut.continueTapped()

        XCTAssertTrue(mockView.setErrorsCalled)
        XCTAssertTrue(mockView.lastIsCountryError ?? false)
        XCTAssertTrue(mockView.lastIsDocumentError ?? false)
        XCTAssertFalse(mockRouter.navigateToDocumentIntroCalled)
    }

    func testContinueTapped_withSelections_butCameraNotAuthorized_showsAlertAndDoesNotNavigate() async {
        let cameraChecker = MockCameraPermissionChecker(status: .denied, requestAccessResult: nil)
        sut = DocumentSelectionPresenter(
            view: mockView,
            interactor: mockInteractor,
            router: mockRouter,
            cameraPermissionChecker: cameraChecker
        )

        await sut.countrySelected(.co)
        await sut.documentSelected(.nationalId)
        await sut.continueTapped()

        XCTAssertTrue(mockView.displayCameraPermissionAlertCalled)
        XCTAssertFalse(mockRouter.navigateToDocumentIntroCalled)
    }

    func testContinueTapped_withValidSelections_andCameraAuthorized_navigatesToDocumentIntroWithMappedValues() async {
        let cameraChecker = MockCameraPermissionChecker(status: .authorized, requestAccessResult: nil)
        sut = DocumentSelectionPresenter(
            view: mockView,
            interactor: mockInteractor,
            router: mockRouter,
            cameraPermissionChecker: cameraChecker
        )
        await sut.viewDidLoad()

        await sut.countrySelected(.co)
        await sut.documentSelected(.nationalId)
        await sut.continueTapped()

        XCTAssertTrue(mockRouter.navigateToDocumentIntroCalled)
        // Verify ValidationConfig was updated with selected values
        XCTAssertEqual(ValidationConfig.shared.documentConfig.country, "co")
        XCTAssertEqual(ValidationConfig.shared.documentConfig.documentType, "national-id")
    }

    func testCancelTapped_callsRouterHandleCancellation() async {
        let cameraChecker = MockCameraPermissionChecker(status: .authorized, requestAccessResult: nil)
        sut = DocumentSelectionPresenter(
            view: mockView,
            interactor: mockInteractor,
            router: mockRouter,
            cameraPermissionChecker: cameraChecker
        )

        await sut.cancelTapped()

        XCTAssertTrue(mockRouter.handleCancellationCalled)
    }
}

// MARK: - Mocks

@MainActor private final class MockDocumentSelectionView: DocumentSelectionPresenterToView {
    private(set) var setCountriesCalled = false
    private(set) var lastCountries: [NativeCountry]?

    private(set) var updateSelectionCalled = false
    private(set) var lastSelectedCountry: NativeCountry?
    private(set) var lastSelectedDocument: NativeDocumentType?

    private(set) var setErrorsCalled = false
    private(set) var lastIsCountryError: Bool?
    private(set) var lastIsDocumentError: Bool?

    private(set) var setLoadingCalled = false
    private(set) var lastIsLoading: Bool?

    private(set) var displayCameraPermissionAlertCalled = false

    private(set) var setCountryLockedCalled = false
    private(set) var lastIsCountryLocked: Bool?

    func setCountries(_ countries: [NativeCountry]) {
        setCountriesCalled = true
        lastCountries = countries
    }

    func updateSelection(selectedCountry: NativeCountry?, selectedDocument: NativeDocumentType?) {
        updateSelectionCalled = true
        lastSelectedCountry = selectedCountry
        lastSelectedDocument = selectedDocument
    }

    func setCountryLocked(_ isLocked: Bool) {
        setCountryLockedCalled = true
        lastIsCountryLocked = isLocked
    }

    func setErrors(isCountryError: Bool, isDocumentError: Bool) {
        setErrorsCalled = true
        lastIsCountryError = isCountryError
        lastIsDocumentError = isDocumentError
    }

    func setLoading(_ isLoading: Bool) {
        setLoadingCalled = true
        lastIsLoading = isLoading
    }

    func displayCameraPermissionAlert() {
        displayCameraPermissionAlertCalled = true
    }
}

@MainActor private final class MockDocumentSelectionInteractor: DocumentSelectionPresenterToInteractor {
    private(set) var fetchSupportedCountriesCalled = false

    func fetchSupportedCountries() {
        fetchSupportedCountriesCalled = true
    }
}

@MainActor private final class MockDocumentSelectionRouter: ValidationRouter {
    private(set) var handleCancellationCalled = false
    private(set) var navigateToDocumentIntroCalled = false

    override func handleCancellation() {
        handleCancellationCalled = true
    }

    override func navigateToDocumentIntro() throws {
        navigateToDocumentIntroCalled = true
    }
}

private struct MockCameraPermissionChecker: CameraPermissionChecking {
    let status: AVAuthorizationStatus
    let requestAccessResult: Bool?

    func authorizationStatus() -> AVAuthorizationStatus {
        status
    }

    func requestAccess(completion: @escaping (Bool) -> Void) {
        completion(requestAccessResult ?? false)
    }
}
