//
//  ValidationRouter.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 30/10/25.
//

import AVFoundation
import Foundation
import MobileCoreServices
import ObjectiveC
import UIKit

// MARK: - Associated Object Key for Router Storage

private var routerAssociatedKey: UInt8 = 0
private var invoicePickerDelegateKey: UInt8 = 0

// MARK: - Validation Router

// The invoice navigation / feedback / file-picker methods live directly on the class
// body (instead of an `extension ValidationRouter`) so same-module test mocks can
// override them. Swift does not allow overriding methods declared in extensions of
// a same-module class unless they are `@objc`, and these methods' signatures
// (optional closures, async-throws, Swift protocol parameters) are not @objc-compatible.
// swiftlint:disable:next type_body_length
@MainActor class ValidationRouter {
    weak var navigationController: TruoraNavigationController?

    private var validationId: String?
    private var uploadUrl: String?
    private var frontUploadUrl: String?
    private var reverseUploadUrl: String?
    private var enrollmentTask: Task<Void, Error>?
    private weak var documentFeedbackViewController: UIViewController?
    private weak var invoiceFeedbackViewController: UIViewController?

    /// Raw bytes of the most recently uploaded/captured invoice file, retained so the
    /// Result → InvoiceFeedback transition can render a preview of what the user sent.
    /// For PDFs we store the rendered first-page PNG here (see `fileSelected`).
    var invoiceCapturedImageData: Data?

    /// `validation_id` of the most recent failed invoice validation that the user chose
    /// to retry. Set by `ResultPresenter` before navigating to `InvoiceFeedback`.
    /// Consumed (and cleared) by `InvoiceInstructionsPresenter.createValidation` when
    /// the user lands back on Instructions — it becomes the `retry_of_id` on the next
    /// `POST /validations` so the backend preserves `remaining_retries` across the chain
    /// and returns a fresh upload URL.
    var pendingInvoiceRetryValidationId: String?

    init(navigationController: TruoraNavigationController) {
        self.navigationController = navigationController
    }

    deinit {
        enrollmentTask?.cancel()
    }

    // MARK: - Navigation Methods

    func navigateToPassiveIntro() throws {
        guard let navController = navigationController else {
            throw TruoraException.sdk(SDKError(type: .internalError, details: "Navigation controller is nil"))
        }
        let passiveIntroViewController = try PassiveIntroConfigurator.buildModule(
            router: self
        )
        navController.pushViewController(passiveIntroViewController, animated: true)
    }

    func navigateToPassiveCapture(validationId: String, uploadUrl: String?) throws {
        guard let navController = navigationController else {
            throw TruoraException.sdk(SDKError(type: .internalError, details: "Navigation controller is nil"))
        }

        if let uploadUrl {
            try validateUploadUrl(uploadUrl, fieldDescription: "Upload URL")
        }
        self.validationId = validationId
        self.uploadUrl = uploadUrl
        let passiveCaptureViewController = try PassiveCaptureConfigurator.buildModule(
            router: self,
            validationId: validationId
        )
        navController.pushViewController(passiveCaptureViewController, animated: true)
    }

    func navigateToResult(
        validationId: String,
        loadingType: ResultLoadingType = .face,
        isCanceled: Bool = false
    ) throws {
        guard let navController = navigationController else {
            throw TruoraException.sdk(SDKError(type: .internalError, details: "Navigation controller is nil"))
        }
        let resultViewController = try ResultConfigurator.buildModule(
            router: self,
            validationId: validationId,
            loadingType: loadingType,
            isCanceled: isCanceled
        )
        navController.pushViewController(resultViewController, animated: true)
    }

    func navigateToDocumentIntro() throws {
        guard let navController = navigationController else {
            throw TruoraException.sdk(SDKError(type: .internalError, details: "Navigation controller is nil"))
        }
        let documentIntroViewController = try DocumentIntroConfigurator.buildModule(
            router: self
        )
        navController.pushViewController(documentIntroViewController, animated: true)
    }

    func navigateToDocumentSelection() throws {
        guard let navController = navigationController else {
            throw TruoraException.sdk(SDKError(type: .internalError, details: "Navigation controller is nil"))
        }

        let documentSelectionViewController = try DocumentSelectionConfigurator.buildModule(
            router: self
        )
        navController.pushViewController(documentSelectionViewController, animated: true)
    }

