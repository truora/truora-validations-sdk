//
//  PassiveCaptureFeedbackViewTests.swift
//  TruoraValidationsSDKTests
//
//  Created by Truora on 27/05/26.
//

import XCTest
@testable import TruoraValidationsSDK

/// Verifies that the new FeedbackType cases introduced in PROC-7068 I1 are
/// properly wired to non-empty localized text.
@MainActor final class PassiveCaptureFeedbackViewTests: XCTestCase {
    // MARK: - moveCloser

    func testFeedbackText_moveCloser_isNonEmpty() {
        let text = TruoraLocalization.string(forKey: LocalizationKeys.passiveCaptureFeedbackMoveCloser)
        XCTAssertFalse(text.isEmpty, "passiveCaptureFeedbackMoveCloser should resolve to a non-empty string")
        XCTAssertNotEqual(
            text, LocalizationKeys.passiveCaptureFeedbackMoveCloser,
            "passiveCaptureFeedbackMoveCloser should not fall back to the raw key"
        )
    }

    // MARK: - moveBack

    func testFeedbackText_moveBack_isNonEmpty() {
        let text = TruoraLocalization.string(forKey: LocalizationKeys.passiveCaptureFeedbackMoveBack)
        XCTAssertFalse(text.isEmpty, "passiveCaptureFeedbackMoveBack should resolve to a non-empty string")
        XCTAssertNotEqual(
            text, LocalizationKeys.passiveCaptureFeedbackMoveBack,
            "passiveCaptureFeedbackMoveBack should not fall back to the raw key"
        )
    }

    // MARK: - feedbackText wiring

    func testFeedbackText_moveCloser_returnsLocalizedString() {
        let view = PassiveCaptureFeedbackView(feedback: .moveCloser)
        XCTAssertFalse(view.feedbackText.isEmpty, "feedbackText for .moveCloser should be non-empty")
    }

    func testFeedbackText_moveBack_returnsLocalizedString() {
        let view = PassiveCaptureFeedbackView(feedback: .moveBack)
        XCTAssertFalse(view.feedbackText.isEmpty, "feedbackText for .moveBack should be non-empty")
    }
}
