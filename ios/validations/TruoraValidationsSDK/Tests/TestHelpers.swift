//
//  TestHelpers.swift
//  TruoraValidationsSDKTests
//
//  Created by Truora on 11/11/25.
//

import Foundation
import XCTest
@testable import TruoraValidationsSDK

// MARK: - Mock Response Builders

enum MockResponseBuilder {
    static func validationCreateResponse(
        validationId: String = "test-validation-id",
        instructions: NativeValidationInstructions? = nil
    ) -> NativeValidationCreateResponse {
        NativeValidationCreateResponse(
            validationId: validationId,
            instructions: instructions
        )
    }

    static func validationInstructions(
        fileUploadLink: String? = "https://example.com/upload",
        frontUrl: String? = nil,
        reverseUrl: String? = nil
    ) -> NativeValidationInstructions {
        NativeValidationInstructions(
            fileUploadLink: fileUploadLink,
            frontUrl: frontUrl,
            reverseUrl: reverseUrl
        )
    }
}

// MARK: - XCTestCase Extensions for iOS 13+ Async Testing

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
