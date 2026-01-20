//
//  EventLogTests.swift
//  SDKTests
//
//  Created by Brayan Escobar on 10/11/25.
//

import XCTest
@testable import TruoraValidationsSDK

final class EventLogTests: XCTestCase {
    func testInitialization() {
        let name = "capture_started"
        let currentView = "PassiveCaptureView"
        let date = "2025-11-10T12:00:00Z"

        let eventLog = EventLog(
            name: name,
            currentView: currentView,
            date: date
        )

        XCTAssertEqual(eventLog.name, name)
        XCTAssertEqual(eventLog.currentView, currentView)
        XCTAssertEqual(eventLog.date, date)
    }

    // MARK: - Codable Tests

    func testEncoding() throws {
        let eventLog = EventLog(
            name: "face_detection_started",
            currentView: "PassiveCaptureView",
            date: "2025-11-10T12:00:00Z"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(eventLog)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(json)
        XCTAssertEqual(json?["name"] as? String, "face_detection_started")
        XCTAssertEqual(json?["current_view"] as? String, "PassiveCaptureView")
        XCTAssertEqual(json?["date"] as? String, "2025-11-10T12:00:00Z")
    }

    func testDecoding() throws {
        let json = """
        {
            "name": "validation_completed",
            "current_view": "ResultView",
            "date": "2025-11-10T15:30:00Z"
        }
        """
        let data = json.data(using: .utf8)!

        let decoder = JSONDecoder()
        let eventLog = try decoder.decode(EventLog.self, from: data)

        XCTAssertEqual(eventLog.name, "validation_completed")
        XCTAssertEqual(eventLog.currentView, "ResultView")
        XCTAssertEqual(eventLog.date, "2025-11-10T15:30:00Z")
    }
}
