//
//  ValidationRouter.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 30/10/25.
//

import Foundation
import ObjectiveC
import TruoraShared
import UIKit

// MARK: - Associated Object Key for Router Storage

private var routerAssociatedKey: UInt8 = 0

// MARK: - Validation Router

class ValidationRouter {
    weak var navigationController: UINavigationController?

    var enrollmentData: EnrollmentData?
    private var validationId: String?
    var uploadUrl: String?
    var frontUploadUrl: String?
    var reverseUploadUrl: String?
    private var enrollmentTask: Task<Void, Error>?
    private weak var documentFeedbackViewController: UIViewController?

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    deinit {
        enrollmentTask?.cancel()
    }

    // MARK: - Navigation Methods

    func navigateToUploadBaseImage(enrollmentData: EnrollmentData) throws {
        guard let navController = navigationController else {
            throw ValidationError.internalError("Navigation controller is nil")
        }
        self.enrollmentData = enrollmentData
        let uploadViewController = try UploadBaseImageConfigurator.buildModule(
            router: self,
            enrollmentData: enrollmentData
        )
        navController.pushViewController(uploadViewController, animated: true)
    }

    func navigateToEnrollmentStatus() throws {
        guard let navController = navigationController else {
            throw ValidationError.internalError("Navigation controller is nil")
        }
        guard let enrollmentData else {
            throw ValidationError.internalError("Missing enrollment data")
        }
        let statusViewController = try EnrollmentStatusConfigurator.buildModule(
            router: self,
            enrollmentData: enrollmentData
        )
        navController.pushViewController(statusViewController, animated: true)
    }

    func navigateToPassiveIntro() throws {
        guard let navController = navigationController else {
            throw ValidationError.internalError("Navigation controller is nil")
        }
        let passiveIntroViewController = try PassiveIntroConfigurator.buildModule(
            router: self
        )
        navController.pushViewController(passiveIntroViewController, animated: true)
    }

    func navigateToPassiveCapture(validationId: String, uploadUrl: String?) throws {
        guard let navController = navigationController else {
            throw ValidationError.internalError("Navigation controller is nil")
        }

        if let uploadUrl {
            guard !uploadUrl.isEmpty else {
                throw ValidationError.invalidConfiguration("Upload URL cannot be empty")
            }
            guard URL(string: uploadUrl) != nil else {
                throw ValidationError.invalidConfiguration("Upload URL is not valid")
            }
        }
        self.validationId = validationId
        self.uploadUrl = uploadUrl
        let passiveCaptureViewController = try PassiveCaptureConfigurator.buildModule(
            router: self,
            validationId: validationId
        )
        navController.pushViewController(passiveCaptureViewController, animated: true)
    }

    func navigateToResult(validationId: String, loadingType: LoadingType = .face) throws {
        guard let navController = navigationController else {
            throw ValidationError.internalError("Navigation controller is nil")
        }
        let resultViewController = try ResultConfigurator.buildModule(
            router: self,
            validationId: validationId,
            loadingType: loadingType
        )
        navController.pushViewController(resultViewController, animated: true)
    }

    func navigateToDocumentIntro() throws {
        guard let navController = navigationController else {
            throw ValidationError.internalError("Navigation controller is nil")
        }
        let documentIntroViewController = try DocumentIntroConfigurator.buildModule(
            router: self
        )
        navController.pushViewController(documentIntroViewController, animated: true)
    }

    func navigateToDocumentSelection() throws {
        guard let navController = navigationController else {
            throw ValidationError.internalError("Navigation controller is nil")
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
            throw ValidationError.internalError("Navigation controller is nil")
        }

        guard !frontUploadUrl.isEmpty, URL(string: frontUploadUrl) != nil else {
            throw ValidationError.invalidConfiguration("Front upload URL is not valid")
        }

        if let reverseUploadUrl {
            guard !reverseUploadUrl.isEmpty, URL(string: reverseUploadUrl) != nil else {
                throw ValidationError.invalidConfiguration("Reverse upload URL is not valid")
            }
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
            throw ValidationError.internalError("Navigation controller is nil")
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
        guard let navController = navigationController else {
            completion?()
            return
        }

        guard let presented = navController.presentedViewController else {
            completion?()
            return
        }

        guard let feedbackVC = documentFeedbackViewController, presented === feedbackVC else {
            print(
                "⚠️ ValidationRouter: Not dismissing presented VC because it is not DocumentFeedback"
            )
            completion?()
            return
        }

        presented.dismiss(animated: true) { [weak self] in
            self?.documentFeedbackViewController = nil
            completion?()
        }
    }

    func dismissFlow() {
        enrollmentTask?.cancel()
        enrollmentTask = nil
        navigationController?.dismiss(animated: true)
    }

    func handleError(_ error: ValidationError) {
        ValidationConfig.shared.delegate?(.failure(error))
        dismissFlow()
    }

    func setEnrollmentTask(_ task: Task<Void, Error>?) {
        self.enrollmentTask = task
    }

    func handleCancellation() {
        // Show alert
        guard let navController = navigationController,
              navController.viewIfLoaded?.window != nil else {
            print(
                "⚠️ ValidationRouter: Cannot present cancel alert - navigation controller not in view hierarchy"
            )
            return
        }

        let alert = UIAlertController(
            title: "Cancel validation",
            message: "You are about to cancel your current validation process",
            preferredStyle: .alert
        )
        alert.addAction(
            UIAlertAction(title: "OK", style: .default) { [weak self] _ in
                ValidationConfig.shared.delegate?(.failure(.cancelled))

                self?.dismissFlow()
            }
        )
        navController.present(alert, animated: true)
    }
}

// MARK: - Factory Methods

extension ValidationRouter {
    @MainActor
    static func createRootNavigationController() throws -> UINavigationController {
        let navController = UINavigationController()
        let router = ValidationRouter(navigationController: navController)

        // Store router as associated object to prevent deallocation
        objc_setAssociatedObject(
            navController,
            &routerAssociatedKey,
            router,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )

        guard let enrollmentData = ValidationConfig.shared.enrollmentData else {
            throw ValidationError.internalError("Enrollment data not configured")
        }

        // Conditionally start the flow
        let initialViewController: UIViewController =
            if enrollmentData.enrollmentId.isEmpty {
                // Skipped enrollment, go to passive intro
                try PassiveIntroConfigurator.buildModule(router: router)
            } else {
                // New enrollment, go to upload base image or enrollment status
                try UploadBaseImageConfigurator.buildModule(
                    router: router,
                    enrollmentData: enrollmentData
                )
            }
        navController.viewControllers = [initialViewController]
        navController.navigationBar.isHidden = false

        return navController
    }

