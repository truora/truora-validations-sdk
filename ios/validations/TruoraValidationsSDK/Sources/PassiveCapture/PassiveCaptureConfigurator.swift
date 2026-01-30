//
//  PassiveCaptureConfigurator.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 30/10/25.
//

import Foundation
import SwiftUI
import UIKit

enum PassiveCaptureConfigurator {
    @MainActor static func buildModule(
        router: ValidationRouter,
        validationId: String
    ) throws -> UIViewController {
        let viewModel = PassiveCaptureViewModel()
        let useAutocapture = ValidationConfig.shared.faceConfig.useAutocapture

        let presenter = PassiveCapturePresenter(
            view: viewModel,
            interactor: nil,
            router: router,
            useAutocapture: useAutocapture
        )

        let interactor = PassiveCaptureInteractor(
            presenter: presenter,
            validationId: validationId
        )

        presenter.interactor = interactor
        viewModel.presenter = presenter

        let uiConfig = ValidationConfig.shared.uiConfig
        let swiftUIView = PassiveCaptureView(viewModel: viewModel, config: uiConfig)
        let hostingController = UIHostingController(rootView: swiftUIView)
        hostingController.view.backgroundColor = .clear // Ensure transparent background
        hostingController.modalPresentationStyle = .fullScreen

        return hostingController
    }
}
