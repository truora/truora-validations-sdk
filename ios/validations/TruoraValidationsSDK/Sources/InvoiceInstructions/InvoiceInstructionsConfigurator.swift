//
//  InvoiceInstructionsConfigurator.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 16/04/26.
//

import Foundation
import SwiftUI
import UIKit

enum InvoiceInstructionsConfigurator {
    @MainActor static func buildModule(
        router: ValidationRouter
    ) throws -> UIViewController {
        let invoiceConfig = ValidationConfig.shared.invoiceConfig
        guard !invoiceConfig.country.isEmpty else {
            throw TruoraException.sdk(
                SDKError(type: .invalidConfiguration, details: "Missing invoice country")
            )
        }

        let viewModel = InvoiceInstructionsViewModel()

        let presenter = InvoiceInstructionsPresenter(
            view: viewModel,
            interactor: nil,
            router: router
        )

        let logger = try TruoraLoggerImplementation.shared
        let interactor = InvoiceInstructionsInteractor(
            presenter: presenter,
            country: invoiceConfig.country,
            logger: logger
        )

        viewModel.presenter = presenter
        presenter.interactor = interactor

        let config = ValidationConfig.shared.uiConfig
        let swiftUIView = InvoiceInstructionsView(
            viewModel: viewModel,
            config: config,
            country: invoiceConfig.country
        )
        .sdkLocaleEnvironment(locale: TruoraLocalization.currentLocale)
        return UIHostingController(rootView: swiftUIView)
    }
}
