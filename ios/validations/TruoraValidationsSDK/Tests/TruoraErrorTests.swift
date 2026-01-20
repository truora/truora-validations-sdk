//
//  TruoraErrorTests.swift
//  SDKTests
//
//  Created by Brayan Escobar on 10/11/25.
//

import XCTest
@testable import TruoraValidationsSDK

final class TruoraErrorTests: XCTestCase {
    func testInitialization() {
        let description = "Some cool description"
        let currentValidation = "face-recognition"
        let type = "network"
        let code = "1234"

        let error = TruoraError(
            description: description,
            currentValidation: currentValidation,
            type: type,
            code: code
        )

        XCTAssertEqual(error.description, description)
        XCTAssertEqual(error.currentValidation, currentValidation)
        XCTAssertEqual(error.type, type)
        XCTAssertEqual(error.code, code)
    }

    // MARK: - Error Protocol Tests

    func testConformsToErrorProtocol() {
        let error = TruoraError(
            description: "Test error",
            currentValidation: "face",
            type: "system",
            code: "1234"
        )

        let asError: Error = error

        XCTAssertTrue(asError is TruoraError)
    }

    func testCanBeThrownAndCaught() {
        let error = TruoraError(
            description: "Test error",
            currentValidation: "face",
            type: "network",
            code: "1234"
        )

        do {
            throw error
        } catch let caughtError as TruoraError {
            XCTAssertEqual(caughtError.description, "Test error")
            XCTAssertEqual(caughtError.code, "1234")
        } catch {
            XCTFail("Expected TruoraError but got \(error)")
        }
    }

    // MARK: - Codable Tests

    func testEncoding() throws {
        let error = TruoraError(
            description: "API request failed",
            currentValidation: "face-recognition",
            type: "network",
            code: "1234"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(error)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(json)
        XCTAssertEqual(json?["description"] as? String, "API request failed")
        XCTAssertEqual(json?["current_validation"] as? String, "face-recognition")
        XCTAssertEqual(json?["type"] as? String, "network")
        XCTAssertEqual(json?["code"] as? String, "1234")
    }

    func testDecoding() throws {
        let json = """
        {
            "description": "Configuration is invalid",
            "current_validation": "document-validation",
            "type": "configuration",
            "code": "1234"
        }
        """
        let data = json.data(using: .utf8)!

        let decoder = JSONDecoder()
        let error = try decoder.decode(TruoraError.self, from: data)

        XCTAssertEqual(error.description, "Configuration is invalid")
        XCTAssertEqual(error.currentValidation, "document-validation")
        XCTAssertEqual(error.type, "configuration")
        XCTAssertEqual(error.code, "1234")
    }
}
