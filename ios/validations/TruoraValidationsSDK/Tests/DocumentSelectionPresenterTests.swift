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
        let navController = TruoraNavigationController()
        mockRouter = MockDocumentSelectionRouter(navigationController: navController)
    }

    override func tearDown() {
        sut = nil
        mockView = nil
        mockInteractor = nil
        mockRouter = nil
        try? ValidationConfig.shared.setValidation(.document(Document()))
        ValidationConfig.shared.reset()
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

    func testViewDidLoad_callsHandleErrorWhenDenied() async {
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

        XCTAssertTrue(mockRouter.handleErrorCalled)
        XCTAssertFalse(mockView.displayCameraPermissionAlertCalled)
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

    func testContinueTapped_withSelections_butCameraNotAuthorized_callsHandleErrorAndDoesNotNavigate() async {
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

        XCTAssertTrue(mockRouter.handleErrorCalled)
        XCTAssertFalse(mockView.displayCameraPermissionAlertCalled)
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

    // Note: Invalid configuration (finishViewConfig set with waitForResults disabled)
    // is prevented at the builder level via preconditionFailure in
    // waitForResults(false). The throw in ValidationConfig.setValidation
    // is a defense-in-depth measure that cannot be triggered through the
    // public builder API, so it is not directly testable here.

    func testContinueTapped_preservesFinishViewConfig() async throws {
        // Given — pre-configure documentConfig with finishViewConfig
        let finishConfig = FinishViewConfiguration(success: .hide, failure: .show)
        let preConfigured = Document()
            .setFinishViewConfiguration(finishConfig)
        try ValidationConfig.shared.setValidation(.document(preConfigured))

        let cameraChecker = MockCameraPermissionChecker(status: .authorized, requestAccessResult: nil)
        sut = DocumentSelectionPresenter(
            view: mockView,
            interactor: mockInteractor,
            router: mockRouter,
            cameraPermissionChecker: cameraChecker
        )
        await sut.viewDidLoad()

        // When
        await sut.countrySelected(.co)
        await sut.documentSelected(.nationalId)
        await sut.continueTapped()

        // Then — finishViewConfig should be preserved
        let docConfig = ValidationConfig.shared.documentConfig
        XCTAssertEqual(docConfig.country, "co")
        XCTAssertEqual(docConfig.documentType, "national-id")
        XCTAssertEqual(docConfig.finishViewConfig, finishConfig)
        XCTAssertTrue(docConfig.waitForResults)
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

    // MARK: - Single Country Preselection Tests

    func testViewDidLoad_withSingleCountry_preselectsAndLocksCountry() async throws {
        let config = Document().setCountry("PE")
        try ValidationConfig.shared.setValidation(.document(config))

        let cameraChecker = MockCameraPermissionChecker(status: .authorized, requestAccessResult: nil)
        sut = DocumentSelectionPresenter(
            view: mockView,
            interactor: mockInteractor,
            router: mockRouter,
            cameraPermissionChecker: cameraChecker
        )

        await sut.viewDidLoad()

        XCTAssertTrue(mockView.setCountryLockedCalled)
        XCTAssertTrue(mockView.lastIsCountryLocked ?? false)
        XCTAssertEqual(mockView.lastSelectedCountry, .pe)
    }

    func testViewDidLoad_withAllowedCountries_doesNotPreselectOrLock() async throws {
        let config = Document().setAllowedCountries("PE,CO,MX")
        try ValidationConfig.shared.setValidation(.document(config))

        let cameraChecker = MockCameraPermissionChecker(status: .authorized, requestAccessResult: nil)
        sut = DocumentSelectionPresenter(
            view: mockView,
            interactor: mockInteractor,
            router: mockRouter,
            cameraPermissionChecker: cameraChecker
        )

        await sut.viewDidLoad()

        XCTAssertNil(mockView.lastSelectedCountry)
        XCTAssertFalse(mockView.setCountryLockedCalled)
    }

    // MARK: - Single Document Type Preselection Tests

    func testViewDidLoad_withSingleDocumentType_preselectsAndLocksDocumentType() async throws {
        let config = Document()
            .setCountry("PE")
            .setDocumentType("national-id")
        try ValidationConfig.shared.setValidation(.document(config))

        let cameraChecker = MockCameraPermissionChecker(status: .authorized, requestAccessResult: nil)
        sut = DocumentSelectionPresenter(
            view: mockView,
            interactor: mockInteractor,
            router: mockRouter,
            cameraPermissionChecker: cameraChecker
        )

        await sut.viewDidLoad()

        XCTAssertTrue(mockView.setDocumentLockedCalled)
        XCTAssertTrue(mockView.lastIsDocumentLocked ?? false)
        XCTAssertEqual(mockView.lastSelectedDocument, .nationalId)
    }

    func testViewDidLoad_withAllowedDocumentTypes_doesNotPreselectOrLock() async throws {
        let config = Document()
            .setCountry("PE")
            .setAllowedDocumentTypes("national-id,foreign-id")
        try ValidationConfig.shared.setValidation(.document(config))

        let cameraChecker = MockCameraPermissionChecker(status: .authorized, requestAccessResult: nil)
        sut = DocumentSelectionPresenter(
            view: mockView,
            interactor: mockInteractor,
            router: mockRouter,
            cameraPermissionChecker: cameraChecker
        )

        await sut.viewDidLoad()

        XCTAssertNil(mockView.lastSelectedDocument)
    }

    func testCountrySelected_withSingleAllowedDocumentType_preselectsAndLocksDocumentType() async throws {
        let config = Document()
            .setAllowedDocumentTypes("national-id")
        try ValidationConfig.shared.setValidation(.document(config))

        let cameraChecker = MockCameraPermissionChecker(status: .authorized, requestAccessResult: nil)
        sut = DocumentSelectionPresenter(
            view: mockView,
            interactor: mockInteractor,
            router: mockRouter,
            cameraPermissionChecker: cameraChecker
        )
        await sut.viewDidLoad()

        await sut.countrySelected(.pe)

        XCTAssertTrue(mockView.setDocumentLockedCalled)
        XCTAssertTrue(mockView.lastIsDocumentLocked ?? false)
        XCTAssertEqual(mockView.lastSelectedDocument, .nationalId)
    }

    func testCountrySelected_withMultipleAllowedDocumentTypes_resetsDocumentLock() async throws {
        let config = Document()
            .setAllowedDocumentTypes("national-id,foreign-id")
        try ValidationConfig.shared.setValidation(.document(config))

        let cameraChecker = MockCameraPermissionChecker(status: .authorized, requestAccessResult: nil)
        sut = DocumentSelectionPresenter(
            view: mockView,
            interactor: mockInteractor,
            router: mockRouter,
            cameraPermissionChecker: cameraChecker
        )
        await sut.viewDidLoad()

        await sut.countrySelected(.pe)

        XCTAssertFalse(mockView.lastIsDocumentLocked ?? true)
    }

    // MARK: - Priority Tests (allowed fields over legacy fields)

    func testViewDidLoad_withSingleAllowedCountry_hasHigherPriorityThanCountry() async throws {
        let config = Document()
            .setCountry("MX")
            .setAllowedCountries("CO")
        try ValidationConfig.shared.setValidation(.document(config))

        let cameraChecker = MockCameraPermissionChecker(status: .authorized, requestAccessResult: nil)
        sut = DocumentSelectionPresenter(
            view: mockView,
            interactor: mockInteractor,
            router: mockRouter,
            cameraPermissionChecker: cameraChecker
        )

        await sut.viewDidLoad()

        XCTAssertTrue(mockView.setCountryLockedCalled)
        XCTAssertTrue(mockView.lastIsCountryLocked ?? false)
        XCTAssertEqual(mockView.lastSelectedCountry, .co, "allowedCountries should have priority over country")
    }

    func testViewDidLoad_withSingleAllowedDocumentType_hasHigherPriorityThanDocumentType() async throws {
        let config = Document()
            .setCountry("PE")
            .setDocumentType("passport")
            .setAllowedDocumentTypes("national-id")
        try ValidationConfig.shared.setValidation(.document(config))

        let cameraChecker = MockCameraPermissionChecker(status: .authorized, requestAccessResult: nil)
        sut = DocumentSelectionPresenter(
            view: mockView,
            interactor: mockInteractor,
            router: mockRouter,
            cameraPermissionChecker: cameraChecker
        )

        await sut.viewDidLoad()

        XCTAssertTrue(mockView.setDocumentLockedCalled)
        XCTAssertTrue(mockView.lastIsDocumentLocked ?? false)
        XCTAssertEqual(mockView.lastSelectedDocument, .nationalId, "allowedDocumentTypes should have priority over documentType")
    }

    func testViewDidLoad_withLegacyCountry_worksAsFallback() async throws {
        let config = Document()
            .setCountry("PE")
        try ValidationConfig.shared.setValidation(.document(config))

        let cameraChecker = MockCameraPermissionChecker(status: .authorized, requestAccessResult: nil)
        sut = DocumentSelectionPresenter(
            view: mockView,
            interactor: mockInteractor,
            router: mockRouter,
            cameraPermissionChecker: cameraChecker
        )

        await sut.viewDidLoad()

        XCTAssertTrue(mockView.setCountryLockedCalled)
        XCTAssertTrue(mockView.lastIsCountryLocked ?? false)
        XCTAssertEqual(mockView.lastSelectedCountry, .pe, "country should work as fallback when allowedCountries is empty")
    }

    func testViewDidLoad_withLegacyDocumentType_worksAsFallback() async throws {
        let config = Document()
            .setCountry("PE")
            .setDocumentType("national-id")
        try ValidationConfig.shared.setValidation(.document(config))

        let cameraChecker = MockCameraPermissionChecker(status: .authorized, requestAccessResult: nil)
        sut = DocumentSelectionPresenter(
            view: mockView,
            interactor: mockInteractor,
            router: mockRouter,
            cameraPermissionChecker: cameraChecker
        )

        await sut.viewDidLoad()

        XCTAssertTrue(mockView.setDocumentLockedCalled)
        XCTAssertTrue(mockView.lastIsDocumentLocked ?? false)
        XCTAssertEqual(mockView.lastSelectedDocument, .nationalId, "documentType should work as fallback when allowedDocumentTypes is empty")
    }

    // MARK: - Fixed Selection (Unified Screen) Tests

    func testViewDidLoad_withFixedSelection_setsSelectionFixed() async throws {
        let config = Document()
            .setAllowedCountries("CO")
            .setAllowedDocumentTypes("national-id")
        try ValidationConfig.shared.setValidation(.document(config))

        let cameraChecker = MockCameraPermissionChecker(status: .authorized, requestAccessResult: nil)
        sut = DocumentSelectionPresenter(
            view: mockView,
            interactor: mockInteractor,
            router: mockRouter,
            cameraPermissionChecker: cameraChecker
        )

        await sut.viewDidLoad()

        XCTAssertTrue(mockView.setSelectionFixedCalled, "Fixed unified screen should be signalled when both country and document are locked")
        XCTAssertTrue(mockView.lastIsSelectionFixed ?? false)
    }

    func testContinueTapped_withFixedSelection_callsCreateValidation() async throws {
        try await ValidationConfig.shared.configure(apiKey: "test-key", accountId: "acc-123")
        let config = Document()
            .setAllowedCountries("CO")
            .setAllowedDocumentTypes("national-id")
        try ValidationConfig.shared.setValidation(.document(config))

        let cameraChecker = MockCameraPermissionChecker(status: .authorized, requestAccessResult: nil)
        sut = DocumentSelectionPresenter(
            view: mockView,
            interactor: mockInteractor,
            router: mockRouter,
            cameraPermissionChecker: cameraChecker
        )

        await sut.viewDidLoad()

        let fakeResponse = NativeValidationCreateResponse(
            validationId: "v123",
            instructions: NativeValidationInstructions(
                fileUploadLink: nil,
                frontUrl: "https://upload.example.com/front",
                reverseUrl: nil
            )
        )
        mockInteractor.createValidationResult = .success(fakeResponse)

        await sut.continueTapped()

        XCTAssertTrue(mockView.setLoadingCalled, "Should show loading while creating validation")
        XCTAssertFalse(mockView.lastIsLoading ?? true, "Should hide loading after validation created")
    }

    func testContinueTapped_withFixedSelection_navigatesToCapture() async throws {
        try await ValidationConfig.shared.configure(apiKey: "test-key", accountId: "acc-123")
        let config = Document()
            .setAllowedCountries("CO")
            .setAllowedDocumentTypes("national-id")
        try ValidationConfig.shared.setValidation(.document(config))

        let cameraChecker = MockCameraPermissionChecker(status: .authorized, requestAccessResult: nil)
        sut = DocumentSelectionPresenter(
            view: mockView,
            interactor: mockInteractor,
            router: mockRouter,
            cameraPermissionChecker: cameraChecker
        )

        await sut.viewDidLoad()

        let fakeResponse = NativeValidationCreateResponse(
            validationId: "v123",
            instructions: NativeValidationInstructions(
                fileUploadLink: nil,
                frontUrl: "https://upload.example.com/front",
                reverseUrl: nil
            )
        )
        mockInteractor.createValidationResult = .success(fakeResponse)

        await sut.continueTapped()

        XCTAssertFalse(mockRouter.navigateToDocumentIntroCalled, "Intro should be skipped for fixed selection")
        XCTAssertTrue(mockRouter.navigateToDocumentCaptureCalled, "Should navigate directly to capture")
    }

    func testContinueTapped_withFixedSelection_whenCreateValidationThrows_resetsLoadingAndRoutesError() async throws {
        try await ValidationConfig.shared.configure(apiKey: "test-key", accountId: "acc-123")
        let config = Document()
            .setAllowedCountries("CO")
            .setAllowedDocumentTypes("national-id")
        try ValidationConfig.shared.setValidation(.document(config))

        let cameraChecker = MockCameraPermissionChecker(status: .authorized, requestAccessResult: nil)
        sut = DocumentSelectionPresenter(
            view: mockView,
            interactor: mockInteractor,
            router: mockRouter,
            cameraPermissionChecker: cameraChecker
        )
        await sut.viewDidLoad()

        mockInteractor.createValidationResult = .failure(
            TruoraException.network(message: "timeout")
        )

        await sut.continueTapped()

        XCTAssertTrue(mockView.setLoadingCalled)
        XCTAssertFalse(mockView.lastIsLoading ?? true, "Loading should be hidden after failure")
        XCTAssertTrue(mockRouter.handleErrorCalled, "Error should be routed on validation failure")
        XCTAssertFalse(mockRouter.navigateToDocumentCaptureCalled)
    }

    func testContinueTapped_withFixedSelection_whenFrontUrlMissing_routesError() async throws {
        try await ValidationConfig.shared.configure(apiKey: "test-key", accountId: "acc-123")
        let config = Document()
            .setAllowedCountries("CO")
            .setAllowedDocumentTypes("national-id")
        try ValidationConfig.shared.setValidation(.document(config))

        let cameraChecker = MockCameraPermissionChecker(status: .authorized, requestAccessResult: nil)
        sut = DocumentSelectionPresenter(
            view: mockView,
            interactor: mockInteractor,
            router: mockRouter,
            cameraPermissionChecker: cameraChecker
        )
        await sut.viewDidLoad()

        let responseWithNoFrontUrl = NativeValidationCreateResponse(
            validationId: "v123",
            instructions: NativeValidationInstructions(
                fileUploadLink: nil,
                frontUrl: "",
                reverseUrl: nil
            )
        )
        mockInteractor.createValidationResult = .success(responseWithNoFrontUrl)

        await sut.continueTapped()

        XCTAssertFalse(mockView.lastIsLoading ?? true, "Loading should be hidden")
        XCTAssertTrue(mockRouter.handleErrorCalled, "Missing front URL should route an error")
        XCTAssertFalse(mockRouter.navigateToDocumentCaptureCalled)
    }

    func testViewDidLoad_withFixedSelection_setsLoadedImageStateWhenUrlReturned() async throws {
        let config = Document()
            .setAllowedCountries("CO")
            .setAllowedDocumentTypes("national-id")
        try ValidationConfig.shared.setValidation(.document(config))

        let cameraChecker = MockCameraPermissionChecker(status: .authorized, requestAccessResult: nil)
        mockInteractor.fetchDocumentExampleURL = URL(string: "https://example.com/doc.png")
        sut = DocumentSelectionPresenter(
            view: mockView,
            interactor: mockInteractor,
            router: mockRouter,
            cameraPermissionChecker: cameraChecker
        )

        await sut.viewDidLoad()

        XCTAssertEqual(
            mockView.lastDocumentImageState,
            try .loaded(XCTUnwrap(URL(string: "https://example.com/doc.png"))),
            "Should set .loaded state when interactor returns a URL"
        )
    }

    func testContinueTapped_withNonFixedSelection_navigatesToIntro() async throws {
        let config = Document()
            .setAllowedCountries("CO,MX")
        try ValidationConfig.shared.setValidation(.document(config))

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

        XCTAssertTrue(mockRouter.navigateToDocumentIntroCalled, "Non-fixed selection should navigate to Intro as before")
        XCTAssertFalse(mockRouter.navigateToDocumentCaptureCalled)
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

    private(set) var setDocumentLockedCalled = false
    private(set) var lastIsDocumentLocked: Bool?

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

    func setDocumentLocked(_ isLocked: Bool) {
        setDocumentLockedCalled = true
        lastIsDocumentLocked = isLocked
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

    private(set) var setSelectionFixedCalled = false
    private(set) var lastIsSelectionFixed: Bool?

    func setSelectionFixed(_ isFixed: Bool) {
        setSelectionFixedCalled = true
        lastIsSelectionFixed = isFixed
    }

    private(set) var lastDocumentImageState: DocumentImageState?

    func setDocumentImageState(_ state: DocumentImageState) {
        lastDocumentImageState = state
    }
}

private final class MockDocumentSelectionInteractor: @preconcurrency DocumentSelectionPresenterToInteractor {
    private(set) var fetchSupportedCountriesCalled = false
    var createValidationResult: Result<NativeValidationCreateResponse, Error>?
    var fetchDocumentExampleURL: URL?

    func fetchSupportedCountries() {
        fetchSupportedCountriesCalled = true
    }

    func logViewRendered() async {}

    func logContinueButtonClicked(selectedCountry: NativeCountry?, selectedDocument: NativeDocumentType?) async {}

    func logCancelButtonClicked() async {}

    func createValidation(accountId: String) async throws -> NativeValidationCreateResponse {
        switch createValidationResult {
        case .success(let response): return response
        case .failure(let error): throw error
        case .none: throw TruoraException.sdk(SDKError(type: .internalError))
        }
    }

    func fetchDocumentExample(country: String, documentType: String) async -> URL? {
        fetchDocumentExampleURL
    }
}

@MainActor private final class MockDocumentSelectionRouter: ValidationRouter {
    private(set) var handleCancellationCalled = false
    private(set) var navigateToDocumentIntroCalled = false
    private(set) var navigateToDocumentCaptureCalled = false
    private(set) var handleErrorCalled = false

    override func handleCancellation(loadingType: ResultLoadingType) {
        handleCancellationCalled = true
    }

    override func navigateToDocumentIntro() throws {
        navigateToDocumentIntroCalled = true
    }

    override func navigateToDocumentCapture(
        validationId: String,
        frontUploadUrl: String,
        reverseUploadUrl: String?
    ) throws {
        navigateToDocumentCaptureCalled = true
    }

    override func handleError(_ error: TruoraException) {
        handleErrorCalled = true
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