    @MainActor
    static func createRootNavigationController(of type: ValidationType) throws -> UINavigationController {
        let navController = UINavigationController()
        let router = ValidationRouter(navigationController: navController)

        // Store router as associated object to prevent deallocation
        objc_setAssociatedObject(
            navController,
            &routerAssociatedKey,
            router,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )

        guard ValidationConfig.shared.enrollmentData != nil else {
            throw ValidationError.internalError("Enrollment data not configured")
        }
        let viewController: UIViewController =
            switch type {
            case .face:
                try getPassiveIntroViewController(router: router)
            case .document:
                try getDocumentSelectionViewController(router: router)
            }

        navController.viewControllers = [viewController]
        navController.navigationBar.isHidden = false

        return navController
    }

    @MainActor
    static func createDocumentSelectionNavigationController() throws -> UINavigationController {
        let navController = UINavigationController()
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

    // Helper to retrieve router from navigation controller
    static func getRouter(from navigationController: UINavigationController) -> ValidationRouter? {
        objc_getAssociatedObject(navigationController, &routerAssociatedKey) as? ValidationRouter
    }

    @MainActor
    static func presentFlow(
        navController: UINavigationController,
        from presentingViewController: UIViewController
    ) throws {
        guard presentingViewController.viewIfLoaded?.window != nil else {
            throw ValidationError.internalError("Cannot present: view is not in window hierarchy")
        }

        guard presentingViewController.presentedViewController == nil else {
            throw ValidationError.internalError("Cannot present: presenter is already presenting")
        }

        presentingViewController.present(navController, animated: true)
    }
}

// MARK: - Passive Intro View Controller

private func getPassiveIntroViewController(router: ValidationRouter) throws -> UIViewController {
    let enrollmentTask = startReferenceFaceEnrollment()
    router.setEnrollmentTask(enrollmentTask)

    return try PassiveIntroConfigurator.buildModule(router: router, enrollmentTask: enrollmentTask)
}

// MARK: - Document Selection View Controller

private func getDocumentSelectionViewController(
    router: ValidationRouter
) throws -> UIViewController {
    try DocumentSelectionConfigurator.buildModule(router: router)
}

// MARK: - Reference Face Enrollment

private func startReferenceFaceEnrollment() -> Task<Void, Error>? {
    guard let accountId = ValidationConfig.shared.accountId, !accountId.isEmpty else {
        print("⚠️ ValidationRouter: No account id configured, skipping enrollment")
        return nil
    }

    guard let referenceFace = ValidationConfig.shared.faceConfig.referenceFace else {
        print("⚠️ ValidationRouter: No reference face configured, skipping enrollment")
        return nil
    }

    guard let apiClient = ValidationConfig.shared.apiClient else {
        print("❌ ValidationRouter: API client not configured")
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
    apiClient: TruoraShared.TruoraValidations
) async throws {
    let request = TruoraShared.EnrollmentRequest(
        type: "face-recognition",
        user_authorized: true,
        account_id: accountId,
        confirmation: nil
    )

    print("🟢 ValidationRouter: Creating enrollment for account: \(accountId)")

    let enrollmentResponse = try await apiClient.enrollments.createEnrollment(
        formData: request.toFormData()
    )

    guard !Task.isCancelled else {
        print("⚠️ ValidationRouter: Enrollment task was cancelled")
        throw CancellationError()
    }

    let enrollment = try await SwiftKTORHelper.parseResponse(
        enrollmentResponse,
        as: EnrollmentResponse.self
    )

    print("🟢 ValidationRouter: Enrollment created - ID: \(enrollment.enrollmentId)")

    guard let uploadUrl = enrollment.fileUploadLink else {
        throw ValidationError.apiError("No file upload link in enrollment response")
    }

    try await uploadReferenceFaceFile(
        uploadUrl: uploadUrl,
        referenceFace: referenceFace,
        apiClient: apiClient
    )
}

private func uploadReferenceFaceFile(
    uploadUrl: String,
    referenceFace: ReferenceFace,
    apiClient: TruoraShared.TruoraValidations
) async throws {
    print("🟢 ValidationRouter: Uploading reference face to presigned URL")

    let fileHandle = TruoraShared.PlatformFileHandle(
        nsUrl: referenceFace.url,
        httpClient: nil as TruoraShared.Ktor_client_coreHttpClient?
    )

    let uploadResponse = try await apiClient.enrollments.uploadReferenceFace(
        uploadUrl: uploadUrl,
        file: fileHandle,
        contentType: nil
    )

    guard !Task.isCancelled else {
        print("⚠️ ValidationRouter: Enrollment task was cancelled")
        return
    }

    print(
        "🟢 ValidationRouter: Reference face uploaded successfully - Status: \(uploadResponse.status.value)"
    )

    await MainActor.run {
        print("✅ ValidationRouter: Reference face enrollment completed")
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
}
#endif
