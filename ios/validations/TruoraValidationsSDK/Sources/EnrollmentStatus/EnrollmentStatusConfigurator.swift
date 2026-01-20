//
//  EnrollmentStatusConfigurator.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 30/10/25.
//

import Foundation
import SwiftUI
import UIKit

class EnrollmentStatusConfigurator {
    static func buildModule(router: ValidationRouter, enrollmentData: EnrollmentData) throws -> UIViewController {
        guard !enrollmentData.enrollmentId.isEmpty else {
            throw ValidationError.invalidConfiguration("Enrollment ID is required for status checking")
        }

        let viewModel = EnrollmentStatusViewModel()
        let interactor = EnrollmentStatusInteractor(presenter: nil)
        let presenter = EnrollmentStatusPresenter(
            view: viewModel,
            interactor: interactor,
            router: router,
            enrollmentId: enrollmentData.enrollmentId
        )

        viewModel.presenter = presenter
        interactor.presenter = presenter

        let swiftUIView = EnrollmentStatusView(viewModel: viewModel)
        let hostingController = UIHostingController(rootView: swiftUIView)
        hostingController.modalPresentationStyle = .fullScreen

        return hostingController
    }
}
