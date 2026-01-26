//
//  PassiveIntroPresenter.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 31/10/25.
//

import Foundation

class PassiveIntroPresenter {
    weak var view: PassiveIntroPresenterToView?
    var interactor: PassiveIntroPresenterToInteractor?
    weak var router: ValidationRouter?
    private var validationTask: Task<Void, Never>?

    init(
        view: PassiveIntroPresenterToView,
        interactor: PassiveIntroPresenterToInteractor?,
        router: ValidationRouter
    ) {
        self.view = view
        self.interactor = interactor
        self.router = router
    }

    deinit {
        validationTask?.cancel()
    }
}

extension PassiveIntroPresenter: PassiveIntroViewToPresenter {
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

        validationTask = Task { [weak self] in
            guard let self else { return }

            do {
                try await interactor.enrollmentCompleted()
                interactor.createValidation(accountId: accountId)
            } catch is CancellationError {
                // Task was cancelled - hide loading and exit gracefully
                print("⚠️ PassiveIntroPresenter: Enrollment was cancelled")
                await MainActor.run { [weak self] in
                    self?.view?.hideLoading()
                }
            } catch {
                print("❌ PassiveIntroPresenter: Enrollment failed: \(error)")
                await MainActor.run { [weak self] in
                    self?.view?.hideLoading()
                    self?.router?.handleError(
                        .apiError("Reference face enrollment failed: \(error.localizedDescription)")
                    )
                }
            }
        }
    }

    func cancelTapped() {
        validationTask?.cancel()
        router?.handleCancellation()
    }
}

extension PassiveIntroPresenter: PassiveIntroInteractorToPresenter {
    func validationCreated(response: ValidationCreateResponse) {
        guard let router else {
            view?.hideLoading()
            view?.showError("Router not configured")
            return
        }

        view?.hideLoading()

        do {
            let validationId = response.validationId
            let uploadUrl = response.instructions?.fileUploadLink

            try router.navigateToPassiveCapture(validationId: validationId, uploadUrl: uploadUrl)
        } catch {
            view?.showError(error.localizedDescription)
        }
    }

    func validationFailed(_ error: ValidationError) {
        view?.hideLoading()
        router?.handleError(error)
    }
}
