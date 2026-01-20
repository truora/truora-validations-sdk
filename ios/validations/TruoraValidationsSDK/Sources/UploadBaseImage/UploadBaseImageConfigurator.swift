//
//  UploadBaseImageConfigurator.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 30/10/25.
//

import Foundation
import SwiftUI
import UIKit

class UploadBaseImageConfigurator {
    static func buildModule(router: ValidationRouter, enrollmentData: EnrollmentData) throws -> UIViewController {
        let viewModel = UploadBaseImageViewModel()

        let presenter = UploadBaseImagePresenter(
            view: viewModel,
            interactor: nil,
            router: router
        )

        let interactor = UploadBaseImageInteractor(
            presenter: presenter,
            enrollmentData: enrollmentData
        )

        viewModel.presenter = presenter
        presenter.interactor = interactor

        let swiftUIView = UploadBaseImageView(viewModel: viewModel)
        let hostingController = UIHostingController(rootView: swiftUIView)
        hostingController.modalPresentationStyle = .fullScreen

        return hostingController
    }
}
