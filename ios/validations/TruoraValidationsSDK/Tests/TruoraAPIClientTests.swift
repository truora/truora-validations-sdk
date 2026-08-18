//
//  TruoraAPIClientTests.swift
//  TruoraValidationsSDKTests
//
//  Created by Truora on 25/01/26.
//

import XCTest
@testable import TruoraValidationsSDK

// MARK: - Test Helpers

private struct APIURLProtocolStubResponse {
    let data: Data?
    let response: URLResponse?
    let error: Error?
}

private final class APIURLProtocolStub: URLProtocol {
    static var stub: APIURLProtocolStubResponse?

    override static func canInit(with _: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
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

// MARK: - API Client Tests

@MainActor final class TruoraAPIClientTests: XCTestCase {
    private var sut: TruoraAPIClient!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [APIURLProtocolStub.self]
        let session = URLSession(configuration: config)
        // Use noRetry config for tests to avoid retry delays
        sut = TruoraAPIClient(
            apiKey: "test-api-key",
            sessionConfig: .noRetry,
            session: session
        )
    }

    override func tearDown() {
        APIURLProtocolStub.stub = nil
        sut = nil
        super.tearDown()
    }

    func testCreateValidation_success_returnsResponse() async throws {
        // Given
        let json = """
        {
            "validation_id": "test-id",
            "instructions": {
                "file_upload_link": "https://files.truora.com/upload"
            }
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let response = try XCTUnwrap(try HTTPURLResponse(
            url: XCTUnwrap(URL(string: "https://api.validations.truora.com/v1/validations")),
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        ))
        APIURLProtocolStub.stub = .init(data: data, response: response, error: nil)

        let request = NativeValidationRequest(
            type: "face-recognition",
            country: nil,
            accountId: "acc-123",
            threshold: 0.8,
            subvalidations: nil,
            documentType: nil,
            timeout: nil,
            userAuthorized: true,
            checkManualReviewAvailability: true
        )

        // When
        let result = try await sut.createValidation(request: request)

        // Then
        XCTAssertEqual(result.validationId, "test-id")
        XCTAssertEqual(result.instructions?.fileUploadLink, "https://files.truora.com/upload")
    }

    func testGetValidation_success_returnsDetail() async throws {
        // Given
        let json = """
        {
            "validation_id": "test-id",
            "validation_status": "success",
            "creation_date": "2025-01-01T00:00:00Z",
            "account_id": "acc-123",
            "type": "face-recognition",
            "details": {
                "face_recognition_validations": {
                    "confidence_score": 0.95
                }
            }
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let response = try XCTUnwrap(try HTTPURLResponse(
            url: XCTUnwrap(URL(string: "https://api.validations.truora.com/v1/validations/test-id?show_details=true")),
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        ))
        APIURLProtocolStub.stub = .init(data: data, response: response, error: nil)

        // When
        let result = try await sut.getValidation(validationId: "test-id")

        // Then
        XCTAssertEqual(result.validationId, "test-id")
        XCTAssertEqual(result.validationStatus, "success")
        XCTAssertEqual(result.details?.faceRecognitionValidations?.confidenceScore, 0.95)
    }

    // MARK: - Form Encoding Drift Guard

    /// Guards against adding a field to `NativeValidationRequest` without also
    /// emitting it from `TruoraAPIClient.encodeToFormData`. If this test fails
    /// after you added a field, wire it into the encoder.
    func testEncodeToFormData_includesAllNonNilFields() {
        // Given — every optional/required field set to a distinct, decodable value
        let request = NativeValidationRequest(
            type: "document-validation",
            country: "co",
            accountId: "acc-123",
            threshold: 0.75,
            subvalidations: ["similarity", "passive_liveness"],
            documentType: "invoice",
            timeout: 60,
            userAuthorized: true,
            checkManualReviewAvailability: true,
            retryOfId: "VLD-abc"
        )

        // When
        let form = sut.encodeToFormData(request)
        // Parse back so we don't rely on item order or URL-escaping details
        var components = URLComponents()
        components.query = form
        let pairs = (components.queryItems ?? [])
            .reduce(into: [String: [String]]()) { acc, item in
                acc[item.name, default: []].append(item.value ?? "")
            }

        // Then — required fields
        XCTAssertEqual(pairs["type"], ["document-validation"])
        XCTAssertEqual(pairs["account_id"], ["acc-123"])
        XCTAssertEqual(pairs["user_authorized"], ["true"])
        XCTAssertEqual(pairs["check_manual_review_availability"], ["true"])

        // Optional fields — every property present on the struct should be here.
        XCTAssertEqual(pairs["country"], ["co"])
        XCTAssertEqual(pairs["document_type"], ["invoice"])
        XCTAssertEqual(pairs["threshold"], ["0.75"])
        XCTAssertEqual(pairs["timeout"], ["60"])
        XCTAssertEqual(pairs["retry_of_id"], ["VLD-abc"])
        // Repeated key — array fields must encode as multiple URL items, not a joined string
        XCTAssertEqual(pairs["subvalidations"]?.sorted(), ["passive_liveness", "similarity"])
    }

    func testEncodeToFormData_omitsNilOptionalFields() {
        // Given — only the required fields
        let request = NativeValidationRequest(
            type: "face-recognition",
            country: nil,
            accountId: "acc-123",
            threshold: nil,
            subvalidations: nil,
            documentType: nil,
            timeout: nil,
            userAuthorized: true,
            checkManualReviewAvailability: true
        )

        // When
        let form = sut.encodeToFormData(request)
        var components = URLComponents()
        components.query = form
        let keys = Set((components.queryItems ?? []).map(\.name))

        // Then — nil optionals stay out of the body so the backend uses its defaults
        XCTAssertFalse(keys.contains("country"))
        XCTAssertFalse(keys.contains("document_type"))
        XCTAssertFalse(keys.contains("threshold"))
        XCTAssertFalse(keys.contains("timeout"))
        XCTAssertFalse(keys.contains("subvalidations"))
        XCTAssertFalse(keys.contains("retry_of_id"))
    }

    func testCreateEnrollment_success_returnsResponse() async throws {
        // Given
        let json = """
        {
            "enrollment_id": "enroll-id",
            "account_id": "acc-123",
            "status": "pending",
            "creation_date": "2025-01-01T00:00:00Z",
            "file_upload_link": "https://files.truora.com/enroll-upload"
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let response = try XCTUnwrap(try HTTPURLResponse(
            url: XCTUnwrap(URL(string: "https://api.validations.truora.com/v1/enrollments")),
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        ))
        APIURLProtocolStub.stub = .init(data: data, response: response, error: nil)

        let request = NativeEnrollmentRequest(
            type: "face-recognition",
            userAuthorized: true,
            accountId: "acc-123",
            confirmation: nil
        )

        // When
        let result = try await sut.createEnrollment(request: request)

        // Then
        XCTAssertEqual(result.enrollmentId, "enroll-id")
        XCTAssertEqual(result.fileUploadLink, "https://files.truora.com/enroll-upload")
    }

    func testUploadFile_success() async throws {
        // Given
        let response = try XCTUnwrap(try HTTPURLResponse(
            url: XCTUnwrap(URL(string: "https://presigned.url")),
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        ))
        APIURLProtocolStub.stub = .init(data: Data(), response: response, error: nil)

        // When/Then
        try await sut.uploadFile(
            uploadUrl: "https://presigned.url",
            fileData: Data([0x01, 0x02]),
            contentType: "image/png"
        )
    }

    func testEvaluateImage_success_returnsFeedback() async throws {
        // Given
        let json = """
        {
            "status": "failure",
            "feedback": {
                "reason": "blurry_image",
                "hints": ["Try holding the camera steady"]
            }
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let response = try XCTUnwrap(try HTTPURLResponse(
            url: XCTUnwrap(URL(string: "https://api.validations.truora.com/v1/evaluate-image")),
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        ))
        APIURLProtocolStub.stub = .init(data: data, response: response, error: nil)

        let request = NativeImageEvaluationRequest(
            image: "base64encodedimage",
            country: "CO",
            documentType: "national-id",
            documentSide: "front",
            validationId: "val-123",
            evaluationType: "document"
        )

        // When
        let result = try await sut.evaluateImage(request: request)

        // Then
        XCTAssertEqual(result.status, "failure")
        XCTAssertEqual(result.feedback?.reason, "blurry_image")
        XCTAssertEqual(result.feedback?.hints?.first, "Try holding the camera steady")
    }

    func testEvaluateImage_success_noFeedback() async throws {
        // Given
        let json = """
        {
            "status": "success"
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let response = try XCTUnwrap(try HTTPURLResponse(
            url: XCTUnwrap(URL(string: "https://api.validations.truora.com/v1/evaluate-image")),
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        ))
        APIURLProtocolStub.stub = .init(data: data, response: response, error: nil)

        let request = NativeImageEvaluationRequest(
            image: "base64encodedimage",
            country: "CO",
            documentType: "national-id",
            documentSide: "front",
            validationId: "val-123",
            evaluationType: "document"
        )

        // When
        let result = try await sut.evaluateImage(request: request)

        // Then
        XCTAssertEqual(result.status, "success")
        XCTAssertNil(result.feedback)
    }

    func testAPIError_unauthorized_throwsUnauthorized() async throws {
        // Given
        let response = try XCTUnwrap(try HTTPURLResponse(
            url: XCTUnwrap(URL(string: "https://any.url")),
            statusCode: 401,
            httpVersion: nil,
            headerFields: nil
        ))
        APIURLProtocolStub.stub = .init(data: Data(), response: response, error: nil)

        // When/Then
        do {
            _ = try await sut.getValidation(validationId: "test")
            XCTFail("Should have thrown unauthorized error")
        } catch let error as TruoraAPIError {
            if case .unauthorized = error {
                // Success
            } else {
                XCTFail("Expected .unauthorized, got \(error)")
            }
        } catch {
            XCTFail("Expected TruoraAPIError, got \(error)")
        }
    }

    func testGetDocumentSelection_success_returnsResponse() async throws {
        // Given
        let json = """
        {
            "countries": [
                {
                    "country": "CO",
                    "display_name": "Colombia",
                    "flag": {
                        "url": "https://example.com/flag.png"
                    },
                    "document_types": [
                        {
                            "document_type": "national-id",
                            "display_name": "National ID",
                            "examples": []
                        }
                    ]
                }
            ]
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let response = try XCTUnwrap(try HTTPURLResponse(
            url: XCTUnwrap(URL(string: "https://api.validations.truora.com/v1/config/document-selection")),
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        ))
        APIURLProtocolStub.stub = .init(data: data, response: response, error: nil)

        // When
        let result = try await sut.getDocumentSelection()

        // Then
        XCTAssertEqual(result.countries.count, 1)
        XCTAssertEqual(result.countries[0].country, "CO")
        XCTAssertEqual(result.countries[0].displayName, "Colombia")
        XCTAssertEqual(result.countries[0].flag.url, "https://example.com/flag.png")
        XCTAssertEqual(result.countries[0].documentTypes.count, 1)
        XCTAssertEqual(result.countries[0].documentTypes[0].documentType, "national-id")
        XCTAssertEqual(result.countries[0].documentTypes[0].displayName, "National ID")
        XCTAssertEqual(result.countries[0].documentTypes[0].examples.count, 0)
    }
}
