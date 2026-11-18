//
//  UploadTimeoutPolicyTests.swift
//  TruoraValidationsSDKTests
//

import XCTest
@testable import TruoraValidationsSDK

final class UploadTimeoutPolicyTests: XCTestCase {
    func testDeadlineReturnsTheResultWhenTheOperationFinishesInTime() async throws {
        let value = try await withUploadDeadline(5) { 42 }

        XCTAssertEqual(value, 42)
    }

    func testDeadlineCancelsAnOperationThatRunsTooLong() async {
        let start = Date()

        do {
            _ = try await withUploadDeadline(0.05) {
                try await Task.sleep(nanoseconds: 10_000_000_000)
                return 0
            }
            XCTFail("Expected a timeout")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .timedOut)
        } catch {
            XCTFail("Unexpected error \(error)")
        }

        XCTAssertLessThan(Date().timeIntervalSince(start), 2, "The slow operation must be cancelled, not awaited")
    }
}
