//
//  StepLoopLoggingTests.swift
//  TruoraValidationsSDKTests
//

import XCTest
@testable import TruoraValidationsSDK

final class StepLoopLoggingTests: XCTestCase {
    private let baseUrl = "https://api.test/v1/processes"
    private let processId = "IPR1"

    override func setUp() {
        super.setUp()
        LoggingURLStub.reset()
    }

    override func tearDown() {
        LoggingURLStub.reset()
        super.tearDown()
    }

    /// One step submitted and advanced, then the process resolves: exercises the
    /// three "happy path" step-level log sites in a single pass through `drive()`.
    func testLogsRenderedVerifyAndAdvance() async throws {
        LoggingURLStub.processReads = [
            // Initial read: step 0 is current.
            StubResponse(body: processJSON(currentStep: 0, steps: [stepJSON(stepId: "STP1")])),
            // Poll: step 0 succeeded and current_step moved to 1.
            StubResponse(body: processJSON(
                currentStep: 1,
                steps: [stepJSON(stepId: "STP1", blockStatus: "success"), stepJSON(stepId: "STP2")]
            )),
            // Loop re-reads: the process finished.
            StubResponse(body: processJSON(status: "success", currentStep: 1, steps: [stepJSON(stepId: "STP1")]))
        ]

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [LoggingURLStub.self]
        let session = URLSession(configuration: config)
        let client = TruoraProcessAPIClient(apiKey: "test-key", baseUrl: baseUrl, sessionConfig: .noRetry, session: session)

        let spy = SpyLogger()
        let loop = StepLoop(
            apiClient: client,
            executor: TruoraProcessRequestExecutor(retryPolicy: .none, sleep: { _ in }),
            inputProvider: StubInputProvider(),
            pollingController: PollingController(sleep: { _ in }),
            logger: spy
        )

        _ = try await loop.run(processId: processId) { _ in }

        let names = spy.sdkCalls.map(\.eventName)
        XCTAssertTrue(names.contains("step_rendered"))
        XCTAssertTrue(names.contains("verify_submitted"))
        XCTAssertTrue(names.contains("step_advanced"))
    }

    /// A step submitted, declined with retries left, then resolved on the loop's
    /// next read: exercises the `step_retry` log site.
    func testLogsStepRetryWithRemainingRetriesAndDeclinedReason() async throws {
        LoggingURLStub.processReads = [
            // Initial read: step 0 is current, three attempts left.
            StubResponse(body: processJSON(currentStep: 0, steps: [stepJSON(stepId: "STP1", remainingRetries: 3)])),
            // Poll: step 0 declined, one attempt spent.
            StubResponse(body: processJSON(
                currentStep: 0,
                steps: [stepJSON(
                    stepId: "STP1",
                    blockStatus: "failure",
                    declinedReason: "blurry_photo",
                    remainingRetries: 2
                )]
            )),
            // Loop re-reads after the retry: the process has since resolved.
            StubResponse(body: processJSON(status: "success", currentStep: 0, steps: [stepJSON(stepId: "STP1")]))
        ]

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [LoggingURLStub.self]
        let session = URLSession(configuration: config)
        let client = TruoraProcessAPIClient(apiKey: "test-key", baseUrl: baseUrl, sessionConfig: .noRetry, session: session)

        let spy = SpyLogger()
        let loop = StepLoop(
            apiClient: client,
            executor: TruoraProcessRequestExecutor(retryPolicy: .none, sleep: { _ in }),
            inputProvider: StubInputProvider(),
            pollingController: PollingController(sleep: { _ in }),
            logger: spy
        )

        let outcome = try await loop.run(processId: processId) { _ in }

        guard case .finished = outcome else {
            return XCTFail("Expected .finished, got \(outcome)")
        }

        let retry = spy.sdkCalls.first { $0.eventName == "step_retry" }
        XCTAssertNotNil(retry)
        XCTAssertEqual(retry?.level, .info)
        XCTAssertEqual(retry?.metadata?["s_step_type"] as? String, "enter_document_type")
        XCTAssertEqual(retry?.metadata?["i_remaining_retries"] as? Int, 2)
        XCTAssertEqual(retry?.metadata?["s_declined_reason"] as? String, "blurry_photo")
    }

    /// Every read reports the same unresolved step, so polling exhausts its budget
    /// and the loop fails with `process_timed_out` logged at ERROR level.
    func testLogsProcessTimedOutAtErrorLevelWhenTheStepNeverResolves() async throws {
        LoggingURLStub.processReads = [
            StubResponse(body: processJSON(currentStep: 0, steps: [stepJSON(stepId: "STP1")]))
        ]

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [LoggingURLStub.self]
        let session = URLSession(configuration: config)
        let client = TruoraProcessAPIClient(apiKey: "test-key", baseUrl: baseUrl, sessionConfig: .noRetry, session: session)

        let spy = SpyLogger()
        let loop = StepLoop(
            apiClient: client,
            executor: TruoraProcessRequestExecutor(retryPolicy: .none, sleep: { _ in }),
            inputProvider: StubInputProvider(),
            pollingController: PollingController(sleep: { _ in }),
            logger: spy
        )

        let outcome = try await loop.run(processId: processId) { _ in }

        guard case .failed(.stepTimedOut) = outcome else {
            return XCTFail("Expected .failed(.stepTimedOut), got \(outcome)")
        }

        let timedOut = spy.sdkCalls.first { $0.eventName == "process_timed_out" }
        XCTAssertNotNil(timedOut)
        XCTAssertEqual(timedOut?.level, .error)
        XCTAssertNil(timedOut?.errorMessage)
        XCTAssertFalse(spy.sdkCalls.contains { $0.eventName == "step_advanced" })
    }
}

// MARK: - Fixtures

/// Returns canned input for every step; the loop only needs *some* value to
/// reach `verifyStep`, not a specific one.
private struct StubInputProvider: StepInputProviding {
    func input(for routedStep: RoutedStep) async throws -> StepInput {
        StepInput(values: [TruoraStepInputValue(type: "text", name: "country", value: "CO")])
    }
}

private struct StubResponse {
    let body: String
    let status: Int

    init(body: String, status: Int = 200) {
        self.body = body
        self.status = status
    }
}

/// A process JSON with the given steps, at the given `current_step`.
private func processJSON(status: String = "pending", currentStep: Int, steps: [String]) -> String {
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
    stepId: String,
    blockStatus: String? = nil,
    declinedReason: String? = nil,
    remainingRetries: Int? = nil
) -> String {
    var fields = [#""step_id": "\#(stepId)""#, #""type": "enter_document_type""#]

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

    fields.append(#""expected_inputs": [{"type": "text", "name": "country"}]"#)

    return "{\(fields.joined(separator: ","))}"
}

/// Routes each DI call to a canned response: `GET` walks `processReads`
/// (repeating the last entry), `POST /steps/…` verifies with a canned success.
private final class LoggingURLStub: URLProtocol {
    nonisolated(unsafe) static var processReads: [StubResponse] = []
    nonisolated(unsafe) static var readCount = 0

    static func reset() {
        processReads = []
        readCount = 0
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
        case "POST" where path.contains("/steps/"):
            response = StubResponse(body: #"{"step_id": "STP1", "type": "enter_document_type"}"#)

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
