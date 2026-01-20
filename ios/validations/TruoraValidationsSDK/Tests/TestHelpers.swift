//
//  TestHelpers.swift
//  TruoraValidationsSDKTests
//
//  Created by Truora on 11/11/25.
//

import Foundation
@testable import TruoraValidationsSDK

// MARK: - Mock Response Builders

enum MockResponseBuilder {
    static func validationCreateResponse(
        validationId: String = "test-validation-id",
        accountId: String = "test-account-id",
        type: String = "face-validation",
        validationStatus: String = "pending",
        lifecycleStatus: String? = "active",
        threshold: Double? = 0.8,
        creationDate: String = "2025-01-01T00:00:00Z",
        ipAddress: String? = "127.0.0.1",
        details: ValidationDetails? = nil,
        instructions: ValidationInstructions? = nil
    ) -> ValidationCreateResponse {
        let json = """
        {
            "validation_id": "\(validationId)",
            "account_id": "\(accountId)",
            "type": "\(type)",
            "validation_status": "\(validationStatus)",
            \(lifecycleStatus.map { "\"lifecycle_status\": \"\($0)\"," } ?? "")
            \(threshold.map { "\"threshold\": \($0)," } ?? "")
            "creation_date": "\(creationDate)",
            \(ipAddress.map { "\"ip_address\": \"\($0)\"," } ?? "")
            \(details != nil ? "\"details\": {}," : "")
            \(instructions != nil ?
            "\"instructions\": {\"file_upload_link\": \"\(instructions!.fileUploadLink ?? "")\"}" :
            "\"instructions\": null")
        }
        """

        guard let data = json.data(using: .utf8) else {
            XCTFail("Failed to convert JSON string to Data for ValidationCreateResponse")
            return ValidationCreateResponse(
                validationId: "",
                accountId: "",
                type: "",
                validationStatus: "",
                lifecycleStatus: nil,
                threshold: nil,
                creationDate: "",
                ipAddress: nil,
                details: nil,
                instructions: nil
            )
        }
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(ValidationCreateResponse.self, from: data)
        } catch {
            XCTFail("Failed to decode ValidationCreateResponse: \(error)")
            return ValidationCreateResponse(
                validationId: "",
                accountId: "",
                type: "",
                validationStatus: "",
                lifecycleStatus: nil,
                threshold: nil,
                creationDate: "",
                ipAddress: nil,
                details: nil,
                instructions: nil
            )
        }
    }

    static func validationInstructions(
        fileUploadLink: String? = "https://example.com/upload"
    ) -> ValidationInstructions {
        let json = """
        {
            "file_upload_link": \(fileUploadLink.map { "\"\($0)\"" } ?? "null")
        }
        """

        guard let data = json.data(using: .utf8) else {
            XCTFail("Failed to convert JSON string to Data for ValidationInstructions")
            return ValidationInstructions(fileUploadLink: nil)
        }
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(ValidationInstructions.self, from: data)
        } catch {
            XCTFail("Failed to decode ValidationInstructions: \(error)")
            return ValidationInstructions(fileUploadLink: nil)
        }
    }
}

// MARK: - XCTestCase Extensions for iOS 13+ Async Testing

import XCTest

@available(iOS 13.0, *)
extension XCTestCase {
    /// Helper to run async tests in a synchronous test context for iOS 13-15 compatibility
    func runAsyncTest(
        timeout: TimeInterval = 5.0,
        _ block: @escaping () async throws -> Void
    ) {
        let expectation = self.expectation(description: "Async test")

        Task {
            do {
                try await block()
                expectation.fulfill()
            } catch {
                XCTFail("Async test failed with error: \(error)")
                expectation.fulfill()
            }
        }

        waitForExpectations(timeout: timeout)
    }
}
