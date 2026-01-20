//
//  TruoraValidationBuilderTests.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 17/11/25.
//

import XCTest

@testable import TruoraValidationsSDK

final class TruoraValidationBuilderTests: XCTestCase {
    fileprivate var mockAPIKeyGetter: MockTruoraAPIKeyGetter!

    override func setUp() {
        super.setUp()
        mockAPIKeyGetter = MockTruoraAPIKeyGetter()
    }

    override func tearDown() {
        mockAPIKeyGetter = nil
        super.tearDown()
    }

    // MARK: - Builder Initialization Tests

    func testBuilderInitialization() {
        // When
        let builder = TruoraValidationsSDK.Builder(
            apiKeyGenerator: mockAPIKeyGetter,
            userId: "test-user"
        )

        // Then
        XCTAssertNotNil(builder, "Builder should be initialized")
    }

    // MARK: - withConfig Tests

    func testWithConfig() {
        // Given
        let builder = TruoraValidationsSDK.Builder(
            apiKeyGenerator: mockAPIKeyGetter,
            userId: "test-user"
        )

        // When
        let result = builder.withConfig { config in
            config
                .setSurfaceColor("#FFFFFF")
                .setPrimaryColor("#435AE0")
                .setLanguage(.spanish)
        }

        // Then
        XCTAssertNotNil(result, "Should return builder for chaining")
    }

    // MARK: - withValidation Tests

    func testWithValidation() {
        // Given
        let builder = TruoraValidationsSDK.Builder(
            apiKeyGenerator: mockAPIKeyGetter,
            userId: "test-user"
        )

        // When
        let typedBuilder = builder.withValidation { (validation: Face) in
            validation
                .setSimilarityThreshold(0.85)
                .enableAutocapture(true)
        }

        // Then
        XCTAssertNotNil(typedBuilder, "Should return typed builder")
    }

    // MARK: - build Tests

    func testBuildWithValidation() {
        // Given
        let builder = TruoraValidationsSDK.Builder(
            apiKeyGenerator: mockAPIKeyGetter,
            userId: "test-user-123"
        )

        // When
        let validation =
            builder
                .withValidation { (validation: Face) in
                    validation.setSimilarityThreshold(0.9)
                }
                .build()

        guard case .face(let faceConfig) = validation.type else {
            XCTFail("Expected .face case, but got \(validation.type)")
            return
        }

        // Then
        XCTAssertNotNil(validation, "Should build TruoraValidation")
        XCTAssertEqual(validation.userId, "test-user-123", "Should have correct user ID")
        XCTAssertEqual(
            faceConfig.similarityThreshold,
            0.9,
            "Should have configured similarity threshold"
        )
    }

    func testBuildWithConfigAndValidation() {
        // Given
        let builder = TruoraValidationsSDK.Builder(
            apiKeyGenerator: mockAPIKeyGetter,
            userId: "test-user"
        )

        // When
        let validation =
            builder
                .withConfig { config in
                    config
                        .setPrimaryColor("#435AE0")
                        .setLanguage(.spanish)
                }
                .withValidation { (validation: Face) in
                    validation
                        .setSimilarityThreshold(0.85)
                        .enableAutocapture(false)
                        .setTimeout(120)
                }
                .build()

        guard case .face(let faceConfig) = validation.type else {
            XCTFail("Expected .face case, but got \(validation.type)")
            return
        }

        // Then
        XCTAssertNotNil(validation, "Should build TruoraValidation")
        XCTAssertNotNil(validation.uiConfig.primary, "Should have configured UI")
        XCTAssertEqual(validation.uiConfig.language, .spanish, "Should have configured language")
        XCTAssertEqual(
            faceConfig.similarityThreshold,
            0.85,
            "Should have configured threshold"
        )
        XCTAssertFalse(
            faceConfig.useAutocapture,
            "Should have configured autocapture"
        )
        XCTAssertEqual(
            faceConfig.timeoutSeconds,
            120,
            "Should have configured timeout"
        )
    }

    func testBuildWithoutConfig() {
        // Given
        let builder = TruoraValidationsSDK.Builder(
            apiKeyGenerator: mockAPIKeyGetter,
            userId: "test-user"
        )

        // When
        let validation =
            builder
                .withValidation { (validation: Face) in
                    validation.setSimilarityThreshold(0.8)
                }
                .build()

        // Then
        XCTAssertNotNil(validation, "Should build TruoraValidation with default config")
        XCTAssertEqual(validation.uiConfig.language, .english, "Should use default language")
        XCTAssertNil(validation.uiConfig.primary, "Should have no primary color")
    }

    // MARK: - Full Builder Chain Tests

