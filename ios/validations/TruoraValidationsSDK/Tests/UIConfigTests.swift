//
//  UIConfigTests.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 17/11/25.
//

import TruoraShared
import UIKit
import XCTest
@testable import TruoraValidationsSDK

final class UIConfigTests: XCTestCase {
    var sut: UIConfig!

    override func setUp() {
        super.setUp()
        sut = UIConfig()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialState() {
        // Then - All Material3 colors should be nil by default
        XCTAssertNil(sut.surface, "Surface color should be nil by default")
        XCTAssertNil(sut.onSurface, "OnSurface color should be nil by default")
        XCTAssertNil(sut.primary, "Primary color should be nil by default")
        XCTAssertNil(sut.onPrimary, "OnPrimary color should be nil by default")
        XCTAssertNil(sut.secondary, "Secondary color should be nil by default")
        XCTAssertNil(sut.error, "Error color should be nil by default")
        XCTAssertNil(sut.logoUrl, "Logo URL should be nil by default")
        XCTAssertEqual(sut.language, .english, "Language should default to English")
    }

    // MARK: - Surface Color Tests

    func testSetSurfaceColorWithUIColor() {
        // Given
        let testColor = UIColor.white

        // When
        let result = sut.setSurfaceColor(testColor)

        // Then
        XCTAssertEqual(sut.surface, testColor, "Should set surface color")
        XCTAssertTrue(result === sut, "Should return self for chaining")
    }

    func testSetSurfaceColorWithHexString() {
        // Given
        let hexColor = "#FFFFFF"

        // When
        let result = sut.setSurfaceColor(hexColor)

        // Then
        XCTAssertNotNil(sut.surface, "Should set surface color from hex")
        XCTAssertTrue(result === sut, "Should return self for chaining")
    }

    func testSetSurfaceColorWithInvalidHex() {
        // Given
        let invalidHex = "not-a-color"

        // When
        let result = sut.setSurfaceColor(invalidHex)

        // Then
        XCTAssertNil(sut.surface, "Should not set color with invalid hex")
        XCTAssertTrue(result === sut, "Should still return self for chaining")
    }

    // MARK: - OnSurface Color Tests

    func testSetOnSurfaceColorWithUIColor() {
        // Given
        let testColor = UIColor.black

        // When
        let result = sut.setOnSurfaceColor(testColor)

        // Then
        XCTAssertEqual(sut.onSurface, testColor, "Should set onSurface color")
        XCTAssertTrue(result === sut, "Should return self for chaining")
    }

    func testSetOnSurfaceColorWithHexString() {
        // Given
        let hexColor = "#1F2828"

        // When
        let result = sut.setOnSurfaceColor(hexColor)

        // Then
        XCTAssertNotNil(sut.onSurface, "Should set onSurface color from hex")
        XCTAssertTrue(result === sut, "Should return self for chaining")
    }

    func testSetOnSurfaceColorWithInvalidHex() {
        // Given
        let invalidHex = "invalid"

        // When
        let result = sut.setOnSurfaceColor(invalidHex)

        // Then
        XCTAssertNil(sut.onSurface, "Should not set color with invalid hex")
        XCTAssertTrue(result === sut, "Should still return self for chaining")
    }

    // MARK: - Primary Color Tests

    func testSetPrimaryColorWithUIColor() {
        // Given
        let testColor = UIColor.blue

        // When
        let result = sut.setPrimaryColor(testColor)

        // Then
        XCTAssertEqual(sut.primary, testColor, "Should set primary color")
        XCTAssertTrue(result === sut, "Should return self for chaining")
    }

    func testSetPrimaryColorWithHexString() {
        // Given
        let hexColor = "#435AE0"

        // When
        let result = sut.setPrimaryColor(hexColor)

        // Then
        XCTAssertNotNil(sut.primary, "Should set primary color from hex")
        XCTAssertTrue(result === sut, "Should return self for chaining")
    }

    func testSetPrimaryColorWithInvalidHex() {
        // Given
        let invalidHex = "xyz"

        // When
        let result = sut.setPrimaryColor(invalidHex)

        // Then
        XCTAssertNil(sut.primary, "Should not set color with invalid hex")
        XCTAssertTrue(result === sut, "Should still return self for chaining")
    }

    // MARK: - OnPrimary Color Tests

    func testSetOnPrimaryColorWithUIColor() {
        // Given
        let testColor = UIColor.white

        // When
        let result = sut.setOnPrimaryColor(testColor)

        // Then
        XCTAssertEqual(sut.onPrimary, testColor, "Should set onPrimary color")
        XCTAssertTrue(result === sut, "Should return self for chaining")
    }

    func testSetOnPrimaryColorWithHexString() {
        // Given
        let hexColor = "#FFFFFF"

        // When
        let result = sut.setOnPrimaryColor(hexColor)

        // Then
        XCTAssertNotNil(sut.onPrimary, "Should set onPrimary color from hex")
        XCTAssertTrue(result === sut, "Should return self for chaining")
    }

    func testSetOnPrimaryColorWithInvalidHex() {
        // Given
        let invalidHex = ""

        // When
        let result = sut.setOnPrimaryColor(invalidHex)

        // Then
        XCTAssertNil(sut.onPrimary, "Should not set color with invalid hex")
        XCTAssertTrue(result === sut, "Should still return self for chaining")
    }

    // MARK: - Secondary Color Tests

    func testSetSecondaryColorWithUIColor() {
        // Given
        let testColor = UIColor.darkGray

        // When
        let result = sut.setSecondaryColor(testColor)

        // Then
        XCTAssertEqual(sut.secondary, testColor, "Should set secondary color")
        XCTAssertTrue(result === sut, "Should return self for chaining")
    }

    func testSetSecondaryColorWithHexString() {
        // Given
        let hexColor = "#082054"

        // When
        let result = sut.setSecondaryColor(hexColor)

        // Then
        XCTAssertNotNil(sut.secondary, "Should set secondary color from hex")
        XCTAssertTrue(result === sut, "Should return self for chaining")
    }

    func testSetSecondaryColorWithInvalidHex() {
        // Given
        let invalidHex = "12345"

        // When
        let result = sut.setSecondaryColor(invalidHex)

        // Then
        XCTAssertNil(sut.secondary, "Should not set color with invalid hex")
        XCTAssertTrue(result === sut, "Should still return self for chaining")
    }

    // MARK: - Error Color Tests

    func testSetErrorColorWithUIColor() {
        // Given
        let testColor = UIColor.red

        // When
        let result = sut.setErrorColor(testColor)

        // Then
        XCTAssertEqual(sut.error, testColor, "Should set error color")
        XCTAssertTrue(result === sut, "Should return self for chaining")
    }

    func testSetErrorColorWithHexString() {
        // Given
        let hexColor = "#FF5454"

        // When
        let result = sut.setErrorColor(hexColor)

        // Then
        XCTAssertNotNil(sut.error, "Should set error color from hex")
        XCTAssertTrue(result === sut, "Should return self for chaining")
    }

    func testSetErrorColorWithInvalidHex() {
        // Given
        let invalidHex = "#GGGGGG"

        // When
        let result = sut.setErrorColor(invalidHex)

        // Then
        XCTAssertNil(sut.error, "Should not set color with invalid hex")
        XCTAssertTrue(result === sut, "Should still return self for chaining")
    }

    // MARK: - Logo Tests

    func testSetLogo() {
        // Given
        let logoUrl = "https://example.com/logo.png"

        // When
        let result = sut.setLogo(logoUrl)

        // Then
        XCTAssertEqual(sut.logoUrl, logoUrl, "Should set logo URL")
        XCTAssertTrue(result === sut, "Should return self for chaining")
    }

    func testSetLogoWithInvalidUrl() {
        // Given
        let invalidUrl = "not a valid url with spaces"

        // When
        let result = sut.setLogo(invalidUrl)

        // Then
        XCTAssertNil(sut.logoUrl, "Should not set invalid logo URL")
        XCTAssertTrue(result === sut, "Should still return self for chaining")
    }

    // MARK: - Language Tests

    func testSetLanguage() {
        // Given
        let language = TruoraLanguage.spanish

        // When
        let result = sut.setLanguage(language)

        // Then
        XCTAssertEqual(sut.language, language, "Should set language")
        XCTAssertTrue(result === sut, "Should return self for chaining")
    }

    func testSetLanguagePortuguese() {
        // When
        let result = sut.setLanguage(.portuguese)

        // Then
        XCTAssertEqual(sut.language, .portuguese, "Should set Portuguese language")
        XCTAssertTrue(result === sut, "Should return self for chaining")
    }

    // MARK: - Method Chaining Tests

    func testMethodChainingAllMaterial3Colors() {
        // When
        let result = sut
            .setSurfaceColor("#FFFFFF")
            .setOnSurfaceColor("#1F2828")
            .setPrimaryColor("#435AE0")
            .setOnPrimaryColor("#FFFFFF")
            .setSecondaryColor("#082054")
            .setErrorColor("#FF5454")
            .setLogo("https://example.com/logo.png")
            .setLanguage(.spanish)

        // Then
        XCTAssertTrue(result === sut, "Should support method chaining")
        XCTAssertNotNil(sut.surface, "Should have set surface color")
        XCTAssertNotNil(sut.onSurface, "Should have set onSurface color")
        XCTAssertNotNil(sut.primary, "Should have set primary color")
        XCTAssertNotNil(sut.onPrimary, "Should have set onPrimary color")
        XCTAssertNotNil(sut.secondary, "Should have set secondary color")
        XCTAssertNotNil(sut.error, "Should have set error color")
        XCTAssertEqual(sut.logoUrl, "https://example.com/logo.png", "Should have set logo URL")
        XCTAssertEqual(sut.language, .spanish, "Should have set language")
    }

    func testMethodChainingWithUIColors() {
        // When
        let result = sut
            .setSurfaceColor(UIColor.white)
            .setOnSurfaceColor(UIColor.black)
            .setPrimaryColor(UIColor.blue)
            .setOnPrimaryColor(UIColor.white)
            .setSecondaryColor(UIColor.darkGray)
            .setErrorColor(UIColor.red)

        // Then
        XCTAssertTrue(result === sut, "Should support method chaining with UIColors")
        XCTAssertEqual(sut.surface, UIColor.white)
        XCTAssertEqual(sut.onSurface, UIColor.black)
        XCTAssertEqual(sut.primary, UIColor.blue)
        XCTAssertEqual(sut.onPrimary, UIColor.white)
        XCTAssertEqual(sut.secondary, UIColor.darkGray)
        XCTAssertEqual(sut.error, UIColor.red)
    }

    func testPartialConfiguration() {
        // When - only set some colors
        let result = sut
            .setSurfaceColor("#F9FAFB")
            .setPrimaryColor("#435AE0")

        // Then
        XCTAssertTrue(result === sut, "Should support partial configuration")
        XCTAssertNotNil(sut.surface, "Should have set surface color")
        XCTAssertNotNil(sut.primary, "Should have set primary color")
        XCTAssertNil(sut.onSurface, "OnSurface should still be nil")
        XCTAssertNil(sut.onPrimary, "OnPrimary should still be nil")
        XCTAssertNil(sut.secondary, "Secondary should still be nil")
        XCTAssertNil(sut.error, "Error should still be nil")
    }
}

// MARK: - UIColor Hex Extension Tests

extension UIConfigTests {
    func testUIColorHexInitWithValidHex() {
        // Given
        let hexStrings = [
            "#FF5722": true,
            "FF5722": true,
            "#FFFFFF": true,
            "000000": true,
            "#123456": true
        ]

        // When/Then
        for (hex, shouldSucceed) in hexStrings {
            let color = UIColor(hex: hex)
            if shouldSucceed {
                XCTAssertNotNil(color, "Should create color from valid hex: \(hex)")
            }
        }
    }