    func navigateToDocumentCapture(
        validationId: String,
        frontUploadUrl: String,
        reverseUploadUrl: String?
    ) throws {
        guard let navController = navigationController else {
            throw TruoraException.sdk(SDKError(type: .internalError, details: "Navigation controller is nil"))
        }

        try validateUploadUrl(frontUploadUrl, fieldDescription: "Front upload URL")
        if let reverseUploadUrl {
            try validateUploadUrl(reverseUploadUrl, fieldDescription: "Reverse upload URL")
        }

        self.validationId = validationId
        self.frontUploadUrl = frontUploadUrl
        self.reverseUploadUrl = reverseUploadUrl

        let documentCaptureViewController = try DocumentCaptureConfigurator.buildModule(
            router: self,
            validationId: validationId,
            frontUploadUrl: frontUploadUrl,
            reverseUploadUrl: reverseUploadUrl
        )
        navController.pushViewController(documentCaptureViewController, animated: true)
    }

    func navigateToDocumentFeedback(
        feedback: FeedbackScenario,
        capturedImageData: Data?,
        retriesLeft: Int
    ) throws {
        guard let navController = navigationController else {
            throw TruoraException.sdk(SDKError(type: .internalError, details: "Navigation controller is nil"))
        }
        let feedbackViewController = DocumentFeedbackConfigurator.buildModule(
            router: self,
            feedback: feedback,
            capturedImageData: capturedImageData,
            retriesLeft: retriesLeft
        )
        documentFeedbackViewController = feedbackViewController
        navController.present(feedbackViewController, animated: true)
    }

    func dismissDocumentFeedback(completion: (() -> Void)? = nil) {
        dismissPresentedFeedback(
            expected: documentFeedbackViewController,
            feedbackName: "DocumentFeedback",
            onDismissed: { [weak self] in self?.documentFeedbackViewController = nil },
            completion: completion
        )
    }

    func dismissFlow() {
        enrollmentTask?.cancel()
        enrollmentTask = nil
        guard let navController = navigationController else { return }
        // Dismiss from the nav's presenter (host app VC) so any modal currently
        // on top of the nav (e.g. InvoiceFeedback) is torn down alongside the
        // nav in a single animation. Calling `navController.dismiss(...)` with
        // a modal on top would only remove that modal and leave the nav (and
        // its Result "Verificando" screen) visible, stranding the user inside
        // the SDK.
        let dismisser = navController.presentingViewController ?? navController
        dismisser.dismiss(animated: true)
    }

    func handleError(_ error: TruoraException) {
        ValidationConfig.shared.delegate?(.error(error))
        dismissFlow()
    }

    /// Ends the flow with a completed (declined) result instead of surfacing an SDK error.
    func finishWithCompletedResult(_ result: ValidationResult) {
        ValidationConfig.shared.delegate?(.completed(result))
        dismissFlow()
    }

    func setEnrollmentTask(_ task: Task<Void, Error>?) {
        self.enrollmentTask = task
    }

    // MARK: - Single-Use Upload URL Accessors

    /// Consumes the upload URL, returning its value and clearing it so it cannot be reused.
    func consumeUploadUrl() -> String? {
        guard let url = uploadUrl else {
            debugLog("⚠️ ValidationRouter: Upload URL already consumed or never set")
            return nil
        }
        uploadUrl = nil
        debugLog("🔒 ValidationRouter: Upload URL consumed and cleared")
        return url
    }

    /// Consumes the front upload URL, returning its value and clearing it.
    func consumeFrontUploadUrl() -> String? {
        guard let url = frontUploadUrl else {
            debugLog("⚠️ ValidationRouter: Front upload URL already consumed or never set")
            return nil
        }
        frontUploadUrl = nil
        debugLog("🔒 ValidationRouter: Front upload URL consumed and cleared")
        return url
    }

    /// Consumes the reverse upload URL, returning its value and clearing it.
    func consumeReverseUploadUrl() -> String? {
        guard let url = reverseUploadUrl else {
            debugLog("⚠️ ValidationRouter: Reverse upload URL already consumed or never set")
            return nil
        }
        reverseUploadUrl = nil
        debugLog("🔒 ValidationRouter: Reverse upload URL consumed and cleared")
        return url
    }

