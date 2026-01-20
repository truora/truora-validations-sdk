//
//  EnrollmentInteractor.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 30/10/25.
//

import Foundation
import TruoraShared

class EnrollmentInteractor {
    init() {}
}

extension EnrollmentInteractor {
    func createEnrollment(accountId: String) async throws -> EnrollmentData {
        print("🟢 EnrollmentInteractor: Creating enrollment...")

        guard let apiClient = ValidationConfig.shared.apiClient else {
            print("❌ EnrollmentInteractor: API client not configured")
            throw ValidationError.invalidConfiguration("API client not configured")
        }

        do {
            // Create enrollment request
            let request = EnrollmentRequest(
                type: "face-recognition",
                user_authorized: true,
                account_id: accountId,
                confirmation: nil
            )

            print("🟢 EnrollmentInteractor: Sending enrollment request for account: \(accountId)")

            // Call API
            let response = try await apiClient.enrollments.createEnrollment(
                formData: request.toFormData()
            )

            // Parse response
            let enrollmentResponse = try await SwiftKTORHelper.parseResponse(
                response,
                as: EnrollmentResponse.self
            )

            print(
                "🟢 EnrollmentInteractor: Enrollment created - ID: \(enrollmentResponse.enrollmentId)"
            )

            // Create enrollment data
            let enrollmentData = EnrollmentData(
                enrollmentId: enrollmentResponse.enrollmentId,
                accountId: enrollmentResponse.accountId,
                uploadUrl: enrollmentResponse.fileUploadLink,
                createdAt: Date()
            )

            return enrollmentData
        } catch {
            print("❌ EnrollmentInteractor: Enrollment creation failed: \(error)")
            throw ValidationError.apiError(error.localizedDescription)
        }
    }
}