    // swiftlint:disable:next function_body_length
    func testFullBuilderChain() throws {
        // Given
        let referenceFace = try ReferenceFace.from("https://example.com/face.jpg")

        // When
        let validation = TruoraValidationsSDK.Builder(
            apiKeyGenerator: mockAPIKeyGetter,
            userId: "user-456"
        )
        .withConfig { config in
            config
                .setSurfaceColor("#FFFFFF")
                .setOnSurfaceColor("#1F2828")
                .setPrimaryColor("#435AE0")
                .setOnPrimaryColor("#FFFFFF")
                .setSecondaryColor("#082054")
                .setErrorColor("#FF5454")
                .setLogo("https://example.com/logo.png")
                .setLanguage(.portuguese)
        }
        .withValidation { (validation: Face) in
            validation
                .useReferenceFace(referenceFace)
                .setSimilarityThreshold(0.95)
                .enableAutocapture(true)
                .enableWaitForResults(false)
                .setTimeout(180)
        }
        .build()

        // Then
        XCTAssertEqual(validation.userId, "user-456", "Should have correct user ID")

        // Check UI Config - Material3 colors
        XCTAssertNotNil(validation.uiConfig.surface, "Should have surface color")
        XCTAssertNotNil(validation.uiConfig.onSurface, "Should have onSurface color")
        XCTAssertNotNil(validation.uiConfig.primary, "Should have primary color")
        XCTAssertNotNil(validation.uiConfig.onPrimary, "Should have onPrimary color")
        XCTAssertNotNil(validation.uiConfig.secondary, "Should have secondary color")
        XCTAssertNotNil(validation.uiConfig.error, "Should have error color")
        XCTAssertEqual(
            validation.uiConfig.logoUrl,
            "https://example.com/logo.png",
            "Should have logo URL"
        )
        XCTAssertEqual(validation.uiConfig.language, .portuguese, "Should have Portuguese language")

        guard case .face(let faceConfig) = validation.type else {
            XCTFail("Expected .face case, but got \(validation.type)")
            return
        }

        // Check Validation Config
        XCTAssertNotNil(faceConfig.referenceFace, "Should have reference face")
        XCTAssertEqual(
            faceConfig.similarityThreshold,
            0.95,
            "Should have threshold"
        )
        XCTAssertTrue(faceConfig.useAutocapture, "Should have autocapture enabled")
        XCTAssertFalse(
            faceConfig.shouldWaitForResults,
            "Should not wait for results"
        )
        XCTAssertEqual(faceConfig.timeoutSeconds, 180, "Should have timeout")
    }

    // MARK: - Type Inference Tests

    func testTypeInferenceWithFace() {
        // Given
        let builder = TruoraValidationsSDK.Builder(
            apiKeyGenerator: mockAPIKeyGetter,
            userId: "test-user"
        )

        // When
        let validation =
            builder
                .withValidation { (validation: Face) in
                    validation.setSimilarityThreshold(0.85)
                }
                .build()

        // Then - Type should be inferred as TruoraValidation<Face>
        let vld: TruoraValidationsSDK.TruoraValidation<Face> = validation

        guard case .face(let faceConfig) = vld.type else {
            XCTFail("Expected .face case, but got \(validation.type)")
            return
        }

        XCTAssertEqual(faceConfig.similarityThreshold, 0.85, "Should access Face properties")
    }
}

// MARK: - TruoraValidation Tests

extension TruoraValidationBuilderTests {
    func testTruoraValidationProperties() {
        // Given
        let validation = TruoraValidationsSDK.Builder(
            apiKeyGenerator: mockAPIKeyGetter,
            userId: "test-user"
        )
        .withValidation { (face: Face) in face }
        .build()

        guard case .face(let faceConfig) = validation.type else {
            XCTFail("Expected .face case, but got \(validation.type)")
            return
        }

        // Then
        XCTAssertNotNil(validation.apiKeyGenerator, "Should have API key generator")
        XCTAssertEqual(validation.userId, "test-user", "Should have user ID")
        XCTAssertNotNil(validation.uiConfig, "Should have UI config")
        XCTAssertNotNil(faceConfig, "Should have validation config")
    }

    func testTruoraValidationDefaultValues() {
        // When
        let validation = TruoraValidationsSDK.Builder(
            apiKeyGenerator: mockAPIKeyGetter,
            userId: "test-user"
        )
        .withValidation { (face: Face) in face }
        .build()

        guard case .face(let faceConfig) = validation.type else {
            XCTFail("Expected .face case, but got \(validation.type)")
            return
        }

        // Then - Check default values
        XCTAssertEqual(
            faceConfig.similarityThreshold,
            0.8,
            "Should have default threshold"
        )
        XCTAssertTrue(faceConfig.useAutocapture, "Should have default autocapture")
        XCTAssertTrue(
            faceConfig.shouldWaitForResults,
            "Should have default wait for results"
        )
        XCTAssertEqual(
            faceConfig.timeoutSeconds,
            60,
            "Should have default timeout"
        )
        XCTAssertEqual(validation.uiConfig.language, .english, "Should have default language")
    }
}

// MARK: - Mock API Key Getter

private class MockTruoraAPIKeyGetter: TruoraAPIKeyGetter {
    var shouldThrowError = false
    var apiKeyToReturn = "test-api-key-123"
    var getApiKeyCalled = false

    func getApiKeyFromSecureLocation() async throws -> String {
        getApiKeyCalled = true

        if shouldThrowError {
            throw NSError(domain: "TestError", code: 1, userInfo: nil)
        }

        return apiKeyToReturn
    }
}
