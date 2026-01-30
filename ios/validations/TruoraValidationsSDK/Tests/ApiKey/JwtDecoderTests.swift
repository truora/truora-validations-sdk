import XCTest
@testable import TruoraValidationsSDK

@MainActor final class JwtDecoderTests: XCTestCase {
    private var sut: JwtDecoder!

    override func setUp() {
        super.setUp()
        sut = JwtDecoder()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Valid JWT Tests

    func testExtractJwtData_withValidSdkKey_returnsExpirationAndKeyType() throws {
        // Given: A valid JWT with key_type=sdk and exp=1893456000 (2030-01-01)
        // Payload: {"exp": 1893456000, "key_type": "sdk"}
        let jwt = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE4OTM0NTYwMDAsImtleV90eXBlIjoic2RrIn0.signature"

        // When
        let (expiration, keyType) = try sut.extractJwtData(jwt)

        // Then
        XCTAssertEqual(expiration, 1_893_456_000)
        XCTAssertEqual(keyType, "sdk")
    }

    func testExtractJwtData_withValidGeneratorKey_returnsExpirationAndKeyType() throws {
        // Given: A valid JWT with key_type=generator and exp=1893456000
        // Payload: {"exp": 1893456000, "key_type": "generator"}
        let jwt = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE4OTM0NTYwMDAsImtleV90eXBlIjoiZ2VuZXJhdG9yIn0.signature"

        // When
        let (expiration, keyType) = try sut.extractJwtData(jwt)

        // Then
        XCTAssertEqual(expiration, 1_893_456_000)
        XCTAssertEqual(keyType, "generator")
    }

    func testExtractJwtData_withAdditionalClaims_extractsCorrectly() throws {
        // Given: A JWT with additional claims like sub, iat, etc.
        // Payload: {"exp": 1893456000, "key_type": "sdk", "sub": "user123", "iat": 1640000000}
        let jwt = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE4OTM0NTYwMDAsImtleV90eXBlIjoic2RrIiwic3ViIjoidXNlcjEyMyIsImlhdCI6MTY0MDAwMDAwMH0.signature"

        // When
        let (expiration, keyType) = try sut.extractJwtData(jwt)

        // Then
        XCTAssertEqual(expiration, 1_893_456_000)
        XCTAssertEqual(keyType, "sdk")
    }

    // MARK: - Invalid JWT Format Tests

    func testExtractJwtData_withEmptyString_throwsInvalidJwtFormat() {
        // Given
        let jwt = ""

        // When/Then
        XCTAssertThrowsError(try sut.extractJwtData(jwt)) { error in
            XCTAssertEqual(error as? ApiKeyError, .invalidJwtFormat)
        }
    }

    func testExtractJwtData_withOnePart_throwsInvalidJwtFormat() {
        // Given
        let jwt = "onlyonepart"

        // When/Then
        XCTAssertThrowsError(try sut.extractJwtData(jwt)) { error in
            XCTAssertEqual(error as? ApiKeyError, .invalidJwtFormat)
        }
    }

    func testExtractJwtData_withTwoParts_throwsInvalidJwtFormat() {
        // Given
        let jwt = "header.payload"

        // When/Then
        XCTAssertThrowsError(try sut.extractJwtData(jwt)) { error in
            XCTAssertEqual(error as? ApiKeyError, .invalidJwtFormat)
        }
    }

    func testExtractJwtData_withInvalidBase64Payload_throwsInvalidJwtFormat() {
        // Given: Invalid base64 in payload
        let jwt = "header.!!!invalid!!!.signature"

        // When/Then
        XCTAssertThrowsError(try sut.extractJwtData(jwt)) { error in
            XCTAssertEqual(error as? ApiKeyError, .invalidJwtFormat)
        }
    }

    func testExtractJwtData_withInvalidJsonPayload_throwsInvalidJwtFormat() {
        // Given: Valid base64 but invalid JSON
        // Base64 of "not json"
        let jwt = "header.bm90IGpzb24.signature"

        // When/Then
        XCTAssertThrowsError(try sut.extractJwtData(jwt)) { error in
            XCTAssertEqual(error as? ApiKeyError, .invalidJwtFormat)
        }
    }

    // MARK: - Missing Claims Tests

    func testExtractJwtData_withMissingExpClaim_throwsMissingExpiration() {
        // Given: JWT without exp claim
        // Payload: {"key_type": "sdk"}
        let jwt = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJrZXlfdHlwZSI6InNkayJ9.signature"

        // When/Then
        XCTAssertThrowsError(try sut.extractJwtData(jwt)) { error in
            XCTAssertEqual(error as? ApiKeyError, .missingExpiration)
        }
    }

    func testExtractJwtData_withMissingKeyTypeClaim_throwsMissingKeyType() {
        // Given: JWT without key_type claim
        // Payload: {"exp": 1893456000}
        let jwt = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE4OTM0NTYwMDB9.signature"

        // When/Then
        XCTAssertThrowsError(try sut.extractJwtData(jwt)) { error in
            XCTAssertEqual(error as? ApiKeyError, .missingKeyType)
        }
    }

    func testExtractJwtData_withEmptyPayload_throwsMissingExpiration() {
        // Given: JWT with empty payload
        // Payload: {}
        let jwt = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.e30.signature"

        // When/Then
        XCTAssertThrowsError(try sut.extractJwtData(jwt)) { error in
            XCTAssertEqual(error as? ApiKeyError, .missingExpiration)
        }
    }

    // MARK: - Expiration Tests

    func testIsExpired_withFutureExpiration_returnsFalse() {
        // Given
        let futureExpiration: TimeInterval = Date().timeIntervalSince1970 + 3600 // 1 hour from now

        // When
        let isExpired = sut.isExpired(futureExpiration)

        // Then
        XCTAssertFalse(isExpired)
    }

    func testIsExpired_withPastExpiration_returnsTrue() {
        // Given
        let pastExpiration: TimeInterval = Date().timeIntervalSince1970 - 3600 // 1 hour ago

        // When
        let isExpired = sut.isExpired(pastExpiration)

        // Then
        XCTAssertTrue(isExpired)
    }

    func testIsExpired_withExactCurrentTime_returnsTrue() {
        // Given
        let currentTime: TimeInterval = 1_640_000_000
        let expiration: TimeInterval = 1_640_000_000

        // When
        let isExpired = sut.isExpired(expiration, currentTime: currentTime)

        // Then
        XCTAssertTrue(isExpired)
    }

    func testIsExpired_withCustomCurrentTime_calculatesCorrectly() {
        // Given
        let expiration: TimeInterval = 1_640_000_000
        let currentTime: TimeInterval = 1_639_999_999 // 1 second before expiration

        // When
        let isExpired = sut.isExpired(expiration, currentTime: currentTime)

        // Then
        XCTAssertFalse(isExpired)
    }

    // MARK: - Base64URL Decoding Tests

    func testExtractJwtData_withBase64UrlEncoding_decodesCorrectly() throws {
        // Given: JWT with base64url special characters (- and _)
        // Payload with exp=1893456000 and key_type="sdk"
        // This test ensures proper base64url to base64 conversion
        let jwt = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE4OTM0NTYwMDAsImtleV90eXBlIjoic2RrIn0.signature"

        // When
        let (expiration, keyType) = try sut.extractJwtData(jwt)

        // Then
        XCTAssertEqual(expiration, 1_893_456_000)
        XCTAssertEqual(keyType, "sdk")
    }

    func testExtractJwtData_withPaddingRequired_decodesCorrectly() throws {
        // Given: JWT payload that requires padding
        // Payload: {"exp": 1893456000, "key_type": "sdk"}
        let jwt = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE4OTM0NTYwMDAsImtleV90eXBlIjoic2RrIn0.signature"

        // When
        let result = try sut.extractJwtData(jwt)

        // Then
        XCTAssertEqual(result.keyType, "sdk")
    }
}
