@MainActor protocol DocumentFeedbackPresenterToView: AnyObject {}
//
//  DocumentFeedbackPresenter.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 05/01/26.
//

import Foundation

final class DocumentFeedbackPresenter {
    weak var view: DocumentFeedbackPresenterToView?
    weak var router: ValidationRouter?

    init(
        view: DocumentFeedbackPresenterToView,
        router: ValidationRouter
    ) {
        self.view = view
        self.router = router
    }
}

extension DocumentFeedbackPresenter: DocumentFeedbackViewToPresenter {
    func viewDidLoad() async {
        // No-op for now
    }

    func retryTapped() async {
        await router?.dismissDocumentFeedback()
    }

    func tipsTapped() async {
        // No-op for now - tips functionality may be future work
    }

    func dismissed() async {
        await router?.dismissDocumentFeedback()
    }
}
