//
//  PassiveIntroProtocols.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 31/10/25.
//

import Foundation

// MARK: - View to Presenter

protocol PassiveIntroViewToPresenter: AnyObject {
    func viewDidLoad() async
    func startTapped() async
    func cancelTapped() async
}

// MARK: - Presenter to View

/// Protocol for updating the passive intro view.
/// Implementations should ensure UI updates are performed on the main thread.
@MainActor protocol PassiveIntroPresenterToView: AnyObject {
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
    func validationCreated(response: NativeValidationCreateResponse) async
    func validationFailed(_ error: TruoraException) async
}