    func testUIColorHexInitWithInvalidHex() {
        // Given
        let invalidHexStrings = [
            "not-a-hex",
            "#GGGGGG",
            "12345",
            "",
            "#12345",
            "#1234567" // 7 hex digits - invalid
        ]

        // When/Then
        for hex in invalidHexStrings {
            let color = UIColor(hex: hex)
            XCTAssertNil(color, "Should return nil for invalid hex: \(hex)")
        }
    }

    func testUIColorHexWithSpecificColors() {
        // Test red
        let red = UIColor(hex: "#FF0000")
        XCTAssertNotNil(red)

        // Test green
        let green = UIColor(hex: "#00FF00")
        XCTAssertNotNil(green)

        // Test blue
        let blue = UIColor(hex: "#0000FF")
        XCTAssertNotNil(blue)

        // Test white
        let white = UIColor(hex: "#FFFFFF")
        XCTAssertNotNil(white)

        // Test black
        let black = UIColor(hex: "#000000")
        XCTAssertNotNil(black)
    }
}

// MARK: - UIConfig to TruoraUIConfig Conversion Tests

extension UIConfigTests {
    func testToTruoraConfigWithDefaultConfig() {
        // Given
        let config = UIConfig()

        // When
        let truoraConfig = config.toTruoraConfig()

        // Then
        XCTAssertNotNil(truoraConfig, "Should create TruoraUIConfig")
        XCTAssertNotNil(truoraConfig.colors, "Should have colors object")
    }

