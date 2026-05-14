//
//  InvoiceFeedbackConfigurator.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 16/04/26.
//

import SwiftUI
import UIKit

enum InvoiceFeedbackConfigurator {
    @MainActor static func buildModule(
        router: ValidationRouter,
        feedback: FeedbackScenario,
        capturedImageData: Data?,
        retriesLeft: Int,
        retryBehavior: InvoiceFeedbackRetryBehavior = .dismissOnly
    ) -> UIViewController {
        let country = ValidationConfig.shared.invoiceConfig.country
        let viewModel = InvoiceFeedbackViewModel(
            feedback: feedback,
            capturedImageData: capturedImageData,
            retriesLeft: retriesLeft,
            country: country
        )

        let presenter = InvoiceFeedbackPresenter(
            view: viewModel,
            router: router,
            retryBehavior: retryBehavior
        )
        viewModel.presenter = presenter

        let config = ValidationConfig.shared.uiConfig
        let swiftUIView = InvoiceFeedbackView(
            viewModel: viewModel,
            config: config
        )
        .sdkLocaleEnvironment(locale: TruoraLocalization.currentLocale)
        let hostingController = UIHostingController(rootView: swiftUIView)
        hostingController.modalPresentationStyle = .fullScreen
        return hostingController
    }
}
