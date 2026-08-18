//
//  TruoraProcessRetryPolicyTests.swift
//  TruoraValidationsSDKTests
//
//  Created by Truora on 01/07/26.
//

import XCTest
@testable import TruoraValidationsSDK

final class TruoraProcessRetryPolicyTests: XCTestCase {
    private func retriesPolicy(
        baseDelay: TimeInterval = 0.1,
        maxDelay: TimeInterval = 10.0,
        multiplier: Double = 2.0,
        maxRetries: Int = 5
    ) -> TruoraRetryPolicy {
        TruoraRetryPolicy(
            maxRetries: maxRetries,
            baseDelay: baseDelay,
            maxDelay: maxDelay,
            multiplier: multiplier
        )
    }

    func testDelayGrowsExponentiallyWithoutJitter() {
        let policy = retriesPolicy(baseDelay: 0.1, multiplier: 2.0)

        XCTAssertEqual(policy.delay(forAttempt: 0), 0.1, accuracy: 0.0001)
        XCTAssertEqual(policy.delay(forAttempt: 1), 0.2, accuracy: 0.0001)
        XCTAssertEqual(policy.delay(forAttempt: 2), 0.4, accuracy: 0.0001)
        XCTAssertEqual(policy.delay(forAttempt: 3), 0.8, accuracy: 0.0001)
    }

    func testDelayIsCappedAtMaxDelay() {
        let policy = retriesPolicy(baseDelay: 1.0, maxDelay: 5.0, multiplier: 2.0)

        XCTAssertEqual(policy.delay(forAttempt: 0), 1.0, accuracy: 0.0001)
        XCTAssertEqual(policy.delay(forAttempt: 1), 2.0, accuracy: 0.0001)
        XCTAssertEqual(policy.delay(forAttempt: 2), 4.0, accuracy: 0.0001)
        // 8.0 would exceed the cap
        XCTAssertEqual(policy.delay(forAttempt: 3), 5.0, accuracy: 0.0001)
        XCTAssertEqual(policy.delay(forAttempt: 10), 5.0, accuracy: 0.0001)
    }

    func testNonePolicyPerformsNoRetries() {
        XCTAssertEqual(TruoraRetryPolicy.none.maxRetries, 0)
    }
}