    func handleCancellation(loadingType: ResultLoadingType) {
        presentCancelAlert(
            on: navigationController,
            missingPresenterMessage:
            "⚠️ ValidationRouter: Cannot present cancel alert - navigation controller not in view hierarchy"
        ) { [weak self] in
            guard let self else { return }
            self.enrollmentTask?.cancel()
            do {
                // Empty validationId is intentional for cancellation — Result shows
                // failure UI and notifies the delegate with `.canceled`.
                try self.navigateToResult(
                    validationId: "",
                    loadingType: loadingType,
                    isCanceled: true
                )
            } catch {
                debugLog("⚠️ ValidationRouter: Failed to navigate to cancel result: \(error)")
                ValidationConfig.shared.delegate?(.canceled(nil))
                self.dismissFlow()
            }
        }
    }

    // MARK: - Invoice Navigation

    func navigateToInvoiceInstructions() throws {
        guard let navController = navigationController else {
            throw TruoraException.sdk(SDKError(type: .internalError, details: "Navigation controller is nil"))
        }
        let invoiceInstructionsViewController = try InvoiceInstructionsConfigurator.buildModule(
            router: self
        )
        navController.pushViewController(invoiceInstructionsViewController, animated: true)
    }

    func navigateToInvoiceFeedback(
        feedback: FeedbackScenario,
        capturedImageData: Data?,
        retriesLeft: Int,
        retryBehavior: InvoiceFeedbackRetryBehavior = .dismissOnly
    ) throws {
        guard let navController = navigationController else {
            throw TruoraException.sdk(SDKError(type: .internalError, details: "Navigation controller is nil"))
        }
        let feedbackViewController = InvoiceFeedbackConfigurator.buildModule(
            router: self,
            feedback: feedback,
            capturedImageData: capturedImageData,
            retriesLeft: retriesLeft,
            retryBehavior: retryBehavior
        )
        invoiceFeedbackViewController = feedbackViewController
        navController.present(feedbackViewController, animated: true)
    }

    func dismissInvoiceFeedback(completion: (() -> Void)? = nil) {
        dismissPresentedFeedback(
            expected: invoiceFeedbackViewController,
            feedbackName: "InvoiceFeedback",
            onDismissed: { [weak self] in self?.invoiceFeedbackViewController = nil },
            completion: completion
        )
    }

    /// Dismiss InvoiceFeedback modal, then pop back to InvoiceInstructions.
    /// Used after polling detects a declined reason — the user retries from InvoiceInstructions.
    /// Nav stack is [InvoiceInstructions, Result]. Pops Result to land on InvoiceInstructions.
    ///
    /// Order matters: pop Result from the nav stack *before* dismissing the modal so the
    /// dismiss animation reveals Instructions directly. Reversing the order flashes the
    /// Result "Verificando" screen for the duration of the pop animation.
    func dismissInvoiceFeedbackAndPopToIntro() {
        navigationController?.popViewController(animated: false)
        dismissInvoiceFeedback(completion: nil)
    }

    /// Shows the "Cancelar validación" confirmation on top of the currently-presented
    /// InvoiceFeedback modal (not on the nav controller). Dismiss + navigate only happen
    /// if the user confirms — tapping "No, volver" keeps them on the feedback screen.
    ///
    /// On confirm we exit the SDK flow directly via `dismissFlow()` + `.canceled` delegate,
    /// skipping any intermediate screen. `dismissFlow()` handles the case where this
    /// feedback modal is still presented on top of the nav — it tears the whole SDK stack
    /// down from the nav's presenter in one animation.
    func handleInvoiceFeedbackCancellation() {
        presentCancelAlert(
            on: invoiceFeedbackViewController,
            missingPresenterMessage:
            "⚠️ ValidationRouter: Cannot present cancel alert — feedback VC not on screen"
        ) { [weak self] in
            guard let self else { return }
            // Clear retry state so any stray re-appear on Instructions doesn't
            // trigger a chained `retry_of_id` createValidation mid-cancel.
            self.pendingInvoiceRetryValidationId = nil
            self.invoiceCapturedImageData = nil
            self.enrollmentTask?.cancel()
            ValidationConfig.shared.delegate?(.canceled(nil))
            self.dismissFlow()
        }
    }

