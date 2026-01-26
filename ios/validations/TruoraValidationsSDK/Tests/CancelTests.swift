//
//  CancelTests.swift
//  SDKTests
//
//  Created by Brayan Escobar on 10/11/25.
//

import XCTest
@testable import TruoraValidationsSDK

final class CancelTests: XCTestCase {
    func testInitialization() {
        let reason = "User pressed back button"
        let currentValidation = "face-recognition"
        let currentView = "PassiveCaptureView"

        let cancel = Cancel(
            reason: reason,
            currentValidation: currentValidation,
            currentView: currentView
        )

        XCTAssertEqual(cancel.reason, reason)
        XCTAssertEqual(cancel.currentValidation, currentValidation)
        XCTAssertEqual(cancel.currentView, currentView)
    }

    // MARK: - Codable Tests

    func testEncoding() throws {
        let cancel = Cancel(
            reason: "User cancelled",
            currentValidation: "face-recognition",
            currentView: "PassiveCaptureView"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(cancel)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(json)
        XCTAssertEqual(json?["reason"] as? String, "User cancelled")
        XCTAssertEqual(json?["current_validation"] as? String, "face-recognition")
        XCTAssertEqual(json?["current_view"] as? String, "PassiveCaptureView")
    }

    func testDecoding() throws {
        let json = """
        {
            "reason": "User cancelled",
            "current_validation": "face-recognition",
            "current_view": "PassiveCaptureView"
        }
        """
        let data = json.data(using: .utf8)!

        let decoder = JSONDecoder()
        let cancel = try decoder.decode(Cancel.self, from: data)

        XCTAssertEqual(cancel.reason, "User cancelled")
        XCTAssertEqual(cancel.currentValidation, "face-recognition")
        XCTAssertEqual(cancel.currentView, "PassiveCaptureView")
    }
}
