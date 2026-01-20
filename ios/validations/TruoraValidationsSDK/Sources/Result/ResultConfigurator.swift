//
//  ResultConfigurator.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 30/10/25.
//

import Foundation
import SwiftUI
import TruoraShared
import UIKit

class ResultConfigurator {
    /// Builds the Result module with polling capability
    ///
    /// - Parameters:
    ///   - router: The validation router for navigation
    ///   - validationId: The ID of the validation to poll for
    /// - Returns: A configured UIViewController for the result screen
    static func buildModule(
        router: ValidationRouter,
        validationId: String,
        loadingType: LoadingType = .face
    ) throws -> UIViewController {
        let shouldWaitForResults = ValidationConfig.shared.faceConfig.shouldWaitForResults

        let viewModel = ResultViewModel(loadingType: loadingType)
        let presenter = ResultPresenter(
            validationId: validationId,
            loadingType: loadingType,
            shouldWaitForResults: shouldWaitForResults
        )
        let interactor = ResultInteractor(validationId: validationId, loadingType: loadingType)

        viewModel.presenter = presenter
        presenter.view = viewModel
        presenter.interactor = interactor
        presenter.router = router
        interactor.presenter = presenter

        let composeConfig = ValidationConfig.shared.composeConfig
        let swiftUIView = ResultView(viewModel: viewModel, composeConfig: composeConfig)
        let hostingController = UIHostingController(rootView: swiftUIView)

        return hostingController
    }
}
