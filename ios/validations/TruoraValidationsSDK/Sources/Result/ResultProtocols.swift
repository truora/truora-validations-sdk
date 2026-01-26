//
//  ResultProtocols.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 21/12/25.
//

import Foundation

// MARK: - View -> Presenter

protocol ResultViewToPresenter: AnyObject {
    func viewDidLoad()
    func doneTapped()
}

// MARK: - Presenter -> View

protocol ResultPresenterToView: AnyObject {
    func showLoading()
    func showResult(_ result: ValidationResult)
    func showCompleted()
    func setLoadingButtonState(_ isLoading: Bool)
}

// MARK: - Presenter -> Interactor

protocol ResultPresenterToInteractor: AnyObject {
    func startPolling()
    func cancelPolling()
}

// MARK: - Interactor -> Presenter

protocol ResultInteractorToPresenter: AnyObject {
    func pollingCompleted(result: ValidationResult)
    func pollingFailed(error: ValidationError)
}
