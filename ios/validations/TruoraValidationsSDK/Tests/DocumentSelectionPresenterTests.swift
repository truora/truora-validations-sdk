//
//  DocumentSelectionPresenterTests.swift
//  TruoraValidationsSDKTests
//
//  Created by Truora on 07/01/26.
//

import AVFoundation
import XCTest

import TruoraShared
@testable import TruoraValidationsSDK

final class DocumentSelectionPresenterTests: XCTestCase {
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

    func testViewDidLoad_fetchesCountries_andDoesNotShowAlertWhenAuthorized() {
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

        sut.viewDidLoad()

        XCTAssertTrue(mockInteractor.fetchSupportedCountriesCalled)
        XCTAssertFalse(mockView.displayCameraPermissionAlertCalled)
    }

    func testViewDidLoad_showsAlertWhenDenied() {
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

        sut.viewDidLoad()

        XCTAssertTrue(mockView.displayCameraPermissionAlertCalled)
    }

    func testContinueTapped_withoutSelections_setsErrorsAndDoesNotNavigate() {
        let cameraChecker = MockCameraPermissionChecker(status: .authorized, requestAccessResult: nil)
        sut = DocumentSelectionPresenter(
            view: mockView,
            interactor: mockInteractor,
            router: mockRouter,
            cameraPermissionChecker: cameraChecker
        )

        sut.continueTapped()

        XCTAssertTrue(mockView.setErrorsCalled)
        XCTAssertTrue(mockView.lastIsCountryError ?? false)
        XCTAssertTrue(mockView.lastIsDocumentError ?? false)
        XCTAssertFalse(mockRouter.navigateToDocumentIntroCalled)
    }

    func testContinueTapped_withSelections_butCameraNotAuthorized_showsAlertAndDoesNotNavigate() {
        let cameraChecker = MockCameraPermissionChecker(status: .denied, requestAccessResult: nil)
        sut = DocumentSelectionPresenter(
            view: mockView,
            interactor: mockInteractor,
            router: mockRouter,
            cameraPermissionChecker: cameraChecker
        )

        sut.countrySelected(.co)
        sut.documentSelected(.nationalId)
        sut.continueTapped()

        XCTAssertTrue(mockView.displayCameraPermissionAlertCalled)
        XCTAssertFalse(mockRouter.navigateToDocumentIntroCalled)
    }

    func testContinueTapped_withValidSelections_andCameraAuthorized_navigatesToDocumentIntroWithMappedValues() {
        let cameraChecker = MockCameraPermissionChecker(status: .authorized, requestAccessResult: nil)
        sut = DocumentSelectionPresenter(
            view: mockView,
            interactor: mockInteractor,
            router: mockRouter,
            cameraPermissionChecker: cameraChecker
        )
        sut.viewDidLoad()

        sut.countrySelected(.co)
        sut.documentSelected(.nationalId)
        sut.continueTapped()

        XCTAssertTrue(mockRouter.navigateToDocumentIntroCalled)
        // Verify ValidationConfig was updated with selected values
        XCTAssertEqual(ValidationConfig.shared.documentConfig.country, "CO")
        XCTAssertEqual(ValidationConfig.shared.documentConfig.documentType, "national-id")
    }

    func testCancelTapped_callsRouterHandleCancellation() {
        let cameraChecker = MockCameraPermissionChecker(status: .authorized, requestAccessResult: nil)
        sut = DocumentSelectionPresenter(
            view: mockView,
            interactor: mockInteractor,
            router: mockRouter,
            cameraPermissionChecker: cameraChecker
        )

        sut.cancelTapped()

        XCTAssertTrue(mockRouter.handleCancellationCalled)
    }
}

// MARK: - Mocks

private final class MockDocumentSelectionView: DocumentSelectionPresenterToView {
    private(set) var setCountriesCalled = false
    private(set) var lastCountries: [TruoraCountry]?

    private(set) var updateSelectionCalled = false
    private(set) var lastSelectedCountry: TruoraCountry?
    private(set) var lastSelectedDocument: TruoraDocumentType?

    private(set) var setErrorsCalled = false
    private(set) var lastIsCountryError: Bool?
    private(set) var lastIsDocumentError: Bool?

    private(set) var setLoadingCalled = false
    private(set) var lastIsLoading: Bool?

    private(set) var displayCameraPermissionAlertCalled = false

    func setCountries(_ countries: [TruoraCountry]) {
        setCountriesCalled = true
        lastCountries = countries
    }

    func updateSelection(selectedCountry: TruoraCountry?, selectedDocument: TruoraDocumentType?) {
        updateSelectionCalled = true
        lastSelectedCountry = selectedCountry
        lastSelectedDocument = selectedDocument
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

private final class MockDocumentSelectionInteractor: DocumentSelectionPresenterToInteractor {
    private(set) var fetchSupportedCountriesCalled = false

    func fetchSupportedCountries() {
        fetchSupportedCountriesCalled = true
    }
}

private final class MockDocumentSelectionRouter: ValidationRouter {
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
