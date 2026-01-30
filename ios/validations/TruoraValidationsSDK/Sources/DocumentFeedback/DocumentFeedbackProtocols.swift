//
//  DocumentFeedbackProtocols.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 05/01/26.
//

import Foundation

// MARK: - View to Presenter

protocol DocumentFeedbackViewToPresenter: AnyObject {
    func viewDidLoad() async
    func retryTapped() async
    func tipsTapped() async
    func dismissed() async
}

// MARK: - Presenter to View

// Protocol for updating the document feedback view.
// Implementations should ensure UI updates are performed on the main thread.
