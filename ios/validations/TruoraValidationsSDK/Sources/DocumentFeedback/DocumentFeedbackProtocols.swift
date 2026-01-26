//
//  DocumentFeedbackProtocols.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 05/01/26.
//

import Foundation

// MARK: - View to Presenter

protocol DocumentFeedbackViewToPresenter: AnyObject {
    func viewDidLoad()
    func retryTapped()
    func tipsTapped()
    func dismissed()
}

// MARK: - Presenter to View

protocol DocumentFeedbackPresenterToView: AnyObject {}
