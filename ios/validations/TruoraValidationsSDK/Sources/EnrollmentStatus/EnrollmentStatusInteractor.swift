//
//  EnrollmentStatusInteractor.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 30/10/25.
//

import Foundation
import TruoraShared

class EnrollmentStatusInteractor {
    weak var presenter: EnrollmentStatusInteractorToPresenter?

    init(presenter: EnrollmentStatusInteractorToPresenter?) {
        self.presenter = presenter
    }
}

// MARK: - EnrollmentStatusPresenterToInteractor

extension EnrollmentStatusInteractor: EnrollmentStatusPresenterToInteractor {
    func checkEnrollmentStatus(enrollmentId: String) {
        guard let apiClient = ValidationConfig.shared.apiClient else {
            presenter?.enrollmentCheckFailed(error: "API client not configured")
            return
        }

        Task {
            do {
                let response = try await apiClient.enrollments.getEnrollment(
                    enrollmentId: enrollmentId
                )
                let enrollment = try await SwiftKTORHelper.parseResponse(
                    response,
                    as: EnrollmentResponse.self
                )

                presenter?.enrollmentCheckCompleted(status: enrollment.status)
            } catch {
                presenter?.enrollmentCheckFailed(error: error.localizedDescription)
            }
        }
    }
}
