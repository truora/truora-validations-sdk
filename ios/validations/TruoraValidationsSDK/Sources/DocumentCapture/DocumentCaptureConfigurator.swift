//
//  DocumentCaptureConfigurator.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 23/12/25.
//

import SwiftUI
import UIKit

class DocumentCaptureConfigurator {
    static func buildModule(
        router: ValidationRouter,
        validationId: String,
        frontUploadUrl: String,
        reverseUploadUrl: String?
    ) throws -> UIViewController {
        let viewModel = DocumentCaptureViewModel()

        let presenter = DocumentCapturePresenter(
            view: viewModel,
            interactor: nil,
            router: router,
            validationId: validationId
        )

        let interactor = DocumentCaptureInteractor(
            presenter: presenter
        )

        // Configure upload URLs immediately (presenter also validates via router on load).
        interactor.setUploadUrls(frontUploadUrl: frontUploadUrl, reverseUploadUrl: reverseUploadUrl)

        viewModel.presenter = presenter
        presenter.interactor = interactor

        let composeConfig = ValidationConfig.shared.composeConfig
        let swiftUIView = DocumentCaptureView(viewModel: viewModel, composeConfig: composeConfig)
        let hostingController = UIHostingController(rootView: swiftUIView)
        hostingController.modalPresentationStyle = .fullScreen
        return hostingController
    }
}