    /// Pops Result off the navigation stack so the user lands back on Instructions.
    /// Used by `InvoiceInstructionsPresenter` when the file upload fails and we want
    /// the user to be able to retry from the Instructions screen.
    ///
    /// Awaits the pop transition via `CATransaction` so callers can reliably show an
    /// alert or update state on Instructions *after* the animation finishes — without
    /// this, the error alert could try to present while Result was still visible or
    /// while the view backing Instructions had not re-rendered.
    func popToInvoiceInstructions() async {
        guard let navController = navigationController else { return }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            CATransaction.begin()
            CATransaction.setCompletionBlock {
                continuation.resume()
            }
            navController.popViewController(animated: true)
            CATransaction.commit()
        }
    }

    // MARK: - Invoice File Picker / Camera

    func presentInvoiceFilePicker(presenter: InvoiceInstructionsViewToPresenter) {
        guard let navController = navigationController else { return }

        let documentTypes = InvoiceFilePickerDelegate.supportedDocumentTypes
        let picker = UIDocumentPickerViewController(documentTypes: documentTypes, in: .import)
        let delegate = InvoiceFilePickerDelegate(presenter: presenter)
        // Retain delegate for the lifetime of the picker via associated object
        objc_setAssociatedObject(picker, &invoicePickerDelegateKey, delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        picker.delegate = delegate
        picker.allowsMultipleSelection = false
        navController.present(picker, animated: true)
    }

    func presentInvoiceCamera(presenter: InvoiceInstructionsViewToPresenter) {
        guard let navController = navigationController else { return }

        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            debugLog("⚠️ ValidationRouter: Camera not available on this device")
            Task { await presenter.pickerCancelled() }
            return
        }

        // UIImagePickerController doesn't surface a denied-permission error — it just
        // shows a black preview. Gate on AVCaptureDevice authorization so the user
        // gets the standard "Go to Settings" alert instead of a dead screen.
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            debugLog("🟢 ValidationRouter: Invoice camera authorized, presenting picker")
            presentInvoiceImagePicker(on: navController, presenter: presenter)
        case .notDetermined:
            debugLog("🟡 ValidationRouter: Invoice camera permission not determined, requesting access")
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if granted {
                        debugLog("🟢 ValidationRouter: Invoice camera permission granted, presenting picker")
                        self.presentInvoiceImagePicker(on: navController, presenter: presenter)
                    } else {
                        debugLog("⚠️ ValidationRouter: Invoice camera permission denied by user")
                        self.presentCameraPermissionDeniedAlert(on: navController, presenter: presenter)
                    }
                }
            }
        case .denied, .restricted:
            debugLog("⚠️ ValidationRouter: Invoice camera permission denied/restricted, showing settings alert")
            presentCameraPermissionDeniedAlert(on: navController, presenter: presenter)
        @unknown default:
            debugLog("⚠️ ValidationRouter: Unknown camera authorization status, cancelling")
            Task { await presenter.pickerCancelled() }
        }
    }
}

// MARK: - Private Helpers

/// Internal helpers shared by the routing methods. Kept in an extension so they
/// don't count toward `type_body_length` on the class — the class body is reserved
/// for the methods that same-module test mocks need to override.
private extension ValidationRouter {
    /// Presents the generic "Cancelar validación" confirmation alert on the given
    /// view controller. Runs `onConfirm` if the user taps confirm; logs and returns
    /// if the presenter isn't currently in the view hierarchy.
    func presentCancelAlert(
        on presenter: UIViewController?,
        missingPresenterMessage: String,
        onConfirm: @escaping () -> Void
    ) {
        guard let presenter, presenter.viewIfLoaded?.window != nil else {
            debugLog(missingPresenterMessage)
            return
        }
        let alert = UIAlertController(
            title: TruoraLocalization.string(forKey: LocalizationKeys.cancelAlertTitle),
            message: TruoraLocalization.string(forKey: LocalizationKeys.cancelAlertMessage),
            preferredStyle: .alert
        )
        alert.addAction(
            UIAlertAction(
                title: TruoraLocalization.string(forKey: LocalizationKeys.cancelAlertCancel),
                style: .cancel
            )
        )
        alert.addAction(
            UIAlertAction(
                title: TruoraLocalization.string(forKey: LocalizationKeys.cancelAlertConfirm),
                style: .default
            ) { _ in onConfirm() }
        )
        presenter.present(alert, animated: true)
    }

