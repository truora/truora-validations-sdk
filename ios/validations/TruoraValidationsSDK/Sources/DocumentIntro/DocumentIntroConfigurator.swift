//
//  DocumentIntroConfigurator.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 23/12/25.
//

import Foundation
import SwiftUI
import UIKit

class DocumentIntroConfigurator {
    static func buildModule(
        router: ValidationRouter
    ) throws -> UIViewController {
        let documentConfig = ValidationConfig.shared.documentConfig
        guard !documentConfig.country.isEmpty else {
            throw ValidationError.internalError("Missing document country")
        }
        guard !documentConfig.documentType.isEmpty else {
            throw ValidationError.internalError("Missing document type")
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

        let composeConfig = ValidationConfig.shared.composeConfig
        let swiftUIView = DocumentIntroView(viewModel: viewModel, composeConfig: composeConfig)
        let hostingController = UIHostingController(rootView: swiftUIView)

        return hostingController
    }
}
