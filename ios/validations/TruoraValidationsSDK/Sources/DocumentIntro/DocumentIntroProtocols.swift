//
//  DocumentIntroProtocols.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 23/12/25.
//

import Foundation

// MARK: - View to Presenter

protocol DocumentIntroViewToPresenter: AnyObject {
    func viewDidLoad()
    func startTapped()
    func cancelTapped()
}

// MARK: - Presenter to View

protocol DocumentIntroPresenterToView: AnyObject {
    func showLoading()
    func hideLoading()
    func showError(_ message: String)
}

// MARK: - Presenter to Interactor

protocol DocumentIntroPresenterToInteractor: AnyObject {
    func createValidation(accountId: String)
}

// MARK: - Interactor to Presenter

protocol DocumentIntroInteractorToPresenter: AnyObject {
    func validationCreated(response: ValidationCreateResponse)
    func validationFailed(_ error: ValidationError)
}