    func testToTruoraConfigWithAllColorsSet() {
        // Given
        let config = UIConfig()
            .setSurfaceColor("#FFFFFF")
            .setOnSurfaceColor("#1F2828")
            .setPrimaryColor("#435AE0")
            .setOnPrimaryColor("#FFFFFF")
            .setSecondaryColor("#082054")
            .setErrorColor("#FF5454")

        // When
        let truoraConfig = config.toTruoraConfig()

        // Then
        XCTAssertNotNil(truoraConfig.colors, "Should have colors")
        XCTAssertNotNil(truoraConfig.colors?.surface, "Should have surface color")
        XCTAssertNotNil(truoraConfig.colors?.onSurface, "Should have onSurface color")
        XCTAssertNotNil(truoraConfig.colors?.primary, "Should have primary color")
        XCTAssertNotNil(truoraConfig.colors?.onPrimary, "Should have onPrimary color")
        XCTAssertNotNil(truoraConfig.colors?.secondary, "Should have secondary color")
        XCTAssertNotNil(truoraConfig.colors?.error, "Should have error color")
    }

    func testToTruoraConfigWithPartialColors() {
        // Given
        let config = UIConfig()
            .setSurfaceColor("#FFFFFF")
            .setPrimaryColor("#435AE0")

        // When
        let truoraConfig = config.toTruoraConfig()

        // Then
        XCTAssertNotNil(truoraConfig.colors?.surface, "Should have surface color")
        XCTAssertNotNil(truoraConfig.colors?.primary, "Should have primary color")
        XCTAssertNil(truoraConfig.colors?.onSurface, "OnSurface should be nil")
        XCTAssertNil(truoraConfig.colors?.onPrimary, "OnPrimary should be nil")
        XCTAssertNil(truoraConfig.colors?.secondary, "Secondary should be nil")
        XCTAssertNil(truoraConfig.colors?.error, "Error should be nil")
    }

