//
//  TruoraProcessAPIClientTests.swift
//  TruoraValidationsSDKTests
//
//  Created by Truora on 15/06/26.
//

import XCTest
@testable import TruoraValidationsSDK

// MARK: - Test Helpers

private struct TruoraURLProtocolStubResponse {
    let data: Data?
    let response: URLResponse?
    let error: Error?
}

/// `URLProtocol` stub that both serves a canned response and records the last
/// request so tests can assert method / path / headers. (URLSession streams the
/// body away during dispatch, so request bodies are covered by the encoder
/// tests in `TruoraProcessRequestsTests` rather than here.)
private final class TruoraURLProtocolStub: URLProtocol {
    static var stub: TruoraURLProtocolStubResponse?
    static var lastRequest: URLRequest?
    /// Counts requests that reach the wire, so tests can assert how many attempts
    /// a retry layer made.
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

// MARK: - DI API Client Tests

@MainActor final class TruoraProcessAPIClientTests: XCTestCase {
    private var sut: TruoraProcessAPIClient!
    private let baseUrl = "https://api.identity.truora.com/v1/processes"

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [TruoraURLProtocolStub.self]
        let session = URLSession(configuration: config)
        // noRetry avoids retry delays in tests.
        sut = TruoraProcessAPIClient(
            apiKey: "test-api-key",
            sessionConfig: .noRetry,
            session: session
        )
    }

    override func tearDown() {
        TruoraURLProtocolStub.reset()
        sut = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func stubOK(json: String, url: String) throws {
        let data = try XCTUnwrap(json.data(using: .utf8))
        let response = try XCTUnwrap(try HTTPURLResponse(
            url: XCTUnwrap(URL(string: url)),
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        ))
        TruoraURLProtocolStub.stub = .init(data: data, response: response, error: nil)
    }

    private func stubStatus(_ statusCode: Int, url: String = "https://any.url") throws {
        let response = try XCTUnwrap(try HTTPURLResponse(
            url: XCTUnwrap(URL(string: url)),
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        ))
        TruoraURLProtocolStub.stub = .init(data: Data(), response: response, error: nil)
    }

    private func stub(json: String, status statusCode: Int, url: String) throws {
        let data = try XCTUnwrap(json.data(using: .utf8))
        let response = try XCTUnwrap(try HTTPURLResponse(
            url: XCTUnwrap(URL(string: url)),
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        ))
        TruoraURLProtocolStub.stub = .init(data: data, response: response, error: nil)
    }

    private func sampleBlock() -> TruoraBlockInput {
        TruoraBlockInput(type: .documentVerification, config: ["country": .string("CO")])
    }

    // MARK: - Transport retry ownership

    /// The DI client's *default* transport must not retry: `TruoraProcessRequestExecutor` and
    /// `MediaUploader` each own a retry budget above it, and a retrying transport
    /// would multiply their attempts rather than bound them.
    ///
    /// Built without an explicit `sessionConfig` on purpose — every other test here
    /// passes `.noRetry`, which is exactly why none of them would catch a regression
    /// in the default.
    func testDefaultSessionConfigDoesNotRetryTransientFailures() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [TruoraURLProtocolStub.self]
        let session = URLSession(configuration: config)
        let client = TruoraProcessAPIClient(apiKey: "test-api-key", session: session)

        try stubStatus(503, url: "\(baseUrl)/IPR1")

        await assertThrowsTruoraProcessAPIError(.serverError(statusCode: 503, body: "")) {
            _ = try await client.readProcess(processId: "IPR1")
        }

        XCTAssertEqual(TruoraURLProtocolStub.requestCount, 1, "A 503 must reach the wire exactly once")
    }

    private func assertLastRequest(method: String, path: String) {
        let request = TruoraURLProtocolStub.lastRequest
        XCTAssertEqual(request?.httpMethod, method)
        XCTAssertEqual(request?.url?.absoluteString, "\(baseUrl)\(path)")
        XCTAssertEqual(request?.value(forHTTPHeaderField: "Truora-API-Key"), "test-api-key")
    }

    // MARK: - createProcess

    func testCreateProcess_success_returnsResponse() async throws {
        try stubOK(
            json: #"{"process_id": "IDP123", "status": "pending", "account_id": "a", "client_id": "c"}"#,
            url: baseUrl
        )

        let result = try await sut.createProcess(
            request: TruoraCreateProcessRequest(block: sampleBlock(), ttl: 300)
        )

        XCTAssertEqual(result.processId, "IDP123")
        XCTAssertEqual(result.status, .pending)
        assertLastRequest(method: "POST", path: "")
        XCTAssertEqual(
            TruoraURLProtocolStub.lastRequest?.value(forHTTPHeaderField: "Content-Type"),
            "application/json"
        )
    }

