//
//  TruoraProcessEnvironmentTests.swift
//  TruoraValidationsSDKTests
//
//  Created by Truora on 30/07/26.
//

import XCTest
@testable import TruoraValidationsSDK

// MARK: - Test Helpers

/// `URLProtocol` stub that serves a canned `200` and records the request, so the tests
/// below can assert which host the client actually dialed.
private final class EnvironmentURLProtocolStub: URLProtocol {
    /// Any decodable process body — these tests assert the host dialed, not the payload.
    private static let processJson = #"{"process_id": "IDP123", "status": "pending"}"#

    static var lastRequest: URLRequest?

    static func reset() {
        lastRequest = nil
    }

    override static func canInit(with _: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.lastRequest = request

        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil),
              let data = Self.processJson.data(using: .utf8) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

// MARK: - Environment Tests

/// Host values are asserted literally on purpose: they must stay byte-identical to KMP
/// `DIEnvironment`, so a typo or a drift from the Kotlin side fails here.
@MainActor final class TruoraProcessEnvironmentTests: XCTestCase {
    override func tearDown() {
        EnvironmentURLProtocolStub.reset()
        super.tearDown()
    }

    // MARK: - Hosts

    func testProductionCarriesProductionHosts() {
        XCTAssertEqual(
            TruoraProcessEnvironment.production.baseUrl,
            "https://api.identity.truora.com/v1"
        )
        XCTAssertEqual(
            TruoraProcessEnvironment.production.consentsBaseUrl,
            "https://api.account.truora.com/v1"
        )
    }

    func testStagingCarriesStagingHosts() {
        XCTAssertEqual(
            TruoraProcessEnvironment.staging.baseUrl,
            "https://api.identity.truorastaging.com/v1"
        )
        XCTAssertEqual(
            TruoraProcessEnvironment.staging.consentsBaseUrl,
            "https://api.account.truorastaging.com/v1"
        )
    }

    // MARK: - Client base-URL resolution

    /// `defaultBaseUrl` is public API — deriving it from the environment must not move it.
    func testDefaultBaseUrlIsProductionProcessesHost() {
        XCTAssertEqual(
            TruoraProcessAPIClient.defaultBaseUrl,
            "https://api.identity.truora.com/v1/processes"
        )
    }

    /// Built without an `environment` or a `baseUrl`: the wire must still be production.
    func testClientDefaultsToProductionProcessesHost() async throws {
        let client = TruoraProcessAPIClient(apiKey: "test-api-key", session: makeSession())

        _ = try await client.readProcess(processId: "IDP123")

        XCTAssertEqual(
            EnvironmentURLProtocolStub.lastRequest?.url?.absoluteString,
            "https://api.identity.truora.com/v1/processes/IDP123"
        )
    }

    func testStagingClientDialsStagingProcessesHost() async throws {
        let client = TruoraProcessAPIClient(
            apiKey: "test-api-key",
            environment: .staging,
            session: makeSession()
        )

        _ = try await client.readProcess(processId: "IDP123")

        XCTAssertEqual(
            EnvironmentURLProtocolStub.lastRequest?.url?.absoluteString,
            "https://api.identity.truorastaging.com/v1/processes/IDP123"
        )
    }

    // MARK: - Helpers

    private func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [EnvironmentURLProtocolStub.self]
        return URLSession(configuration: config)
    }
}