    func testToTruoraConfigLogoIsNilWhenOnlyUrlProvided() {
        // Given
        let config = UIConfig()
            .setLogo("https://example.com/logo.png")

        // When
        let truoraConfig = config.toTruoraConfig()

        // Then - URL is handled by ValidationConfig downloader, not by direct Compose mapping
        XCTAssertNil(truoraConfig.logo, "Logo should be nil when only URL is provided")
    }

    func testToTruoraConfigIncludesLogoWhenCustomLogoProvided() {
        // Given
        let logoData = Data([0x01, 0x02, 0x03, 0x04])
        let config = UIConfig()
            .setCustomLogo(logoData, width: 120, height: 30)

        // When
        let truoraConfig = config.toTruoraConfig()

        // Then
        XCTAssertNotNil(truoraConfig.logo, "Logo should be present when custom logo data is provided")
        XCTAssertEqual(truoraConfig.logo?.logoData.size, Int32(logoData.count))
        XCTAssertEqual(truoraConfig.logo?.width?.floatValue, Float(120), "Logo width should be passed through")
        XCTAssertEqual(truoraConfig.logo?.height?.floatValue, Float(30), "Logo height should be passed through")
    }

    func testSetLogoRejectsNonHttpsUrl() {
        // Given
        let config = UIConfig()

        // When
        _ = config.setLogo("http://example.com/logo.png")

        // Then
        XCTAssertNil(config.logoUrl, "Non-https logo URL should be ignored")
    }

    func testSetCustomLogoRejectsEmptyData() {
        // Given
        let config = UIConfig()

        // When
        _ = config.setCustomLogo(Data())

        // Then
        XCTAssertNil(config.customLogoData, "Empty logo data should be ignored")
    }

    func testSetCustomLogoClearsLogoUrl() {
        // Given
        let config = UIConfig()
            .setLogo("https://example.com/logo.png")
        let logoData = Data([0x01, 0x02, 0x03])

        // When
        _ = config.setCustomLogo(logoData)

        // Then
        XCTAssertNil(config.logoUrl, "Custom logo should clear logo URL to avoid ambiguity")
        XCTAssertEqual(config.customLogoData, logoData, "Custom logo bytes should be set")
    }

    func testSetLogoClearsCustomLogoData() {
        // Given
        let logoData = Data([0x01, 0x02, 0x03])
        let config = UIConfig()
            .setCustomLogo(logoData)
        let logoUrl = "https://example.com/logo.png"

        // When
        _ = config.setLogo(logoUrl)

        // Then
        XCTAssertNil(config.customLogoData, "Setting a logo URL should clear custom logo bytes")
        XCTAssertEqual(config.logoUrl, logoUrl, "Logo URL should be set")
    }

    func testToTruoraConfigDefaultThemeValuesAreNil() {
        // Given
        let config = UIConfig()

        // When
        let truoraConfig = config.toTruoraConfig()

        // Then - Default theme values should be nil
        XCTAssertNil(truoraConfig.colors?.tint00, "tint00 should be nil")
        XCTAssertNil(truoraConfig.colors?.tint20, "tint20 should be nil")
        XCTAssertNil(truoraConfig.colors?.warning, "warning should be nil")
        XCTAssertNil(truoraConfig.colors?.success, "success should be nil")
        XCTAssertNil(truoraConfig.colors?.overlay, "overlay should be nil")
        XCTAssertNil(truoraConfig.colors?.secondaryBg, "secondaryBg should be nil")
        XCTAssertNil(truoraConfig.colors?.infoBlue, "infoBlue should be nil")
    }
}
