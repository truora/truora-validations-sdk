//
//  EnrollmentStatusPresenter.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 30/10/25.
//

import Foundation

class EnrollmentStatusPresenter {
    weak var view: EnrollmentStatusPresenterToView?
    var interactor: EnrollmentStatusPresenterToInteractor?
    weak var router: ValidationRouter?
    private let enrollmentId: String

    init(
        view: EnrollmentStatusPresenterToView?,
        interactor: EnrollmentStatusPresenterToInteractor?,
        router: ValidationRouter?,
        enrollmentId: String
    ) {
        self.view = view
        self.interactor = interactor
        self.router = router
        self.enrollmentId = enrollmentId
    }
}

// MARK: - EnrollmentStatusViewToPresenter

extension EnrollmentStatusPresenter: EnrollmentStatusViewToPresenter {
    func viewDidLoad() {
        view?.showLoading()
        interactor?.checkEnrollmentStatus(enrollmentId: enrollmentId)
    }
}

// MARK: - EnrollmentStatusInteractorToPresenter

extension EnrollmentStatusPresenter: EnrollmentStatusInteractorToPresenter {
    func enrollmentCheckCompleted(status: String) {
        view?.hideLoading()
        view?.updateStatus("Enrollment verified: \(status)")

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self else { return }
            do {
                guard let router = self.router else {
                    throw ValidationError.internalError("Router not configured")
                }
                try router.navigateToPassiveIntro()
            } catch {
                self.view?.showError("Navigation failed: \(error.localizedDescription)")
            }
        }
    }

    func enrollmentCheckFailed(error: String) {
        view?.hideLoading()
        view?.showError("Enrollment check failed: \(error)")
    }
}
