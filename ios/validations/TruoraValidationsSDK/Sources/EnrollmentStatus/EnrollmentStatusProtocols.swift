//
//  EnrollmentStatusProtocols.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 30/10/25.
//

import Foundation

// MARK: - View Protocol

protocol EnrollmentStatusPresenterToView: AnyObject {
    func showLoading()
    func hideLoading()
    func updateStatus(_ message: String)
    func showError(_ message: String)
}

// MARK: - Presenter Protocol

protocol EnrollmentStatusViewToPresenter: AnyObject {
    func viewDidLoad()
}

protocol EnrollmentStatusInteractorToPresenter: AnyObject {
    func enrollmentCheckCompleted(status: String)
    func enrollmentCheckFailed(error: String)
}

// MARK: - Interactor Protocol

protocol EnrollmentStatusPresenterToInteractor: AnyObject {
    func checkEnrollmentStatus(enrollmentId: String)
}
