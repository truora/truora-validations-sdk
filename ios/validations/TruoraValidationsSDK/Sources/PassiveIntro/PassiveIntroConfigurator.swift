//
//  PassiveIntroConfigurator.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 31/10/25.
//

import Foundation
import SwiftUI
import UIKit

class PassiveIntroConfigurator {
    static func buildModule(
        router: ValidationRouter,
        enrollmentTask: Task<Void, Error>? = nil
    ) throws -> UIViewController {
        let viewModel = PassiveIntroViewModel()
        let interactor = PassiveIntroInteractor(presenter: nil, enrollmentTask: enrollmentTask)
        let presenter = PassiveIntroPresenter(
            view: viewModel,
            interactor: interactor,
            router: router
        )

        viewModel.presenter = presenter
        interactor.presenter = presenter

        let composeConfig = ValidationConfig.shared.composeConfig
        let swiftUIView = PassiveIntroView(
            viewModel: viewModel,
            composeConfig: composeConfig
        )
        let hostingController = UIHostingController(rootView: swiftUIView)

        return hostingController
    }
}
