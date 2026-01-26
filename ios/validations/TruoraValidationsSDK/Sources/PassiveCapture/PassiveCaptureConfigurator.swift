//
//  PassiveCaptureConfigurator.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 30/10/25.
//

import Foundation
import SwiftUI
import UIKit

class PassiveCaptureConfigurator {
    static func buildModule(router: ValidationRouter, validationId: String) throws -> UIViewController {
        let useAutocapture = ValidationConfig.shared.faceConfig.useAutocapture
        let viewModel = PassiveCaptureViewModel()

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

        viewModel.presenter = presenter
        presenter.interactor = interactor

        let composeConfig = ValidationConfig.shared.composeConfig
        let swiftUIView = PassiveCaptureView(
            viewModel: viewModel,
            composeConfig: composeConfig
        )
        let hostingController = UIHostingController(rootView: swiftUIView)
        hostingController.modalPresentationStyle = .fullScreen

        return hostingController
    }
}
