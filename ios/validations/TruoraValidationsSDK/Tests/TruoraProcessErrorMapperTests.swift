//
//  TruoraProcessErrorMapperTests.swift
//  TruoraValidationsSDKTests
//
//  Created by Truora on 01/07/26.
//

import XCTest
@testable import TruoraValidationsSDK

final class TruoraProcessErrorMapperTests: XCTestCase {
    // MARK: - Status mapping

    func testMapsStatusCodesToErrors() {
        XCTAssertEqual(TruoraProcessErrorMapper.from(httpCode: 400, responseBody: nil).kind, .invalidRequest)
        XCTAssertEqual(TruoraProcessErrorMapper.from(httpCode: 404, responseBody: nil).kind, .notFound)
        XCTAssertEqual(TruoraProcessErrorMapper.from(httpCode: 409, responseBody: nil).kind, .conflict)
        XCTAssertEqual(TruoraProcessErrorMapper.from(httpCode: 410, responseBody: nil).kind, .processExpired)
        XCTAssertEqual(TruoraProcessErrorMapper.from(httpCode: 429, responseBody: nil).kind, .rateLimit)
        XCTAssertEqual(TruoraProcessErrorMapper.from(httpCode: 503, responseBody: nil).kind, .server)
        XCTAssertEqual(TruoraProcessErrorMapper.from(httpCode: 418, responseBody: nil).kind, .unknown)
    }

    func testServerErrorRetainsHttpCode() {
        let error = TruoraProcessErrorMapper.from(httpCode: 502, responseBody: nil)
        XCTAssertEqual(error.kind, .server)
        XCTAssertEqual(error.httpCode, 502)
    }

    // MARK: - Message-marker precedence

    func testMessageMarkersTakePrecedenceOverStatus() {
        let readOnlyBody = #"{"code":"11400","http_code":400,"message":"the field is read only"}"#
        XCTAssertEqual(TruoraProcessErrorMapper.from(httpCode: 400, responseBody: readOnlyBody).kind, .readOnlyField)

        let rateBody = #"{"code":"11400","http_code":400,"message":"max rate limit reached"}"#
        XCTAssertEqual(TruoraProcessErrorMapper.from(httpCode: 400, responseBody: rateBody).kind, .rateLimit)

        let stepTypeBody = #"{"code":"11400","http_code":400,"message":"Invalid step type"}"#
        XCTAssertEqual(TruoraProcessErrorMapper.from(httpCode: 400, responseBody: stepTypeBody).kind, .unsupportedStep)
    }

    func testUnrelatedMessageFallsBackToStatus() {
        let body = #"{"code":"11400","http_code":400,"message":"invalid postal code"}"#
        XCTAssertEqual(TruoraProcessErrorMapper.from(httpCode: 400, responseBody: body).kind, .invalidRequest)
    }

    // MARK: - Retriability

    func testOnlyTransientErrorsAreRetriable() {
        XCTAssertTrue(TruoraProcessApiError.rateLimit().isRetriable)
        XCTAssertTrue(TruoraProcessApiError.server(httpCode: 500).isRetriable)
        XCTAssertTrue(TruoraProcessApiError.network().isRetriable)

        XCTAssertFalse(TruoraProcessApiError.invalidRequest().isRetriable)
        XCTAssertFalse(TruoraProcessApiError.notFound().isRetriable)
        XCTAssertFalse(TruoraProcessApiError.conflict().isRetriable)
        XCTAssertFalse(TruoraProcessApiError.processExpired().isRetriable)
        XCTAssertFalse(TruoraProcessApiError.invalidStep().isRetriable)
        XCTAssertFalse(TruoraProcessApiError.unsupportedStep().isRetriable)
        XCTAssertFalse(TruoraProcessApiError.readOnlyField().isRetriable)
        XCTAssertFalse(TruoraProcessApiError.unknown(httpCode: 418, message: "teapot").isRetriable)
    }

    // MARK: - from(apiError:)

    func testFromApiErrorMapsUsingParsedBody() {
        let apiError = ApiErrorResponse(code: "11429", httpCode: 429, message: "Max rate limit reached")
        let mapped = TruoraProcessErrorMapper.from(apiError: apiError)

        XCTAssertEqual(mapped.kind, .rateLimit)
        XCTAssertTrue(mapped.isRetriable)
        XCTAssertEqual(mapped.apiErrorResponse, apiError)
    }

    // MARK: - from(error:)

    func testFromTransportServerErrorMapsByStatus() {
        let transport = TruoraProcessAPIError.serverError(statusCode: 500, body: nil)
        let mapped = TruoraProcessErrorMapper.from(error: transport)

        XCTAssertEqual(mapped.kind, .server)
        XCTAssertTrue(mapped.isRetriable)
    }

    func testFromTransportNetworkErrorIsRetriableNetwork() {
        let transport = TruoraProcessAPIError.networkError(URLError(.timedOut))
        let mapped = TruoraProcessErrorMapper.from(error: transport)

        XCTAssertEqual(mapped.kind, .network)
        XCTAssertTrue(mapped.isRetriable)
    }

    func testFromTransportDecodingErrorIsNonRetriableUnknown() {
        let transport = TruoraProcessAPIError.decodingError(URLError(.cannotDecodeContentData))
        let mapped = TruoraProcessErrorMapper.from(error: transport)

        XCTAssertEqual(mapped.kind, .unknown)
        XCTAssertFalse(mapped.isRetriable)
    }

    func testFromRawURLErrorIsRetriableNetwork() {
        let mapped = TruoraProcessErrorMapper.from(error: URLError(.networkConnectionLost))

        XCTAssertEqual(mapped.kind, .network)
        XCTAssertTrue(mapped.isRetriable)
    }

    func testFromTruoraProcessApiErrorReturnsSameValue() {
        let original = TruoraProcessApiError.rateLimit()
        XCTAssertEqual(TruoraProcessErrorMapper.from(error: original), original)
    }
}
