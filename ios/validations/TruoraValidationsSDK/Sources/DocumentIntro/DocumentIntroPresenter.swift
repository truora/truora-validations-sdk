//
//  DocumentIntroPresenter.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 23/12/25.
//

import Foundation

class DocumentIntroPresenter {
    weak var view: DocumentIntroPresenterToView?
    var interactor: DocumentIntroPresenterToInteractor?
    weak var router: ValidationRouter?

    init(
        view: DocumentIntroPresenterToView,
        interactor: DocumentIntroPresenterToInteractor?,
        router: ValidationRouter
    ) {
        self.view = view
        self.interactor = interactor
        self.router = router
    }

    deinit {}
}

extension DocumentIntroPresenter: DocumentIntroViewToPresenter {
    func viewDidLoad() async {
        // Initial setup if needed
    }

    func startTapped() async {
        guard let accountId = ValidationConfig.shared.accountId else {
            await view?.showError("Missing account ID")
            return
        }

        guard let interactor else {
            await view?.showError("Interactor not configured")
            return
        }

        await view?.showLoading()
        interactor.createValidation(accountId: accountId)
    }

    func cancelTapped() async {
        await router?.handleCancellation()
    }
}

extension DocumentIntroPresenter: DocumentIntroInteractorToPresenter {
    func validationCreated(response: NativeValidationCreateResponse) async {
        guard let router else {
            await view?.hideLoading()
            await view?.showError("Router not configured")
            return
        }

        await view?.hideLoading()

        let validationId = response.validationId
        let frontUploadUrl = response.instructions?.frontUrl
        let reverseUploadUrl = response.instructions?.reverseUrl

        guard let frontUploadUrl, !frontUploadUrl.isEmpty else {
            await view?.showError("Missing front upload URL")
            return
        }

        do {
            try await router.navigateToDocumentCapture(
                validationId: validationId,
                frontUploadUrl: frontUploadUrl,
                reverseUploadUrl: reverseUploadUrl
            )
        } catch {
            await view?.showError(error.localizedDescription)
        }
    }

    func validationFailed(_ error: TruoraException) async {
        await view?.hideLoading()
        await router?.handleError(error)
    }
}
