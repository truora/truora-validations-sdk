//
//  InvoiceFeedbackPresenter.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 16/04/26.
//

import Foundation

/// Controls what happens when the user taps "Volver a intentar" in InvoiceFeedback.
enum InvoiceFeedbackRetryBehavior {
    /// Dismiss the feedback modal only. Used when shown from InvoiceInstructions (image evaluation).
    /// User returns to InvoiceInstructions which is still in the nav stack.
    case dismissOnly
    /// Dismiss the feedback modal AND pop back to InvoiceInstructions.
    /// Used when shown from Result screen (polling declined reason).
    case popToInvoiceInstructions
}

final class InvoiceFeedbackPresenter {
    weak var view: InvoiceFeedbackPresenterToView?
    weak var router: ValidationRouter?
    private let retryBehavior: InvoiceFeedbackRetryBehavior

    init(
        view: InvoiceFeedbackPresenterToView,
        router: ValidationRouter,
        retryBehavior: InvoiceFeedbackRetryBehavior = .dismissOnly
    ) {
        self.view = view
        self.router = router
        self.retryBehavior = retryBehavior
    }
}

extension InvoiceFeedbackPresenter: InvoiceFeedbackViewToPresenter {
    func viewDidLoad() async {
        // No-op for now
    }

    func retryTapped() async {
        guard let router else { return }

        switch retryBehavior {
        case .dismissOnly:
            await router.dismissInvoiceFeedback()
        case .popToInvoiceInstructions:
            await router.dismissInvoiceFeedbackAndPopToIntro()
        }
    }

    func tipsTapped() async {
        // Tips handled by ViewModel's showTips toggle
    }

    func dismissed() async {
        guard let router else { return }

        // Mirror `retryTapped`: if the feedback was shown from the Result screen
        // (`.popToInvoiceInstructions`), swipe/gesture-dismiss must also pop Result
        // off the nav stack so the user lands on Instructions, not on a stale
        // "Verificando" screen. In practice the feedback modal is presented
        // fullScreen (no swipe-to-dismiss), so this is defensive in case the
        // presentation style changes.
        switch retryBehavior {
        case .dismissOnly:
            await router.dismissInvoiceFeedback()
        case .popToInvoiceInstructions:
            await MainActor.run { router.dismissInvoiceFeedbackAndPopToIntro() }
        }
    }

    func cancelTapped() async {
        guard let router else { return }

        // Present the confirmation alert on top of the feedback modal (not on the
        // nav controller) so the user stays on the feedback view if they tap
        // "No, volver". The modal only dismisses when they explicitly confirm.
        await MainActor.run { router.handleInvoiceFeedbackCancellation() }
    }
}
