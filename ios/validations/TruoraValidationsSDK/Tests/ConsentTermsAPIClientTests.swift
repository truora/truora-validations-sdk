//
//  ConsentTermsAPIClientTests.swift
//  TruoraValidationsSDKTests
//

import XCTest
@testable import TruoraValidationsSDK

// MARK: - Test Helpers

private struct ConsentTermsURLProtocolStubResponse {
    let data: Data?
    let response: URLResponse?
    let error: Error?
}

/// `URLProtocol` stub serving a canned response and recording the last request,
/// mirroring the `TruoraProcessAPIClientTests` harness.
private final class ConsentTermsURLProtocolStub: URLProtocol {
    static var stub: ConsentTermsURLProtocolStubResponse?
    static var lastRequest: URLRequest?
    static var requestCount = 0

    static func reset() {
        stub = nil
        lastRequest = nil
        requestCount = 0
    }

    override static func canInit(with _: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.lastRequest = request
        Self.requestCount += 1

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

// MARK: - Consent Terms API Client Tests

@MainActor final class ConsentTermsAPIClientTests: XCTestCase {
    private var sut: ConsentTermsAPIClient!
    private let baseUrl = "https://api.account.truora.com/v1/consent-terms"

    private let sampleTermsJSON = """
    {
        "client_id": "TCI001",
        "terms_id": "DPCT49988535f7c3090721834149b8783f91",
        "version": "3",
        "creation_date": "2024-01-10T12:00:00Z",
        "terms": {
            "ALL": {"es": "Texto general", "en": "General text", "pt": "Texto geral"},
            "CO": {"es": "Texto CO"},
            "ALL-credit_bureau": {"es": "Texto centrales de riesgo", "en": "Credit bureau text"},
            "MX-face_search": {"es": "Texto biométrico MX"}
        }
    }
    """

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ConsentTermsURLProtocolStub.self]
        let session = URLSession(configuration: config)
        // noRetry avoids retry delays in tests.
        sut = ConsentTermsAPIClient(
            apiKey: "test-process-token",
            sessionConfig: .noRetry,
            session: session
        )
    }

    override func tearDown() {
        ConsentTermsURLProtocolStub.reset()
        sut = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func stub(json: String, status statusCode: Int = 200, url: String = "https://any.url") throws {
        let data = try XCTUnwrap(json.data(using: .utf8))
        let response = try XCTUnwrap(try HTTPURLResponse(
            url: XCTUnwrap(URL(string: url)),
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        ))
        ConsentTermsURLProtocolStub.stub = .init(data: data, response: response, error: nil)
    }

    private func assertThrowsDIAPIError(
        _ expected: TruoraProcessAPIError,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ body: () async throws -> Void
    ) async {
        do {
            try await body()
            XCTFail("Expected \(expected) to be thrown", file: file, line: line)
        } catch let error as TruoraProcessAPIError {
            XCTAssertEqual(error, expected, file: file, line: line)
        } catch {
            XCTFail("Expected TruoraProcessAPIError, got \(error)", file: file, line: line)
        }
    }

    // MARK: - Request building

    func testFetchTermsBuildsURLHeadersAndAppendsTermsTrue() async throws {
        try stub(json: sampleTermsJSON)

        _ = try await sut.fetchTerms(
            termsId: "default-basic",
            queryItems: [
                URLQueryItem(name: "CO.name", value: "Acme"),
                URLQueryItem(name: "CO.nit", value: "900123")
            ]
        )

        let request = try XCTUnwrap(ConsentTermsURLProtocolStub.lastRequest)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(
            request.url?.absoluteString,
            "\(baseUrl)/default-basic?CO.name=Acme&CO.nit=900123&terms=true"
        )
        XCTAssertEqual(request.value(forHTTPHeaderField: "Truora-API-Key"), "test-process-token")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
    }

    func testFetchTermsAppendsTermsTrueWithoutCompanyParams() async throws {
        try stub(json: sampleTermsJSON)

        _ = try await sut.fetchTerms(termsId: "default-items")

        let request = try XCTUnwrap(ConsentTermsURLProtocolStub.lastRequest)
        XCTAssertEqual(request.url?.absoluteString, "\(baseUrl)/default-items?terms=true")
    }

    func testFetchTermsPercentEncodesCompanyNames() async throws {
        try stub(json: sampleTermsJSON)

        _ = try await sut.fetchTerms(
            termsId: "default-basic",
            queryItems: [URLQueryItem(name: "CO.name", value: "Acme Corp & Cía")]
        )

        let url = try XCTUnwrap(ConsentTermsURLProtocolStub.lastRequest?.url?.absoluteString)
        XCTAssertTrue(url.contains("CO.name=Acme%20Corp%20%26%20C%C3%ADa"), "Got \(url)")
    }

    func testFetchTermsUsesInjectedBaseUrl() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ConsentTermsURLProtocolStub.self]
        let staging = ConsentTermsAPIClient(
            apiKey: "test-process-token",
            baseUrl: "https://api.account.truorastaging.com/v1",
            sessionConfig: .noRetry,
            session: URLSession(configuration: config)
        )
        try stub(json: sampleTermsJSON)