    func testCreateProcess_networkError_throwsNetworkError() async {
        TruoraURLProtocolStub.stub = .init(data: nil, response: nil, error: URLError(.notConnectedToInternet))

        await assertThrowsTruoraProcessAPIError(.networkError(URLError(.notConnectedToInternet))) {
            _ = try await self.sut.createProcess(
                request: TruoraCreateProcessRequest(block: self.sampleBlock())
            )
        }
    }

    // MARK: - createOrRead

    func testCreateOrRead_status201_reportsCreated() async throws {
        try stub(
            json: #"{"process_id": "IDP201", "status": "pending"}"#,
            status: 201,
            url: baseUrl
        )

        let result = try await sut.createOrRead()

        XCTAssertTrue(result.created)
        XCTAssertEqual(result.process.processId, "IDP201")
        assertLastRequest(method: "POST", path: "")
    }

    func testCreateOrRead_status200_reportsRead() async throws {
        try stub(
            json: #"{"process_id": "IDP200", "status": "pending"}"#,
            status: 200,
            url: baseUrl
        )

        let result = try await sut.createOrRead()

        XCTAssertFalse(result.created)
        XCTAssertEqual(result.process.processId, "IDP200")
        assertLastRequest(method: "POST", path: "")
    }

    func testCreateOrRead_serverError_throws() async throws {
        try stubStatus(400)

        await assertThrowsTruoraProcessAPIError(.serverError(statusCode: 400, body: "")) {
            _ = try await self.sut.createOrRead()
        }
    }

    // MARK: - readProcess

    func testReadProcess_success_returnsResponse() async throws {
        try stubOK(
            json: #"{"process_id": "IDP123", "status": "success"}"#,
            url: "\(baseUrl)/IDP123"
        )

        let result = try await sut.readProcess(processId: "IDP123")

        XCTAssertEqual(result.processId, "IDP123")
        XCTAssertEqual(result.status, .success)
        assertLastRequest(method: "GET", path: "/IDP123")
    }

    func testReadProcess_emptyProcessId_throws() async {
        await assertThrowsTruoraProcessAPIError(.emptyProcessId) {
            _ = try await self.sut.readProcess(processId: "")
        }
    }

    // MARK: - addBlock

    func testAddBlock_success_returnsResponse() async throws {
        try stubOK(
            json: #"{"verification_id": "VRF1", "step_id": "STP1", "step_type": "enter_document_type"}"#,
            url: "\(baseUrl)/IDP123/verifications"
        )

        let result = try await sut.addBlock(
            processId: "IDP123",
            request: TruoraAddBlockRequest(block: sampleBlock())
        )

        XCTAssertEqual(result.blockId, "VRF1")
        XCTAssertEqual(result.stepId, "STP1")
        XCTAssertEqual(result.stepType, .enterDocumentType)
        assertLastRequest(method: "POST", path: "/IDP123/verifications")
    }

    func testAddBlock_emptyProcessId_throws() async {
        await assertThrowsTruoraProcessAPIError(.emptyProcessId) {
            _ = try await self.sut.addBlock(
                processId: "",
                request: TruoraAddBlockRequest(block: self.sampleBlock())
            )
        }
    }

    // MARK: - verifyStep

    func testVerifyStep_success_returnsStep() async throws {
        try stubOK(
            json: #"{"step_id": "STP1", "type": "take_document_photo"}"#,
            url: "\(baseUrl)/steps/STP1"
        )

        let step = TruoraStep(
            stepId: "STP1",
            type: .enterDocumentType,
            expectedInputs: [TruoraInput(type: "text", name: "country")]
        )

        let result = try await sut.verifyStep(
            stepId: "STP1",
            request: TruoraVerifyStepRequest(
                step: step.settingInputValues([TruoraStepInputValue(type: "text", name: "country", value: "CO")])
            )
        )

        XCTAssertEqual(result.stepId, "STP1")
        XCTAssertEqual(result.type, .takeDocumentPhoto)
        assertLastRequest(method: "POST", path: "/steps/STP1")
    }

    func testVerifyStep_emptyStepId_throws() async {
        await assertThrowsTruoraProcessAPIError(.emptyStepId) {
            _ = try await self.sut.verifyStep(
                stepId: "",
                request: TruoraVerifyStepRequest(step: TruoraStep(stepId: "", type: .enterAuthorization))
            )
        }
    }

    // MARK: - backStep