    /// Dismisses a modal feedback view iff it matches `expected`. Invokes
    /// `completion` either way — if nothing matches we skip the dismiss but still
    /// let the caller continue. `onDismissed` runs only on the real dismiss path
    /// and is where callers clear their weak reference.
    func dismissPresentedFeedback(
        expected: UIViewController?,
        feedbackName: String,
        onDismissed: @escaping () -> Void,
        completion: (() -> Void)?
    ) {
        guard let navController = navigationController,
              let presented = navController.presentedViewController else {
            completion?()
            return
        }
        guard let expected, presented === expected else {
            debugLog(
                "⚠️ ValidationRouter: Not dismissing presented VC because it is not \(feedbackName)"
            )
            completion?()
            return
        }
        presented.dismiss(animated: true) {
            onDismissed()
            completion?()
        }
    }

    /// Throws `invalidConfiguration` if `url` is empty or not a parseable absolute URL.
    func validateUploadUrl(_ url: String, fieldDescription: String) throws {
        guard !url.isEmpty, let parsed = URL(string: url), parsed.scheme != nil else {
            throw TruoraException.sdk(
                SDKError(type: .invalidConfiguration, details: "\(fieldDescription) is not valid")
            )
        }
    }

    func presentInvoiceImagePicker(
        on navController: UINavigationController,
        presenter: InvoiceInstructionsViewToPresenter
    ) {
        let imagePicker = UIImagePickerController()
        let delegate = InvoiceCameraDelegate(presenter: presenter)
        objc_setAssociatedObject(imagePicker, &invoicePickerDelegateKey, delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        imagePicker.delegate = delegate
        imagePicker.sourceType = .camera
        imagePicker.cameraCaptureMode = .photo
        navController.present(imagePicker, animated: true)
    }

    func presentCameraPermissionDeniedAlert(
        on navController: UINavigationController,
        presenter: InvoiceInstructionsViewToPresenter
    ) {
        let alert = UIAlertController(
            title: TruoraLocalization.string(forKey: LocalizationKeys.cameraPermissionDeniedTitle),
            message: TruoraLocalization.string(forKey: LocalizationKeys.cameraPermissionDeniedDescription),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(
            title: TruoraLocalization.string(forKey: LocalizationKeys.commonGoToSettings),
            style: .default
        ) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
            Task { await presenter.pickerCancelled() }
        })
        alert.addAction(UIAlertAction(
            title: TruoraLocalization.string(forKey: LocalizationKeys.commonCancel),
            style: .cancel
        ) { _ in
            Task { await presenter.pickerCancelled() }
        })
        navController.present(alert, animated: true)
    }
}

// MARK: - Factory Methods

extension ValidationRouter {
    @MainActor
    static func createRootNavigationController(of type: ValidationType) throws -> TruoraNavigationController {
        let navController = TruoraNavigationController()
        let router = ValidationRouter(navigationController: navController)

        // Store router as associated object to prevent deallocation
        objc_setAssociatedObject(
            navController,
            &routerAssociatedKey,
            router,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )

        guard ValidationConfig.shared.enrollmentData != nil else {
            throw TruoraException.sdk(SDKError(type: .internalError, details: "Enrollment data not configured"))
        }
        let viewController =
            switch type {
            case .face:
                try getPassiveIntroViewController(router: router)
            case .document:
                try getDocumentSelectionViewController(router: router)
            case .invoice:
                try getInvoiceInstructionsViewController(router: router)
            }

        navController.viewControllers = [viewController]
        navController.navigationBar.isHidden = false

        return navController
    }

    @MainActor
    static func createDocumentSelectionNavigationController() throws -> TruoraNavigationController {
        let navController = TruoraNavigationController()
        let router = ValidationRouter(navigationController: navController)

        // Store router as associated object to prevent deallocation
        objc_setAssociatedObject(
            navController,
            &routerAssociatedKey,
            router,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )

        let documentSelectionViewController = try DocumentSelectionConfigurator.buildModule(
            router: router
        )

        navController.viewControllers = [documentSelectionViewController]
        navController.navigationBar.isHidden = false

        return navController
    }

    /// Helper to retrieve router from navigation controller
    static func getRouter(from navigationController: TruoraNavigationController) -> ValidationRouter? {
        objc_getAssociatedObject(navigationController, &routerAssociatedKey) as? ValidationRouter
    }

