//
//  StepLoopTests.swift
//  TruoraValidationsSDKTests
//

import XCTest
@testable import TruoraValidationsSDK

final class StepLoopTests: XCTestCase {
    private let processId = "IPR1"

    override func setUp() {
        super.setUp()
        ScriptedURLStub.reset()
    }

    override func tearDown() {
        ScriptedURLStub.reset()
        super.tearDown()
    }

    // MARK: - Builders

    private func makeLoop(
        inputProvider: StepInputProviding = FakeInputProvider(),
        uploadStatus: Int = 200,
        uploadBody: String = ""
    ) -> StepLoop {
        ScriptedURLStub.upload = StubResponse(body: uploadBody, status: uploadStatus)

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ScriptedURLStub.self]
        let session = URLSession(configuration: config)
        let client = TruoraProcessAPIClient(
            apiKey: "test-key",
            sessionConfig: .noRetry,
            session: session
        )

        return StepLoop(
            apiClient: client,
            // `.none` keeps the API retry budget out of these assertions.
            executor: TruoraProcessRequestExecutor(retryPolicy: .none, sleep: { _ in }),
            inputProvider: inputProvider,
            uploader: MediaUploader(apiClient: client, sleep: { _ in }, random: { 0.5 }),
            pollingController: PollingController(sleep: { _ in })
        )
    }

    private func run(_ loop: StepLoop) async throws -> (StepLoopOutcome, [ProcessEvent]) {
        var events: [ProcessEvent] = []
        let outcome = try await loop.run(processId: processId) { events.append($0) }

        return (outcome, events)
    }

    /// A process JSON with one or two steps, at the given `current_step`.
    private func processJSON(
        status: String = "pending",
        currentStep: Int,
        steps: [String]
    ) -> String {
        """
        {
          "process_id": "IPR1",
          "status": "\(status)",
          "current_step": \(currentStep),
          "steps": [\(steps.joined(separator: ","))]
        }
        """
    }

    private func stepJSON(
        stepId: String = "STP1",
        type: String = "enter_document_type",
        blockStatus: String? = nil,
        declinedReason: String? = nil,
        remainingRetries: Int? = nil,
        filesUploadUrls: String? = nil
    ) -> String {
        var fields = [#""step_id": "\#(stepId)""#, #""type": "\#(type)""#]

        if let blockStatus {
            var output = [#""status": "\#(blockStatus)""#]
            if let declinedReason {
                output.append(#""declined_reason": "\#(declinedReason)""#)
            }
            fields.append(#""verification_output": {\#(output.joined(separator: ","))}"#)
        }

        if let remainingRetries {
            fields.append(#""remaining_retries": \#(remainingRetries)"#)
        }

        if let filesUploadUrls {
            fields.append(#""files_upload_urls": \#(filesUploadUrls)"#)
        }

        fields.append(#""expected_inputs": [{"type": "text", "name": "country"}]"#)

        return "{\(fields.joined(separator: ","))}"
    }

    // MARK: - advance

    /// The backend moving `current_step` is what drives the loop forward.
    func testAdvancesWhenCurrentStepChanges() async throws {
        ScriptedURLStub.processReads = [
            // Initial read: step 0 is current.
            StubResponse(body: processJSON(currentStep: 0, steps: [stepJSON(), stepJSON(stepId: "STP2")]), status: 200),
            // Poll: step 0 succeeded and current_step moved to 1.
            StubResponse(
                body: processJSON(
                    currentStep: 1,
                    steps: [stepJSON(blockStatus: "success"), stepJSON(stepId: "STP2")]
                ),
                status: 200
            ),
            // Loop re-reads: the process finished.
            StubResponse(body: processJSON(status: "success", currentStep: 1, steps: [stepJSON()]), status: 200)
        ]

        let (outcome, events) = try await run(makeLoop())

        guard case .finished(let process) = outcome else {
            return XCTFail("Expected .finished, got \(outcome)")
        }
        XCTAssertEqual(process.status, .success)
        XCTAssertTrue(events.isEmpty)
        XCTAssertEqual(ScriptedURLStub.verifyCount, 1)
    }

    // MARK: - retry

    func testRetriesWhenStepFailsWithRemainingRetries() async throws {
        ScriptedURLStub.processReads = [
            StubResponse(body: processJSON(currentStep: 0, steps: [stepJSON(remainingRetries: 3)]), status: 200),
            // Poll: failed, but the user has attempts left.
            StubResponse(
                body: processJSON(currentStep: 0, steps: [
                    stepJSON(blockStatus: "failure", declinedReason: "blurry document", remainingRetries: 2)
                ]),
                status: 200
            ),
            // Loop re-reads and the process has since resolved, ending the run.
            StubResponse(body: processJSON(status: "failure", currentStep: 0, steps: [stepJSON()]), status: 200)
        ]

        let (outcome, events) = try await run(makeLoop())

        guard case .finished = outcome else {
            return XCTFail("Expected .finished, got \(outcome)")
        }
        XCTAssertEqual(events.count, 1)
        guard case .stepRetry(let retry) = events.first else {
            return XCTFail("Expected .stepRetry, got \(String(describing: events.first))")
        }
        XCTAssertEqual(retry.stepType, .enterDocumentType)
        XCTAssertEqual(retry.declinedReason, "blurry document")
        XCTAssertEqual(retry.remainingRetries, 2, "Reports the decremented count from the poll")
    }

    // MARK: - terminal

    func testFinishesImmediatelyWhenProcessIsNotPending() async throws {
        ScriptedURLStub.processReads = [
            StubResponse(body: processJSON(status: "success", currentStep: 0, steps: [stepJSON()]), status: 200)
        ]

        let (outcome, _) = try await run(makeLoop())

        guard case .finished(let process) = outcome else {
            return XCTFail("Expected .finished, got \(outcome)")
        }
        XCTAssertEqual(process.status, .success)
        XCTAssertEqual(ScriptedURLStub.verifyCount, 0, "A resolved process is never verified")
    }

    // MARK: - unsupported

    func testUnsupportedStepTypeFailsWithUnsupportedFlow() async throws {
        ScriptedURLStub.processReads = [
            StubResponse(body: processJSON(currentStep: 0, steps: [stepJSON(type: "enter_response")]), status: 200)
        ]

        let (outcome, _) = try await run(makeLoop())

        XCTAssertEqual(outcome.failure, .unsupportedFlow(stepType: "enter_response"))
        XCTAssertEqual(ScriptedURLStub.verifyCount, 0)
    }

    /// A step type the SDK has never heard of decodes to `.unknown` and routes the
    /// same graceful way, rather than crashing.
    func testUnknownWireStepTypeFailsWithUnsupportedFlow() async throws {
        ScriptedURLStub.processReads = [
            StubResponse(body: processJSON(currentStep: 0, steps: [stepJSON(type: "teleport_user")]), status: 200)
        ]

        let (outcome, _) = try await run(makeLoop())

        XCTAssertEqual(outcome.failure, .unsupportedFlow(stepType: "unknown"))
    }

    // MARK: - verify errors

    /// The backend checks the media actually landed in storage at verify time.
    func testImagesWereNotUploadedIsSurfaced() async throws {
        ScriptedURLStub.processReads = [
            StubResponse(body: processJSON(currentStep: 0, steps: [stepJSON()]), status: 200)
        ]
        ScriptedURLStub.verify = StubResponse(
            body: #"{"code": "10400", "http_code": 400, "message": "images were not uploaded"}"#,
            status: 400
        )

        let (outcome, _) = try await run(makeLoop())

        XCTAssertEqual(outcome.failure, .unknown(message: "images were not uploaded"))
    }

    func testExpiredTokenIsSurfaced() async throws {
        ScriptedURLStub.processReads = [
            StubResponse(body: #"{"message": "unauthorized"}"#, status: 401)
        ]

        let (outcome, _) = try await run(makeLoop())

        XCTAssertEqual(outcome.failure, .tokenExpired)
    }

    // MARK: - upload

    /// A consumed presigned URL is terminal: no retry, no re-read.
    func testSignedUrlRejectionFailsTheLoop() async throws {
        let files = #"[{"name": "document_front", "url": "https://files.truora.com/u/abc"}]"#
        ScriptedURLStub.processReads = [
            StubResponse(
                body: processJSON(currentStep: 0, steps: [stepJSON(type: "take_document_photo", filesUploadUrls: files)]),
                status: 200
            )
        ]

        let loop = makeLoop(
            inputProvider: FakeInputProvider(
                media: ["document_front": StepMedia(data: Data("x".utf8), contentType: "image/jpeg")]
            ),
            uploadStatus: 403,
            uploadBody: "<Error><Code>AccessDenied</Code></Error>"
        )
        let (outcome, _) = try await run(loop)

        XCTAssertEqual(outcome.failure, .mediaUploadFailed(reason: "Upload URL rejected by storage (AccessDenied)"))
        XCTAssertEqual(ScriptedURLStub.verifyCount, 0, "A failed upload is never verified")
        XCTAssertEqual(ScriptedURLStub.uploadCount, 1, "A rejected signature is not retried")
    }

    /// A transient upload failure is retried by ``MediaUploader`` and nothing else:
    /// exactly its 3-attempt budget reaches the wire, never a multiple of it.
    func testTransientUploadFailureUsesExactlyTheUploaderBudget() async throws {
        let files = #"[{"name": "document_front", "url": "https://files.truora.com/u/abc"}]"#
        ScriptedURLStub.processReads = [
            StubResponse(
                body: processJSON(currentStep: 0, steps: [stepJSON(type: "take_document_photo", filesUploadUrls: files)]),
                status: 200
            )
        ]

        let loop = makeLoop(
            inputProvider: FakeInputProvider(
                media: ["document_front": StepMedia(data: Data("x".utf8), contentType: "image/jpeg")]
            ),
            uploadStatus: 503
        )
        let (outcome, _) = try await run(loop)

        guard case .failed(.mediaUploadFailed) = outcome else {
            return XCTFail("Expected .mediaUploadFailed, got \(outcome)")
        }
        XCTAssertEqual(ScriptedURLStub.uploadCount, MediaUploader.maxAttempts)
        XCTAssertEqual(ScriptedURLStub.verifyCount, 0, "A failed upload is never verified")
    }

    func testUploadRejectsAnUntrustedHost() async throws {
        let files = #"[{"name": "document_front", "url": "https://evil.example.com/u/abc"}]"#
        ScriptedURLStub.processReads = [
            StubResponse(
                body: processJSON(currentStep: 0, steps: [stepJSON(type: "take_document_photo", filesUploadUrls: files)]),
                status: 200
            )
        ]

        let loop = makeLoop(
            inputProvider: FakeInputProvider(
                media: ["document_front": StepMedia(data: Data("x".utf8), contentType: "image/jpeg")]
            )
        )
        let (outcome, _) = try await run(loop)

        XCTAssertEqual(
            outcome.failure,
            .mediaUploadFailed(reason: "Upload URL is not a Truora file host: https://evil.example.com/u/abc")
        )
        XCTAssertEqual(ScriptedURLStub.uploadCount, 0, "User media never leaves the device")
    }

    func testUploadFailsWhenTheScreenCapturedNoMediaForAFile() async throws {
        let files = #"[{"name": "document_front", "url": "https://files.truora.com/u/abc"}]"#
        ScriptedURLStub.processReads = [
            StubResponse(
                body: processJSON(currentStep: 0, steps: [stepJSON(type: "take_document_photo", filesUploadUrls: files)]),
                status: 200
            )
        ]

        let (outcome, _) = try await run(makeLoop(inputProvider: FakeInputProvider()))

        XCTAssertEqual(outcome.failure, .mediaUploadFailed(reason: "No captured media for document_front"))
        XCTAssertEqual(ScriptedURLStub.uploadCount, 0)
    }

    // MARK: - timeout

    func testStepTimeoutFailsTheLoopInsteadOfSpinning() async throws {
        // Every read shows the same pending step, so polling exhausts its budget.
        ScriptedURLStub.processReads = [
            StubResponse(body: processJSON(currentStep: 0, steps: [stepJSON()]), status: 200)
        ]

        let (outcome, _) = try await run(makeLoop())

        XCTAssertEqual(outcome.failure, .stepTimedOut(stepType: "enter_document_type"))
        XCTAssertEqual(ScriptedURLStub.verifyCount, 1)
        // 1 initial read + 101 polls (pollCount 0...100) — the full 300s budget.
        XCTAssertEqual(ScriptedURLStub.readCount, 102)
    }

    // MARK: - verify request

    /// End-to-end check of the wire contract the backend decodes.
    func testVerifyStepPostsTheFullStepWithTypedInputs() async throws {
        ScriptedURLStub.processReads = [
            StubResponse(body: processJSON(currentStep: 0, steps: [stepJSON(remainingRetries: 2)]), status: 200),
            StubResponse(body: processJSON(status: "success", currentStep: 0, steps: [stepJSON()]), status: 200)
        ]

        _ = try await run(makeLoop())

        let body = try XCTUnwrap(ScriptedURLStub.verifyBodies.first)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])

        XCTAssertEqual(json["step_id"] as? String, "STP1")
        XCTAssertEqual(json["remaining_retries"] as? Int, 2)
        XCTAssertNil(json["step"], "The step is flattened, not nested")

        let inputs = try XCTUnwrap(json["expected_inputs"] as? [[String: Any]])
        XCTAssertEqual(inputs.first?["type"] as? String, "text")
        XCTAssertEqual(inputs.first?["name"] as? String, "country")
        XCTAssertEqual(inputs.first?["value"] as? String, "CO")
    }

    /// A captured value is paired with an expected input on **both** type and name
    /// (`settingInputValues`). A value that matches neither is dropped rather than
    /// applied to a different input, so the expected input goes to the wire with no
    /// `value` — documenting the contract that the backend discards unmatched values.
    func testVerifyStepDropsInputValuesThatMatchNoExpectedInput() async throws {
        ScriptedURLStub.processReads = [
            StubResponse(body: processJSON(currentStep: 0, steps: [stepJSON(remainingRetries: 2)]), status: 200),
            StubResponse(body: processJSON(status: "success", currentStep: 0, steps: [stepJSON()]), status: 200)
        ]

        // Expected input is (type: text, name: country); this value's name differs.
        let provider = FakeInputProvider(values: [TruoraStepInputValue(type: "text", name: "city", value: "Bogota")])
        _ = try await run(makeLoop(inputProvider: provider))

        let body = try XCTUnwrap(ScriptedURLStub.verifyBodies.first)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])

        let inputs = try XCTUnwrap(json["expected_inputs"] as? [[String: Any]])
        XCTAssertEqual(inputs.first?["name"] as? String, "country")
        XCTAssertNil(inputs.first?["value"], "An unmatched value must not be applied to a different input")
    }
}

// MARK: - Helpers

private extension StepLoopOutcome {
    /// The error of a `.failed` outcome, for concise assertions.
    var failure: ProcessError? {
        guard case .failed(let error) = self else {
            return nil
        }

        return error
    }
}

/// Returns canned input for every step.
private struct FakeInputProvider: StepInputProviding {
    var values: [TruoraStepInputValue] = [TruoraStepInputValue(type: "text", name: "country", value: "CO")]
    var media: [String: StepMedia] = [:]

    func input(for routedStep: RoutedStep) async throws -> StepInput {
        StepInput(values: values, media: media)
    }
}

private struct StubResponse {
    let body: String
    let status: Int
}

/// Routes each DI call to a canned response: `GET` walks the `processReads`
/// script (repeating the last entry), `POST /steps/…` verifies, `PUT` uploads.
private final class ScriptedURLStub: URLProtocol {
    nonisolated(unsafe) static var processReads: [StubResponse] = []
    nonisolated(unsafe) static var verify = StubResponse(body: #"{"step_id": "STP1", "type": "enter_document_type"}"#, status: 200)
    nonisolated(unsafe) static var upload = StubResponse(body: "", status: 200)

    nonisolated(unsafe) static var readCount = 0
    nonisolated(unsafe) static var verifyCount = 0
    nonisolated(unsafe) static var uploadCount = 0
    nonisolated(unsafe) static var verifyBodies: [Data] = []

    static func reset() {
        processReads = []
        verify = StubResponse(body: #"{"step_id": "STP1", "type": "enter_document_type"}"#, status: 200)
        upload = StubResponse(body: "", status: 200)
        readCount = 0
        verifyCount = 0
        uploadCount = 0
        verifyBodies = []
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let method = request.httpMethod ?? "GET"
        let path = request.url?.path ?? ""
        let response: StubResponse

        switch method {
        case "PUT":
            Self.uploadCount += 1
            response = Self.upload

        case "POST" where path.contains("/steps/"):
            Self.verifyCount += 1
            if let body = Self.body(of: request) {
                Self.verifyBodies.append(body)
            }
            response = Self.verify

        default:
            let index = min(Self.readCount, max(Self.processReads.count - 1, 0))
            Self.readCount += 1
            response = Self.processReads.isEmpty
                ? StubResponse(body: "{}", status: 500)
                : Self.processReads[index]
        }

        send(response)
    }

    override func stopLoading() {}

    /// `URLProtocol` clears `httpBody`, so the body has to come off the stream.
    private static func body(of request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }

        guard let stream = request.httpBodyStream else {
            return nil
        }

        stream.open()
        defer { stream.close() }

        var data = Data()
        let size = 4096
        var buffer = [UInt8](repeating: 0, count: size)

        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: size)
            guard read > 0 else { break }
            data.append(buffer, count: read)
        }

        return data
    }

    private func send(_ stub: StubResponse) {
        let response = HTTPURLResponse(
            url: request.url ?? URL(fileURLWithPath: "/"),
            statusCode: stub.status,
            httpVersion: nil,
            headerFields: nil
        )

        if let response {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }

        client?.urlProtocol(self, didLoad: Data(stub.body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}
