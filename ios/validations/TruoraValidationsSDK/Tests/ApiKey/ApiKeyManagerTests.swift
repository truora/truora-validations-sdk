import XCTest
@testable import TruoraValidationsSDK

@MainActor final class ApiKeyManagerTests: XCTestCase {
    private var sut: ApiKeyManager!
    private var mockGeneratorClient: MockApiKeyGeneratorClient!
    private var fixedTime: TimeInterval!

    override func setUp() {
        super.setUp()
        mockGeneratorClient = MockApiKeyGeneratorClient()
        fixedTime = 1_700_000_000 // Fixed time for testing
        sut = ApiKeyManager(
            jwtDecoder: JwtDecoder(),
            generatorClient: mockGeneratorClient
        ) { [unowned self] in self.fixedTime }
    }

    override func tearDown() {
        sut = nil
        mockGeneratorClient = nil
        fixedTime = nil
        super.tearDown()
    }

    // MARK: - SDK Key Tests

    func testResolveApiKey_withValidSdkKey_returnsKeyDirectly() async throws {
        // Given: Valid SDK key with future expiration
        // Payload: {"exp": 1893456000, "key_type": "sdk"}
        let sdkKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE4OTM0NTYwMDAsImtleV90eXBlIjoic2RrIn0.signature"

        // When
        let result = try await sut.resolveApiKey(sdkKey)

        // Then
        XCTAssertEqual(result, sdkKey)
        XCTAssertFalse(mockGeneratorClient.generateSdkKeyCalled)
    }

    func testResolveApiKey_withValidSdkKey_doesNotCallGeneratorClient() async throws {
        // Given
        let sdkKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE4OTM0NTYwMDAsImtleV90eXBlIjoic2RrIn0.signature"

        // When
        _ = try await sut.resolveApiKey(sdkKey)

        // Then
        XCTAssertNil(mockGeneratorClient.lastGeneratorKey)
    }

    // MARK: - Generator Key Tests

    func testResolveApiKey_withValidGeneratorKey_callsGeneratorClient() async throws {
        // Given: Valid generator key with future expiration
        // Payload: {"exp": 1893456000, "key_type": "generator"}
        let generatorKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE4OTM0NTYwMDAsImtleV90eXBlIjoiZ2VuZXJhdG9yIn0.signature"
        let expectedSdkKey = "generated-sdk-key"
        mockGeneratorClient.mockResponse = expectedSdkKey

        // When
        let result = try await sut.resolveApiKey(generatorKey)

        // Then
        XCTAssertEqual(result, expectedSdkKey)
        XCTAssertTrue(mockGeneratorClient.generateSdkKeyCalled)
        XCTAssertEqual(mockGeneratorClient.lastGeneratorKey, generatorKey)
    }

    func testResolveApiKey_withGeneratorKey_passesKeyToGeneratorClient() async throws {
        // Given
        let generatorKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE4OTM0NTYwMDAsImtleV90eXBlIjoiZ2VuZXJhdG9yIn0.signature"
        mockGeneratorClient.mockResponse = "sdk-key"

        // When
        _ = try await sut.resolveApiKey(generatorKey)

        // Then
        XCTAssertEqual(mockGeneratorClient.lastGeneratorKey, generatorKey)
    }

    // MARK: - Expiration Tests

