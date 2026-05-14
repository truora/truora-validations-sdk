//
//  InvoiceFeedbackProtocols.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 16/04/26.
//

import Foundation

// MARK: - View to Presenter

protocol InvoiceFeedbackViewToPresenter: AnyObject {
    func viewDidLoad() async
    func retryTapped() async
    func tipsTapped() async
    func dismissed() async
    func cancelTapped() async
}

// MARK: - Presenter to View

/// Protocol for updating the invoice feedback view.
/// Implementations should ensure UI updates are performed on the main thread.
@MainActor protocol InvoiceFeedbackPresenterToView: AnyObject {}
