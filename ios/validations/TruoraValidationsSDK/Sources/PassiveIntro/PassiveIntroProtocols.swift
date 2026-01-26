//
//  PassiveIntroProtocols.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 31/10/25.
//

import Foundation

// MARK: - View to Presenter

protocol PassiveIntroViewToPresenter: AnyObject {
    func viewDidLoad()
    func startTapped()
    func cancelTapped()
}

// MARK: - Presenter to View

protocol PassiveIntroPresenterToView: AnyObject {
    func showLoading()
    func hideLoading()
    func showError(_ message: String)
}

// MARK: - Presenter to Interactor

protocol PassiveIntroPresenterToInteractor: AnyObject {
    func createValidation(accountId: String)
    func enrollmentCompleted() async throws
}

// MARK: - Interactor to Presenter

protocol PassiveIntroInteractorToPresenter: AnyObject {
    func validationCreated(response: ValidationCreateResponse)
    func validationFailed(_ error: ValidationError)
}
