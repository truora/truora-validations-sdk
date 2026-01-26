//
//  DocumentFeedbackConfigurator.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 05/01/26.
//

import SwiftUI
import TruoraShared
import UIKit

enum DocumentFeedbackConfigurator {
    static func buildModule(
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

        let composeConfig = ValidationConfig.shared.composeConfig
        let swiftUIView = DocumentFeedbackView(
            viewModel: viewModel,
            composeConfig: composeConfig
        )
        let hostingController = UIHostingController(rootView: swiftUIView)
        hostingController.modalPresentationStyle = .fullScreen
        return hostingController
    }
}