        _ = try await staging.fetchTerms(termsId: "default-basic")

        XCTAssertEqual(
            ConsentTermsURLProtocolStub.lastRequest?.url?.absoluteString,
            "https://api.account.truorastaging.com/v1/consent-terms/default-basic?terms=true"
        )
    }

    func testFetchTermsRejectsEmptyTermsId() async {
        await assertThrowsDIAPIError(.invalidURL) {
            _ = try await self.sut.fetchTerms(termsId: "")
        }
    }

    // MARK: - Response decoding

    func testFetchTermsDecodesResponse() async throws {
        try stub(json: sampleTermsJSON)

        let response = try await sut.fetchTerms(termsId: "default-items")

        XCTAssertEqual(response.termsId, "DPCT49988535f7c3090721834149b8783f91")
        XCTAssertEqual(response.clientId, "TCI001")
        XCTAssertEqual(response.version, "3")
        XCTAssertEqual(response.terms?["ALL"]?["es"], "Texto general")
        XCTAssertEqual(response.terms?["CO"]?["es"], "Texto CO")
        XCTAssertEqual(response.terms?["ALL-credit_bureau"]?["en"], "Credit bureau text")
        XCTAssertEqual(response.terms?["MX-face_search"]?["es"], "Texto biométrico MX")
    }

    /// When the request carries no company params the service still answers 200,
    /// with the stored Go templates unparsed. That is a valid response: the copy
    /// decodes and flows through verbatim, `{{.company}}` tokens included.
    func testFetchTermsDecodesUnsubstitutedTemplatesAs200() async throws {
        try stub(json: """
        {
            "terms_id": "DPCTa522413fab9a886971c8a6d3fb5bf852",
            "terms": {
                "ALL": {"es": "Autorizo a {{.company}} para que, a través de {{.truora}}, consulte mis datos."}
            }
        }
        """)

        let response = try await sut.fetchTerms(termsId: "default-basic")

        XCTAssertEqual(
            response.terms?["ALL"]?["es"],
            "Autorizo a {{.company}} para que, a través de {{.truora}}, consulte mis datos."
        )
    }

    // MARK: - Errors

    func testFetchTermsThrowsUnauthorizedOn401() async throws {
        try stub(json: #"{"code": 10001}"#, status: 401)

        await assertThrowsDIAPIError(.unauthorized(body: #"{"code": 10001}"#)) {
            _ = try await self.sut.fetchTerms(termsId: "default-basic")
        }
    }

    func testFetchTermsThrowsServerErrorOnNon2xx() async throws {
        try stub(json: "oops", status: 500)

        await assertThrowsDIAPIError(.serverError(statusCode: 500, body: "oops")) {
            _ = try await self.sut.fetchTerms(termsId: "default-basic")
        }
    }

    func testFetchTermsThrowsDecodingErrorOnMalformedBody() async throws {
        try stub(json: #"{"terms": "not-a-map"}"#)

        do {
            _ = try await sut.fetchTerms(termsId: "default-basic")
            XCTFail("Expected decodingError")
        } catch let error as TruoraProcessAPIError {
            guard case .decodingError = error else {
                return XCTFail("Expected decodingError, got \(error)")
            }
        } catch {
            XCTFail("Expected TruoraProcessAPIError, got \(error)")
        }
    }

    func testFetchTermsWrapsTransportFailuresAsNetworkError() async {
        ConsentTermsURLProtocolStub.stub = .init(data: nil, response: nil, error: URLError(.notConnectedToInternet))

        do {
            _ = try await sut.fetchTerms(termsId: "default-basic")
            XCTFail("Expected networkError")
        } catch let error as TruoraProcessAPIError {
            guard case .networkError = error else {
                return XCTFail("Expected networkError, got \(error)")
            }
        } catch {
            XCTFail("Expected TruoraProcessAPIError, got \(error)")
        }
    }
}
