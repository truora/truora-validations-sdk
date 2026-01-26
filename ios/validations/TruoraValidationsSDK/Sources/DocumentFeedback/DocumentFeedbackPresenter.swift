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
    func viewDidLoad() {
        // No-op for now
    }

    func retryTapped() {
        router?.dismissDocumentFeedback()
    }

    func tipsTapped() {
        // No-op for now - tips functionality may be future work
    }

    func dismissed() {
        router?.dismissDocumentFeedback()
    }
}
