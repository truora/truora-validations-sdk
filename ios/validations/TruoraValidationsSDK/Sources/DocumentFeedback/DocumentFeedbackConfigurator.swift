//
//  DocumentFeedbackConfigurator.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 05/01/26.
//

import SwiftUI
import UIKit

enum DocumentFeedbackConfigurator {
    @MainActor static func buildModule(
        router: ValidationRouter,
        feedback: FeedbackScenario,
        capturedImageData: Data?,
        retriesLeft: Int
    ) -> UIViewController {
        let viewModel = DocumentFeedbackViewModel(
            feedback: feedback,
            capturedImageData: capturedImageData,
            retriesLeft: retriesLeft
        )

        let presenter = DocumentFeedbackPresenter(
            view: viewModel,
            router: router
        )
        viewModel.presenter = presenter

        let config = ValidationConfig.shared.uiConfig
        let swiftUIView = DocumentFeedbackView(
            viewModel: viewModel,
            config: config
        )
        let hostingController = UIHostingController(rootView: swiftUIView)
        hostingController.modalPresentationStyle = .fullScreen
        return hostingController
    }
}
