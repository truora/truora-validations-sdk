//
//  ResultProtocols.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 21/12/25.
//

import Foundation

// MARK: - View -> Presenter

protocol ResultViewToPresenter: AnyObject {
    func viewDidLoad() async
    func doneTapped() async
}

// MARK: - Presenter -> View

/// Protocol for updating the result view.
/// Implementations should ensure UI updates are performed on the main thread.
@MainActor protocol ResultPresenterToView: AnyObject {
    func showLoading()
    func showResult(_ result: ValidationResult)
    func showCompleted()
    func setLoadingButtonState(_ isLoading: Bool)
}

// MARK: - Presenter -> Interactor

protocol ResultPresenterToInteractor: AnyObject {
    var validationId: String { get }
    func startPolling()
    func cancelPolling()
}

// MARK: - Interactor -> Presenter

protocol ResultInteractorToPresenter: AnyObject {
    func pollingCompleted(result: ValidationResult) async
    func pollingFailed(error: TruoraException) async
}
