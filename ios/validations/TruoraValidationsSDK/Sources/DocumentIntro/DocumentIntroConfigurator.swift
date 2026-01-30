//
//  DocumentIntroConfigurator.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 23/12/25.
//

import Foundation
import SwiftUI
import UIKit

enum DocumentIntroConfigurator {
    @MainActor static func buildModule(
        router: ValidationRouter
    ) throws -> UIViewController {
        let documentConfig = ValidationConfig.shared.documentConfig
        guard !documentConfig.country.isEmpty else {
            throw TruoraException.sdk(SDKError(type: .invalidConfiguration, details: "Missing document country"))
        }
        guard !documentConfig.documentType.isEmpty else {
            throw TruoraException.sdk(SDKError(type: .invalidConfiguration, details: "Missing document type"))
        }

        let viewModel = DocumentIntroViewModel()

        let presenter = DocumentIntroPresenter(
            view: viewModel,
            interactor: nil,
            router: router
        )
        let interactor = DocumentIntroInteractor(
            presenter: presenter,
            country: documentConfig.country,
            documentType: documentConfig.documentType
        )

        viewModel.presenter = presenter
        presenter.interactor = interactor

        let config = ValidationConfig.shared.uiConfig
        let swiftUIView = DocumentIntroView(viewModel: viewModel, config: config)
        return UIHostingController(rootView: swiftUIView)
    }
}