    @MainActor
    static func presentFlow(
        navController: TruoraNavigationController,
        from presentingViewController: UIViewController
    ) throws {
        guard presentingViewController.viewIfLoaded?.window != nil else {
            throw TruoraException.sdk(
                SDKError(type: .internalError, details: "Cannot present: view is not in window hierarchy")
            )
        }

        guard presentingViewController.presentedViewController == nil else {
            throw TruoraException.sdk(
                SDKError(
                    type: .internalError,
                    details: """
                    Cannot present: view controller is already presenting another view. \
                    Dismiss the existing presented view controller before starting a new validation flow.
                    """
                )
            )
        }

        presentingViewController.present(navController, animated: true)
    }
}

// MARK: - Passive Intro View Controller

@MainActor private func getPassiveIntroViewController(router: ValidationRouter) throws -> UIViewController {
    let enrollmentTask = startReferenceFaceEnrollment()
    router.setEnrollmentTask(enrollmentTask)

    return try PassiveIntroConfigurator.buildModule(router: router, enrollmentTask: enrollmentTask)
}

// MARK: - Document Selection View Controller

@MainActor private func getDocumentSelectionViewController(
    router: ValidationRouter
) throws -> UIViewController {
    try DocumentSelectionConfigurator.buildModule(router: router)
}

// MARK: - Invoice Instructions View Controller

@MainActor private func getInvoiceInstructionsViewController(
    router: ValidationRouter
) throws -> UIViewController {
    try InvoiceInstructionsConfigurator.buildModule(router: router)
}

// MARK: - Reference Face Enrollment

private func startReferenceFaceEnrollment() -> Task<Void, Error>? {
    #if DEBUG
    if TruoraValidationsSDK.isOfflineMode {
        debugLog("⚠️ ValidationRouter: Offline mode, skipping reference face enrollment")
        return nil
    }
    #endif

    guard let accountId = ValidationConfig.shared.accountId, !accountId.isEmpty else {
        return nil
    }

    guard let referenceFace = ValidationConfig.shared.faceConfig.referenceFace else {
        return nil
    }

    guard let apiClient = ValidationConfig.shared.apiClient else {
        debugLog("❌ ValidationRouter: API client not configured")
        return nil
    }

    return Task {
        try await performEnrollment(
            accountId: accountId,
            referenceFace: referenceFace,
            apiClient: apiClient
        )
    }
}

private func performEnrollment(
    accountId: String,
    referenceFace: ReferenceFace,
    apiClient: TruoraAPIClient
) async throws {
    let request = NativeEnrollmentRequest(
        type: NativeValidationTypeEnum.faceRecognition.rawValue,
        userAuthorized: true,
        accountId: accountId,
        confirmation: nil
    )

    debugLog("🟢 ValidationRouter: Creating enrollment for account: \(accountId)")

    let enrollment: NativeEnrollmentResponse
    do {
        enrollment = try await apiClient.createEnrollment(request: request)
    } catch let error as TruoraAPIError {
        if case .serverError(statusCode: 409, _) = error {
            if let logger = try? TruoraLoggerImplementation.shared {
                await logger.logSdk(
                    eventName: "enrollment_already_exists",
                    level: .warning,
                    errorMessage: nil,
                    retention: .oneWeek,
                    metadata: ["account_id": accountId]
                )
            }
            return
        }
        throw error
    }

    guard !Task.isCancelled else {
        debugLog("⚠️ ValidationRouter: Enrollment task was cancelled")
        throw CancellationError()
    }

    debugLog("🟢 ValidationRouter: Enrollment created - ID: \(enrollment.enrollmentId)")

    guard let uploadUrl = enrollment.fileUploadLink else {
        throw TruoraException.network(message: "No file upload link in enrollment response", underlyingError: nil)
    }

    guard UploadUrlValidator.isTruoraFilesUploadUrl(uploadUrl) else {
        throw TruoraException.sdk(SDKError(type: .uploadFailed, details: "Invalid file upload link"))
    }

    try await uploadReferenceFaceFile(
        uploadUrl: uploadUrl,
        referenceFace: referenceFace,
        apiClient: apiClient
    )

    try await waitForEnrollmentReady(
        enrollmentId: enrollment.enrollmentId,
        apiClient: apiClient
    )
}

