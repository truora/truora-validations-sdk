//
//  ServerClockTests.swift
//  TruoraValidationsSDKTests
//

import XCTest
@testable import TruoraValidationsSDK

@MainActor final class ServerClockTests: XCTestCase {
    override func tearDown() {
        ServerClock.reset()
        super.tearDown()
    }

    func testParseCreationDate_withNanoseconds_ignoresFraction() {
        XCTAssertEqual(ServerClock.parseCreationDate("2025-10-07T21:13:45.942001841Z"), 1_759_871_625)
    }

    func testParseCreationDate_withUtcDesignators_parsesUtc() {
        XCTAssertEqual(ServerClock.parseCreationDate("2025-01-01T00:00:00Z"), 1_735_689_600)
        XCTAssertEqual(ServerClock.parseCreationDate("2025-01-01T00:00:00z"), 1_735_689_600)
        XCTAssertEqual(ServerClock.parseCreationDate("2025-01-01T00:00:00+00:00"), 1_735_689_600)
    }

    func testParseCreationDate_withNumericOffset_convertsToUtc() {
        XCTAssertEqual(ServerClock.parseCreationDate("2025-01-01T00:00:00-05:00"), 1_735_707_600)
        XCTAssertEqual(ServerClock.parseCreationDate("2025-01-01T00:00:00.5+05:30"), 1_735_669_800)
        XCTAssertEqual(ServerClock.parseCreationDate("2025-01-01T00:00:00+23:59"), 1_735_603_260)
    }

    func testParseCreationDate_withInvalidValue_returnsNil() {
        XCTAssertNil(ServerClock.parseCreationDate("2025-01-01T00:00:00"))
        XCTAssertNil(ServerClock.parseCreationDate("2025-13-01T00:00:00Z"))
        XCTAssertNil(ServerClock.parseCreationDate("2025-01-01T00:00:00+5"))
        XCTAssertNil(ServerClock.parseCreationDate("2025-01-01T00:00:00+99:99"))
        XCTAssertNil(ServerClock.parseCreationDate("2025-01-01T00:00:00+24:00"))
        XCTAssertNil(ServerClock.parseCreationDate("2025-01-01T00:00:00-05:60"))
        XCTAssertNil(ServerClock.parseCreationDate("not a date"))
        XCTAssertNil(ServerClock.parseCreationDate(""))
        XCTAssertNil(ServerClock.parseCreationDate(nil))
    }

    func testNow_withoutSync_usesDeviceClock() {
        XCTAssertEqual(ServerClock.now(deviceNow: 1234, monotonicNow: 99), 1234)
    }

    func testNow_afterSync_addsMonotonicElapsedTime() {
        ServerClock.sync(withCreationDate: "2025-01-01T00:00:00Z", monotonicNow: 10)

        XCTAssertEqual(ServerClock.now(deviceNow: 0, monotonicNow: 15), 1_735_689_605)
    }

    func testNow_whenDeviceClockChangesAfterSync_ignoresIt() {
        ServerClock.sync(withCreationDate: "2025-01-01T00:00:00Z", monotonicNow: 0)

        let before = ServerClock.now(deviceNow: 1_735_689_600, monotonicNow: 1)
        let after = ServerClock.now(deviceNow: 1_735_689_600 + 7200, monotonicNow: 1)

        XCTAssertEqual(before, after)
    }

    func testSync_withInvalidDate_keepsPreviousAnchor() {
        ServerClock.sync(withCreationDate: "2025-01-01T00:00:00Z", monotonicNow: 0)

        ServerClock.sync(withCreationDate: "invalid", monotonicNow: 50)

        XCTAssertEqual(ServerClock.now(deviceNow: 0, monotonicNow: 0), 1_735_689_600)
    }

    func testIsExpired_withDeviceClockAheadOfServer_usesServerTime() {
        let serverNow = Date().timeIntervalSince1970.rounded(.down) - 7200
        let url = "https://files.truora.com/file?Expires=\(Int(serverNow + 600))"
        XCTAssertTrue(UploadUrlValidator.isExpired(url))

        ServerClock.sync(withCreationDate: formatUtc(serverNow))

        XCTAssertFalse(UploadUrlValidator.isExpired(url))
    }

    func testIsExpired_withDeviceClockBehindServer_usesServerTime() {
        let deviceNow = Date().timeIntervalSince1970.rounded(.down)
        let url = "https://files.truora.com/file?Expires=\(Int(deviceNow + 600))"
        XCTAssertFalse(UploadUrlValidator.isExpired(url))

        ServerClock.sync(withCreationDate: formatUtc(deviceNow + 7200))

        XCTAssertTrue(UploadUrlValidator.isExpired(url))
    }

    func testCreateResponse_decodesCreationDate() throws {
        let json = #"{"validation_id":"VLD1","creation_date":"2025-01-01T00:00:00Z"}"#

        let response = try JSONDecoder().decode(NativeValidationCreateResponse.self, from: Data(json.utf8))

        XCTAssertEqual(response.creationDate, "2025-01-01T00:00:00Z")
    }

    private func formatUtc(_ timestamp: TimeInterval) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: Date(timeIntervalSince1970: timestamp))
    }
}
