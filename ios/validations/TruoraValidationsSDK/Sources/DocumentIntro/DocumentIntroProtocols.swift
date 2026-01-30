//
//  DocumentIntroProtocols.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 23/12/25.
//

import Foundation

// MARK: - View to Presenter

protocol DocumentIntroViewToPresenter: AnyObject {
    func viewDidLoad() async
    func startTapped() async
    func cancelTapped() async
}

// MARK: - Presenter to View

/// Protocol for updating the document intro view.
/// Implementations should ensure UI updates are performed on the main thread.
@MainActor protocol DocumentIntroPresenterToView: AnyObject {
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
    func validationCreated(response: NativeValidationCreateResponse) async
    func validationFailed(_ error: TruoraException) async
}
