//
//  DocumentSelectionConfigurator.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 07/01/26.
//

import Foundation
import SwiftUI
import UIKit

enum DocumentSelectionConfigurator {
    static func buildModule(
        router: ValidationRouter
    ) throws -> UIViewController {
        let viewModel = DocumentSelectionViewModel()

        let presenter = DocumentSelectionPresenter(
            view: viewModel,
            interactor: nil,
            router: router
        )

        let interactor = DocumentSelectionInteractor(presenter: presenter)

        viewModel.presenter = presenter
        presenter.interactor = interactor

        let swiftUIView = DocumentSelectionView(viewModel: viewModel)
        let hostingController = UIHostingController(rootView: swiftUIView)

        return hostingController
    }
}
