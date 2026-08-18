//
//  PassiveCaptureUploadHeaderViewTests.swift
//  TruoraValidationsSDKTests
//

import XCTest
@testable import TruoraValidationsSDK

@MainActor final class PassiveCaptureUploadHeaderViewTests: XCTestCase {
    func testUploadingTitle_resolvesToLocalizedString() {
        let text = TruoraLocalization.string(forKey: LocalizationKeys.passiveCaptureUploadingTitle)
        XCTAssertFalse(text.isEmpty, "passiveCaptureUploadingTitle should resolve to a non-empty string")
        XCTAssertNotEqual(
            text, LocalizationKeys.passiveCaptureUploadingTitle,
            "passiveCaptureUploadingTitle should not fall back to the raw key"
        )
    }

    func testReadyTitle_resolvesToLocalizedString() {
        let text = TruoraLocalization.string(forKey: LocalizationKeys.passiveCaptureReadyTitle)
        XCTAssertFalse(text.isEmpty, "passiveCaptureReadyTitle should resolve to a non-empty string")
        XCTAssertNotEqual(
            text, LocalizationKeys.passiveCaptureReadyTitle,
            "passiveCaptureReadyTitle should not fall back to the raw key"
        )
    }

    func testHeaderTitle_uploading_returnsLoadingCopy() {
        let expected = TruoraLocalization.string(forKey: LocalizationKeys.passiveCaptureUploadingTitle)
        XCTAssertEqual(uploadHeaderTitle(for: .uploading), expected)
    }

    func testHeaderTitle_success_returnsReadyCopy() {
        let expected = TruoraLocalization.string(forKey: LocalizationKeys.passiveCaptureReadyTitle)
        XCTAssertEqual(uploadHeaderTitle(for: .success), expected)
    }

    func testHeaderTitle_noneOrNavigated_returnsNil() {
        XCTAssertNil(uploadHeaderTitle(for: .none), "Expected nil for .none")
        XCTAssertNil(uploadHeaderTitle(for: .navigatedToResult), "Expected nil for .navigatedToResult")
    }

    func testUploadOvalStrokeColor_uploading_isWhite() {
        XCTAssertEqual(uploadOvalStrokeColor(for: .uploading, theme: TruoraTheme(config: nil)), .white)
    }

    func testUploadOvalStrokeColor_success_isThemeSuccess() {
        let theme = TruoraTheme(config: nil)
        XCTAssertEqual(uploadOvalStrokeColor(for: .success, theme: theme), theme.colors.layoutSuccess)
    }

    func testUploadOvalStrokeColor_none_isNil() {
        XCTAssertNil(uploadOvalStrokeColor(for: .none, theme: TruoraTheme(config: nil)))
        XCTAssertNil(uploadOvalStrokeColor(for: .navigatedToResult, theme: TruoraTheme(config: nil)))
    }
}