    func testResolveApiKey_withExpiredSdkKey_throwsExpiredKey() async {
        // Given: Expired SDK key (exp in the past)
        // Payload: {"exp": 1600000000, "key_type": "sdk"}
        let expiredKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE2MDAwMDAwMDAsImtleV90eXBlIjoic2RrIn0.signature"

        // When/Then
        do {
            _ = try await sut.resolveApiKey(expiredKey)
            XCTFail("Expected expiredKey error")
        } catch let error as ApiKeyError {
            if case .expiredKey(let expiration) = error {
                XCTAssertEqual(expiration, 1_600_000_000)
            } else {
                XCTFail("Expected expiredKey error, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testResolveApiKey_withExpiredGeneratorKey_throwsExpiredKey() async {
        // Given: Expired generator key
        // Payload: {"exp": 1600000000, "key_type": "generator"}
        let expiredKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE2MDAwMDAwMDAsImtleV90eXBlIjoiZ2VuZXJhdG9yIn0.signature"

        // When/Then
        do {
            _ = try await sut.resolveApiKey(expiredKey)
            XCTFail("Expected expiredKey error")
        } catch let error as ApiKeyError {
            if case .expiredKey = error {
                // Expected
            } else {
                XCTFail("Expected expiredKey error, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testResolveApiKey_withExpiredKey_doesNotCallGeneratorClient() async {
        // Given
        let expiredKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE2MDAwMDAwMDAsImtleV90eXBlIjoiZ2VuZXJhdG9yIn0.signature"

        // When
        _ = try? await sut.resolveApiKey(expiredKey)

        // Then
        XCTAssertFalse(mockGeneratorClient.generateSdkKeyCalled)
    }

    // MARK: - Invalid Key Type Tests

    func testResolveApiKey_withInvalidKeyType_throwsInvalidKeyType() async {
        // Given: Key with invalid key_type
        // Payload: {"exp": 1893456000, "key_type": "invalid"}
        let invalidKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE4OTM0NTYwMDAsImtleV90eXBlIjoiaW52YWxpZCJ9.signature"

        // When/Then
        do {
            _ = try await sut.resolveApiKey(invalidKey)
            XCTFail("Expected invalidKeyType error")
        } catch let error as ApiKeyError {
            if case .invalidKeyType(let keyType) = error {
                XCTAssertEqual(keyType, "invalid")
            } else {
                XCTFail("Expected invalidKeyType error, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testResolveApiKey_withEmptyKeyType_throwsInvalidKeyType() async {
        // Given: Key with empty key_type
        // Payload: {"exp": 1893456000, "key_type": ""}
        let emptyTypeKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE4OTM0NTYwMDAsImtleV90eXBlIjoiIn0.signature"

        // When/Then
        do {
            _ = try await sut.resolveApiKey(emptyTypeKey)
            XCTFail("Expected invalidKeyType error")
        } catch let error as ApiKeyError {
            if case .invalidKeyType(let keyType) = error {
                XCTAssertEqual(keyType, "")
            } else {
                XCTFail("Expected invalidKeyType error, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Generator Client Error Tests

    func testResolveApiKey_whenGeneratorClientFails_propagatesError() async {
        // Given
        let generatorKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE4OTM0NTYwMDAsImtleV90eXBlIjoiZ2VuZXJhdG9yIn0.signature"
        mockGeneratorClient.mockError = ApiKeyError.generationFailed("Network error")

        // When/Then
        do {
            _ = try await sut.resolveApiKey(generatorKey)
            XCTFail("Expected error to be thrown")
        } catch let error as ApiKeyError {
            if case .generationFailed(let message) = error {
                XCTAssertEqual(message, "Network error")
            } else {
                XCTFail("Expected generationFailed error, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Invalid JWT Tests

    func testResolveApiKey_withInvalidJwt_throwsInvalidJwtFormat() async {
        // Given
        let invalidJwt = "not-a-valid-jwt"

        // When/Then
        do {
            _ = try await sut.resolveApiKey(invalidJwt)
            XCTFail("Expected invalidJwtFormat error")
        } catch let error as ApiKeyError {
            XCTAssertEqual(error, .invalidJwtFormat)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testResolveApiKey_withMissingClaims_throwsAppropriateError() async {
        // Given: JWT without key_type
        // Payload: {"exp": 1893456000}
        let missingKeyTypeJwt = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE4OTM0NTYwMDB9.signature"

        // When/Then
        do {
            _ = try await sut.resolveApiKey(missingKeyTypeJwt)
            XCTFail("Expected missingKeyType error")
        } catch let error as ApiKeyError {
            XCTAssertEqual(error, .missingKeyType)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

// MARK: - Mock Generator Client

@MainActor private class MockApiKeyGeneratorClient: ApiKeyGeneratorClient {
    var generateSdkKeyCalled = false
    var lastGeneratorKey: String?
    var mockResponse: String?
    var mockError: Error?

    override func generateSdkKey(from generatorKey: String) async throws -> String {
        generateSdkKeyCalled = true
        lastGeneratorKey = generatorKey

        if let error = mockError {
            throw error
        }

        return mockResponse ?? "mock-sdk-key"
    }
}
