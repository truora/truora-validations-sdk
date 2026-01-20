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
    func viewDidLoad() {
        // Initial setup if needed
    }

    func startTapped() {
        guard let accountId = ValidationConfig.shared.accountId else {
            view?.showError("Missing account ID")
            return
        }

        guard let interactor else {
            view?.showError("Interactor not configured")
            return
        }

        view?.showLoading()
        interactor.createValidation(accountId: accountId)
    }

    func cancelTapped() {
        router?.handleCancellation()
    }
}

extension DocumentIntroPresenter: DocumentIntroInteractorToPresenter {
    func validationCreated(response: ValidationCreateResponse) {
        guard let router else {
            view?.hideLoading()
            view?.showError("Router not configured")
            return
        }

        view?.hideLoading()

        let validationId = response.validationId
        let frontUploadUrl = response.instructions?.frontUrl
        let reverseUploadUrl = response.instructions?.reverseUrl

        guard let frontUploadUrl, !frontUploadUrl.isEmpty else {
            view?.showError("Missing front upload URL")
            return
        }

        do {
            try router.navigateToDocumentCapture(
                validationId: validationId,
                frontUploadUrl: frontUploadUrl,
                reverseUploadUrl: reverseUploadUrl
            )
        } catch {
            view?.showError(error.localizedDescription)
        }
    }

    func validationFailed(_ error: ValidationError) {
        view?.hideLoading()
        router?.handleError(error)
    }
}
