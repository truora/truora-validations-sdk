import XCTest
@testable import TruoraValidationsSDK

@MainActor final class ApiKeyGeneratorClientTests: XCTestCase {
    private var sut: ApiKeyGeneratorClient!
    private var session: URLSession!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ApiKeyURLProtocolStub.self]
        session = URLSession(configuration: config)
        sut = ApiKeyGeneratorClient(session: session)
    }

    override func tearDown() {
        ApiKeyURLProtocolStub.stub = nil
        ApiKeyURLProtocolStub.capturedRequest = nil
        ApiKeyURLProtocolStub.capturedBodyString = nil
        sut = nil
        session = nil
        super.tearDown()
    }

    // MARK: - Success Tests

    func testGenerateSdkKey_withValidResponse_returnsApiKey() async throws {
        // Given
        let expectedApiKey = "generated-sdk-key-12345"
        let responseJson = """
        {"api_key": "\(expectedApiKey)", "message": "Key generated successfully"}
        """
        ApiKeyURLProtocolStub.stub = try .init(
            data: responseJson.data(using: .utf8),
            response: HTTPURLResponse(
                url: XCTUnwrap(URL(string: "https://api.account.truora.com/v1/api-keys")),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ),
            error: nil
        )

        // When
        let result = try await sut.generateSdkKey(from: "generator-key-xyz")

        // Then
        XCTAssertEqual(result, expectedApiKey)
    }

    func testGenerateSdkKey_withValidResponse_sendsCorrectHeaders() async throws {
        // Given
        let generatorKey = "test-generator-key"
        ApiKeyURLProtocolStub.stub = try .init(
            data: """
            {"api_key": "sdk-key", "message": "OK"}
            """.data(using: .utf8),
            response: HTTPURLResponse(
                url: XCTUnwrap(URL(string: "https://api.account.truora.com/v1/api-keys")),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            ),
            error: nil
        )
        ApiKeyURLProtocolStub.capturedRequest = nil

        // When
        _ = try await sut.generateSdkKey(from: generatorKey)

        // Then
        let capturedRequest = ApiKeyURLProtocolStub.capturedRequest
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Truora-API-Key"), generatorKey)
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Accept"), "application/json")
        XCTAssertEqual(capturedRequest?.httpMethod, "POST")
    }

    func testGenerateSdkKey_withValidResponse_sendsCorrectBody() async throws {
        // Given
        ApiKeyURLProtocolStub.stub = try .init(
            data: """
            {"api_key": "sdk-key", "message": "OK"}
            """.data(using: .utf8),
            response: HTTPURLResponse(
                url: XCTUnwrap(URL(string: "https://api.account.truora.com/v1/api-keys")),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            ),
            error: nil
        )
        ApiKeyURLProtocolStub.capturedBodyString = nil

        // When
        _ = try await sut.generateSdkKey(from: "generator-key")

        // Then
        let bodyString = ApiKeyURLProtocolStub.capturedBodyString ?? ""
        XCTAssertTrue(bodyString.contains("key_type=sdk"), "Body should contain key_type=sdk, got: \(bodyString)")
        XCTAssertTrue(bodyString.contains("grant=validations"), "Body should contain grant=validations, got: \(bodyString)")
        XCTAssertTrue(bodyString.contains("api_key_version=1"), "Body should contain api_key_version=1, got: \(bodyString)")
        XCTAssertTrue(bodyString.contains("key_name=sdk_usage"), "Body should contain key_name=sdk_usage, got: \(bodyString)")
    }

    // MARK: - Error Tests

    func testGenerateSdkKey_withHttpError_throwsGenerationFailed() async throws {
        // Given
        ApiKeyURLProtocolStub.stub = try .init(
            data: "Unauthorized".data(using: .utf8),
            response: HTTPURLResponse(
                url: XCTUnwrap(URL(string: "https://api.account.truora.com/v1/api-keys")),
                statusCode: 401,
                httpVersion: nil,
                headerFields: nil
            ),
            error: nil
        )

        // When/Then
        do {
            _ = try await sut.generateSdkKey(from: "invalid-key")
            XCTFail("Expected error to be thrown")
        } catch let error as ApiKeyError {
            if case .generationFailed(let message) = error {
                XCTAssertTrue(message.contains("401"))
            } else {
                XCTFail("Expected generationFailed error, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testGenerateSdkKey_withNetworkError_throwsGenerationFailed() async {
        // Given
        ApiKeyURLProtocolStub.stub = .init(
            data: nil,
            response: nil,
            error: URLError(.notConnectedToInternet)
        )

        // When/Then
        do {
            _ = try await sut.generateSdkKey(from: "generator-key")
            XCTFail("Expected error to be thrown")
        } catch let error as ApiKeyError {
            if case .generationFailed(let message) = error {
                XCTAssertFalse(message.isEmpty)
            } else {
                XCTFail("Expected generationFailed error, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testGenerateSdkKey_withInvalidJsonResponse_throwsGenerationFailed() async throws {
        // Given
        ApiKeyURLProtocolStub.stub = try .init(
            data: "not json".data(using: .utf8),
            response: HTTPURLResponse(
                url: XCTUnwrap(URL(string: "https://api.account.truora.com/v1/api-keys")),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            ),
            error: nil
        )

        // When/Then
        do {
            _ = try await sut.generateSdkKey(from: "generator-key")
            XCTFail("Expected error to be thrown")
        } catch let error as ApiKeyError {
            if case .generationFailed = error {
                // Expected
            } else {
                XCTFail("Expected generationFailed error, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testGenerateSdkKey_withMissingApiKeyInResponse_throwsGenerationFailed() async throws {
        // Given
        ApiKeyURLProtocolStub.stub = try .init(
            data: """
            {"message": "OK"}
            """.data(using: .utf8),
            response: HTTPURLResponse(
                url: XCTUnwrap(URL(string: "https://api.account.truora.com/v1/api-keys")),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            ),
            error: nil
        )

        // When/Then
        do {
            _ = try await sut.generateSdkKey(from: "generator-key")
            XCTFail("Expected error to be thrown")
        } catch let error as ApiKeyError {
            if case .generationFailed = error {
                // Expected - JSON decoding should fail
            } else {
                XCTFail("Expected generationFailed error, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - URL Tests

    func testGenerateSdkKey_usesCorrectEndpoint() async throws {
        // Given
        ApiKeyURLProtocolStub.stub = try .init(
            data: """
            {"api_key": "sdk-key", "message": "OK"}
            """.data(using: .utf8),
            response: HTTPURLResponse(
                url: XCTUnwrap(URL(string: "https://api.account.truora.com/v1/api-keys")),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            ),
            error: nil
        )
        ApiKeyURLProtocolStub.capturedRequest = nil

        // When
        _ = try await sut.generateSdkKey(from: "generator-key")

        // Then
        let capturedURL = ApiKeyURLProtocolStub.capturedRequest?.url?.absoluteString
        XCTAssertEqual(capturedURL, "https://api.account.truora.com/v1/api-keys")
    }
}

// MARK: - URLProtocol Stub

private struct ApiKeyURLProtocolStubResponse {
    let data: Data?
    let response: URLResponse?
    let error: Error?
}

private final class ApiKeyURLProtocolStub: URLProtocol {
    static var stub: ApiKeyURLProtocolStubResponse?
    static var capturedRequest: URLRequest?
    static var capturedBodyString: String?

    override static func canInit(with request: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.capturedRequest = request

        // Capture body from httpBody or httpBodyStream
        if let bodyData = request.httpBody {
            Self.capturedBodyString = String(data: bodyData, encoding: .utf8)
        } else if let stream = request.httpBodyStream {
            stream.open()
            var data = Data()
            let bufferSize = 1024
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            defer {
                buffer.deallocate()
                stream.close()
            }
            while stream.hasBytesAvailable {
                let read = stream.read(buffer, maxLength: bufferSize)
                if read > 0 {
                    data.append(buffer, count: read)
                }
            }
            Self.capturedBodyString = String(data: data, encoding: .utf8)
        }

        guard let stub = Self.stub else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        if let response = stub.response {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }
        if let data = stub.data {
            client?.urlProtocol(self, didLoad: data)
        }
        if let error = stub.error {
            client?.urlProtocol(self, didFailWithError: error)
        } else {
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}