private func uploadReferenceFaceFile(
    uploadUrl: String,
    referenceFace: ReferenceFace,
    apiClient: TruoraAPIClient
) async throws {
    debugLog("🟢 ValidationRouter: Uploading reference face to presigned URL")

    // Read file data from URL
    let fileData: Data
    do {
        if referenceFace.url.isFileURL {
            fileData = try Data(contentsOf: referenceFace.url)
        } else {
            (fileData, _) = try await URLSession.shared.data(from: referenceFace.url)
        }
    } catch {
        throw TruoraException.sdk(SDKError(
            type: .internalError,
            details: "Failed to read reference face file: \(error.localizedDescription)"
        ))
    }

    // Determine content type from URL path extension
    let ext = referenceFace.url.pathExtension.lowercased()
    let contentType = ext == "png" ? "image/png" : "image/jpeg"

    try await apiClient.uploadFile(
        uploadUrl: uploadUrl,
        fileData: fileData,
        contentType: contentType
    )

    guard !Task.isCancelled else {
        debugLog("⚠️ ValidationRouter: Enrollment task was cancelled")
        return
    }

    debugLog("🟢 ValidationRouter: Reference face uploaded successfully")
    debugLog("✅ ValidationRouter: Reference face enrollment completed")
}

// MARK: - Enrollment Polling

/// Exponential backoff intervals for enrollment polling.
/// Starts at 500ms and doubles up to 8s (total ~30s).
private let enrollmentBackoffIntervals: [UInt64] = [
    500_000_000, // 0.5s
    1_000_000_000, // 1s
    2_000_000_000, // 2s
    4_000_000_000, // 4s
    8_000_000_000, // 8s
    8_000_000_000, // 8s
    8_000_000_000 // 8s
]

/// Polls the enrollment until it is ready for face validation.
///
/// The enrollment is considered ready when status is "pending" with reason
/// "waiting_face_validation" — meaning the reference face was processed and
/// the backend is waiting for the face validation to be created.
private func waitForEnrollmentReady(
    enrollmentId: String,
    apiClient: TruoraAPIClient
) async throws {
    for (attempt, interval) in enrollmentBackoffIntervals.enumerated() {
        guard !Task.isCancelled else {
            throw CancellationError()
        }

        let enrollment = try await apiClient.getEnrollment(enrollmentId: enrollmentId)
        let status = enrollment.status.lowercased()
        let reason = enrollment.reason?.lowercased() ?? ""
        let totalAttempts = enrollmentBackoffIntervals.count

        if reason == "waiting_face_validation" {
            debugLog(
                "🟢 ValidationRouter: Enrollment ready for face validation "
                    + "(attempt \(attempt + 1)/\(totalAttempts))"
            )
            return
        }

        if status == "failure" {
            throw TruoraException.network(
                message: "Enrollment failed with reason: \(enrollment.reason ?? "unknown")",
                underlyingError: nil
            )
        }

        // Still processing — wait with exponential backoff and retry
        let attemptNum = attempt + 1
        let log = "🟢 ValidationRouter: Enrollment status=\(status) "
            + "reason=\(reason) (\(attemptNum)/\(totalAttempts)), waiting..."
        debugLog(log)
        try await Task.sleep(nanoseconds: interval)
    }

    let total = enrollmentBackoffIntervals.count
    debugLog("⚠️ ValidationRouter: Enrollment not ready after \(total) attempts, proceeding")
}

// MARK: - Invoice File Picker Delegate

/// Handles UIDocumentPickerViewController callbacks for invoice file selection.
/// Retained via associated object on the picker for the duration of the presentation.
final class InvoiceFilePickerDelegate: NSObject, UIDocumentPickerDelegate {
    private weak var presenter: InvoiceInstructionsViewToPresenter?

    /// Max file size for image uploads (JPG / PNG / GIF / HEIC): 20 MB.
    static let maxImageFileSize = 20 * 1024 * 1024
    /// Max file size for document uploads (PDF / TXT / CSV / DOC / XLS / …): 100 MB.
    static let maxDocumentFileSize = 100 * 1024 * 1024

