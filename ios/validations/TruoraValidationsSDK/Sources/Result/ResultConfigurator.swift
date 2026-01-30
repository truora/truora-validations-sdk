//
//  ResultConfigurator.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 21/12/25.
//

import SwiftUI
import UIKit

enum ResultConfigurator {
    @MainActor static func buildModule(
        router: ValidationRouter,
        validationId: String,
        loadingType: ResultLoadingType = .face
    ) throws -> UIViewController {
        let interactor = ResultInteractor(
            validationId: validationId,
            loadingType: loadingType
        )

        let viewModel = ResultViewModel()
        let presenter = ResultPresenter(
            view: viewModel,
            interactor: interactor,
            router: router,
            loadingType: loadingType
        )

        viewModel.presenter = presenter
        interactor.presenter = presenter

        let config = ValidationConfig.shared.uiConfig
        let swiftUIView = ResultView(viewModel: viewModel, config: config)
        let hostingController = UIHostingController(rootView: swiftUIView)
        hostingController.modalPresentationStyle = .fullScreen

        return hostingController
    }
}