    func testBackStep_success_returnsStep() async throws {
        try stubOK(
            json: #"{"step_id": "STP0", "type": "enter_document_type"}"#,
            url: "\(baseUrl)/steps/STP1/back"
        )

        let result = try await sut.backStep(
            stepId: "STP1",
            request: TruoraBackStepRequest(retryStep: true, deleteAll: false)
        )

        XCTAssertEqual(result.stepId, "STP0")
        XCTAssertEqual(result.type, .enterDocumentType)
        assertLastRequest(method: "POST", path: "/steps/STP1/back")
    }

    func testBackStep_emptyStepId_throws() async {
        await assertThrowsTruoraProcessAPIError(.emptyStepId) {
            _ = try await self.sut.backStep(
                stepId: "",
                request: TruoraBackStepRequest(retryStep: true, deleteAll: false)
            )
        }
    }

    // MARK: - cancelProcess

    func testCancelProcess_success_returnsResponse() async throws {
        try stubOK(
            json: #"{"process_id": "IDP123", "status": "failure", "failure_status": "canceled"}"#,
            url: "\(baseUrl)/IDP123/status"
        )

        let result = try await sut.cancelProcess(
            processId: "IDP123",
            request: TruoraCancelProcessRequest(failureStatus: .canceled, canceledReason: "user_canceled")
        )

        XCTAssertEqual(result.processId, "IDP123")
        XCTAssertEqual(result.failureStatus, .canceled)
        assertLastRequest(method: "POST", path: "/IDP123/status")
    }

    func testCancelProcess_emptyProcessId_throws() async {
        await assertThrowsTruoraProcessAPIError(.emptyProcessId) {
            _ = try await self.sut.cancelProcess(
                processId: "",
                request: TruoraCancelProcessRequest(failureStatus: .canceled)
            )
        }
    }

    // MARK: - uploadFile

    func testUploadFile_success() async throws {
        let response = try XCTUnwrap(try HTTPURLResponse(
            url: XCTUnwrap(URL(string: "https://presigned.url")),
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        ))
        TruoraURLProtocolStub.stub = .init(data: Data(), response: response, error: nil)

        try await sut.uploadFile(
            uploadUrl: "https://presigned.url",
            fileData: Data([0x01, 0x02]),
            contentType: "image/jpeg"
        )

        XCTAssertEqual(TruoraURLProtocolStub.lastRequest?.httpMethod, "PUT")
        XCTAssertEqual(
            TruoraURLProtocolStub.lastRequest?.value(forHTTPHeaderField: "Content-Type"),
            "image/jpeg"
        )
    }

    func testUploadFile_emptyUrl_throws() async {
        await assertThrowsTruoraProcessAPIError(.emptyUploadUrl) {
            try await self.sut.uploadFile(uploadUrl: "", fileData: Data([0x01]), contentType: "image/jpeg")
        }
    }

    func testUploadFile_emptyData_throws() async {
        await assertThrowsTruoraProcessAPIError(.emptyFileData) {
            try await self.sut.uploadFile(
                uploadUrl: "https://presigned.url",
                fileData: Data(),
                contentType: "image/jpeg"
            )
        }
    }

    // MARK: - Error Mapping

    func testUnauthorized_throwsUnauthorized() async throws {
        try stubStatus(401)

        await assertThrowsTruoraProcessAPIError(.unauthorized(body: "")) {
            _ = try await self.sut.readProcess(processId: "IDP123")
        }
    }

    func testServerError_throwsServerError() async throws {
        try stubStatus(404)

        await assertThrowsTruoraProcessAPIError(.serverError(statusCode: 404, body: "")) {
            _ = try await self.sut.readProcess(processId: "IDP123")
        }
    }

    func testDecodingError_throwsDecodingError() async throws {
        try stubOK(json: #"{"unexpected": true}"#, url: "\(baseUrl)/IDP123")

        await assertThrowsTruoraProcessAPIError(.decodingError(URLError(.unknown))) {
            _ = try await self.sut.readProcess(processId: "IDP123")
        }
    }

    // MARK: - Assertion Helper

    /// Runs `block`, fails if it doesn't throw, and asserts the thrown error is
    /// a `TruoraProcessAPIError` equal to `expected` (case identity for payload errors).
    private func assertThrowsTruoraProcessAPIError(
        _ expected: TruoraProcessAPIError,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ block: () async throws -> Void
    ) async {
        do {
            try await block()
            XCTFail("Expected TruoraProcessAPIError.\(expected) to be thrown", file: file, line: line)
        } catch let error as TruoraProcessAPIError {
            XCTAssertEqual(error, expected, file: file, line: line)
        } catch {
            XCTFail("Expected TruoraProcessAPIError, got \(error)", file: file, line: line)
        }
    }
}