    /// Extensions treated as images for the 20 MB limit (kept in sync with the
    /// MIME switch in `contentType(for:)`).
    private static let imageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "gif", "heic", "heif"
    ]

    /// Supported UTI strings for invoice file upload: PDF plus any image type
    /// (`public.image` covers JPEG, PNG, HEIC, GIF, …).
    static let supportedDocumentTypes: [String] = [
        kUTTypePDF as String,
        kUTTypeImage as String
    ]

    /// Picks the right byte ceiling based on the file's extension — images cap at
    /// 20 MB (photos are never that big in practice), documents at 100 MB.
    static func maxFileSize(for url: URL) -> Int {
        let ext = url.pathExtension.lowercased()
        return imageExtensions.contains(ext) ? maxImageFileSize : maxDocumentFileSize
    }

    init(presenter: InvoiceInstructionsViewToPresenter) {
        self.presenter = presenter
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else {
            Task { await presenter?.pickerCancelled() }
            return
        }

        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: url)
            let maxSize = Self.maxFileSize(for: url)

            guard data.count <= maxSize else {
                let mb = maxSize / (1024 * 1024)
                debugLog("❌ InvoiceFilePicker: File exceeds \(mb)MB limit (\(data.count) bytes)")
                Task {
                    await presenter?.fileSelectionFailed(
                        message: "File exceeds the \(mb) MB limit. Please pick a smaller file."
                    )
                }
                return
            }

            let contentType = Self.contentType(for: url)
            Task { await presenter?.fileSelected(data: data, contentType: contentType) }
        } catch {
            debugLog("❌ InvoiceFilePicker: Failed to read file: \(error)")
            Task {
                await presenter?.fileSelectionFailed(
                    message: "Could not read the selected file. Please try again."
                )
            }
        }
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        Task { await presenter?.pickerCancelled() }
    }

    /// Determines content type from file extension.
    static func contentType(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "pdf": return "application/pdf"
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "gif": return "image/gif"
        case "csv": return "text/csv"
        case "txt": return "text/plain"
        case "doc": return "application/msword"
        case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "xls": return "application/vnd.ms-excel"
        case "xlsx": return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        default: return "application/octet-stream"
        }
    }
}

// MARK: - Invoice Camera Delegate

/// Handles UIImagePickerController callbacks for invoice photo capture.
/// Retained via associated object on the picker for the duration of the presentation.
final class InvoiceCameraDelegate: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    private weak var presenter: InvoiceInstructionsViewToPresenter?

    init(presenter: InvoiceInstructionsViewToPresenter) {
        self.presenter = presenter
    }

    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        picker.dismiss(animated: true)

        guard let image = info[.originalImage] as? UIImage,
              let jpegData = image.jpegData(compressionQuality: 0.85) else {
            debugLog("❌ InvoiceCamera: Failed to get image data")
            Task {
                await presenter?.fileSelectionFailed(
                    message: "Could not process the captured photo. Please try again."
                )
            }
            return
        }

        // Camera output is always a JPEG, so apply the 20 MB image ceiling
        // (same limit as picked JPG/PNG/HEIC files).
        let maxSize = InvoiceFilePickerDelegate.maxImageFileSize
        guard jpegData.count <= maxSize else {
            let mb = maxSize / (1024 * 1024)
            debugLog("❌ InvoiceCamera: Photo exceeds \(mb)MB limit (\(jpegData.count) bytes)")
            Task {
                await presenter?.fileSelectionFailed(
                    message: "Photo exceeds the \(mb) MB limit. Please try again."
                )
            }
            return
        }

        Task { await presenter?.fileSelected(data: jpegData, contentType: "image/jpeg") }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
        Task { await presenter?.pickerCancelled() }
    }
}

// MARK: - Test Helpers

#if DEBUG
extension ValidationRouter {
    func startReferenceFaceEnrollmentForTest() -> Task<Void, Error>? {
        startReferenceFaceEnrollment()
    }

    func getPassiveIntroViewControllerForTest() throws -> UIViewController {
        try getPassiveIntroViewController(router: self)
    }

    var invoiceFeedbackViewControllerForTest: UIViewController? {
        invoiceFeedbackViewController
    }

    func setUploadUrlForTest(_ url: String?) {
        uploadUrl = url
    }

    func setFrontUploadUrlForTest(_ url: String?) {
        frontUploadUrl = url
    }

    func setReverseUploadUrlForTest(_ url: String?) {
        reverseUploadUrl = url
    }
}
#endif
