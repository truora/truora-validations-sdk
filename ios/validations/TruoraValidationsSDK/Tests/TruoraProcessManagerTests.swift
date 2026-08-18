//
//  TruoraProcessManagerTests.swift
//  TruoraValidationsSDKTests
//
//  Created by Truora on 07/07/26.
//

import XCTest
@testable import TruoraValidationsSDK

final class TruoraProcessManagerTests: XCTestCase {
    // MARK: - Lifecycle

    func testCancelEmitsProcessCanceledAndFinishesStream() async {
        let manager = TruoraProcessManager(apiClient: TruoraProcessAPIClient(apiKey: "test-key"))

        await manager.cancel()

        // `cancel()` finishes the stream, so this loop terminates.
        var received: [ProcessEvent] = []
        for await event in manager.events {
            received.append(event)
        }

        XCTAssertEqual(received.count, 1)
        guard case .processCanceled = received.first else {
            return XCTFail("Expected .processCanceled, got \(String(describing: received.first))")
        }
    }

    // MARK: - Model decoding

    func testTruoraBlockDecodesSnakeCaseWireNames() throws {
        let json = Data("""
        {
            "verification_id": "ver-123",
            "name": "document_verification",
            "status": "success",
            "failure_status": "declined",
            "declined_reason": "blurry document"
        }
        """.utf8)

        let block = try JSONDecoder().decode(TruoraBlock.self, from: json)

        XCTAssertEqual(block.blockId, "ver-123")
        XCTAssertEqual(block.type, .documentVerification)
        XCTAssertEqual(block.status, .success)
        XCTAssertEqual(block.failureStatus, .declined)
        XCTAssertEqual(block.declinedReason, "blurry document")
        XCTAssertNil(block.outputs)
    }

    func testTruoraProcessStatusIsDistinctCodableType() throws {
        let decoded = try JSONDecoder().decode(TruoraProcessStatus.self, from: Data("\"failure\"".utf8))
        XCTAssertEqual(decoded, .failure)
    }

    // MARK: - Result aggregation shape

    func testProcessResultDefaultsAreEmpty() {
        let result = ProcessResult(processId: "idp-1", status: .pending)

        XCTAssertEqual(result.processId, "idp-1")
        XCTAssertEqual(result.status, .pending)
        XCTAssertNil(result.failureStatus)
        XCTAssertTrue(result.blocks.isEmpty)
        XCTAssertNil(result.risk)
    }

    // MARK: - create-or-read (stubbed network)

    /// Builds a manager whose `TruoraProcessAPIClient` is backed by a stubbed `URLSession`
    /// (via `TruoraProcessURLStub`) returning the given status/body, so the runner's
    /// create-or-read + error-mapping paths are exercised without real network.
    private func makeManager(
        status: Int,
        body: String,
        inputProvider: StepInputProviding? = nil
    ) -> TruoraProcessManager {
        TruoraProcessURLStub.stub = (Data(body.utf8), status)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [TruoraProcessURLStub.self]
        let session = URLSession(configuration: config)
        let client = TruoraProcessAPIClient(apiKey: "test-key", sessionConfig: .noRetry, session: session)
        return TruoraProcessManager(
            apiClient: client,
            executor: TruoraProcessRequestExecutor(retryPolicy: .none, sleep: { _ in }),
            inputProvider: inputProvider
        )
    }

    func testCreateOrRead201ResolvesProcessId() async {
        let manager = makeManager(
            status: 201,
            body: #"{"process_id": "IDP201", "status": "pending", "account_id": "a", "client_id": "c"}"#
        )

        await manager.start()
        await manager.awaitCurrentRun()

        let pid = await manager.resolvedProcessId
        XCTAssertEqual(pid, "IDP201")
    }

    func test401MapsToTokenExpired() async {
        let manager = makeManager(status: 401, body: "{}")

        await manager.start()

        var received: [ProcessEvent] = []
        for await event in manager.events {
            received.append(event)
        }

        guard case .processError(.tokenExpired) = received.first else {
            return XCTFail("Expected .processError(.tokenExpired), got \(String(describing: received.first))")
        }
    }

    func test410MapsToProcessExpired() async {
        let manager = makeManager(status: 410, body: #"{"message": "process expired"}"#)

        await manager.start()

        var received: [ProcessEvent] = []
        for await event in manager.events {
            received.append(event)
        }

        guard case .processError(.processExpired) = received.first else {
            return XCTFail("Expected .processError(.processExpired), got \(String(describing: received.first))")
        }
    }

    // MARK: - Step loop wiring

    /// Without an input provider there is no way to capture a step, so the manager
    /// stops after create-or-read and leaves the stream open.
    func testStartWithoutInputProviderStopsAfterCreateOrRead() async {
        let manager = makeManager(
            status: 201,
            body: #"{"process_id": "IDP1", "status": "pending", "current_step": 0, "steps": [{"step_id": "S1", "type": "enter_response"}]}"#
        )

        await manager.start()
        await manager.awaitCurrentRun()

        let pid = await manager.resolvedProcessId
        XCTAssertEqual(pid, "IDP1")
    }

    /// With a provider, `start()` runs create-or-read and then drives the step loop,
    /// whose failure surfaces on the event stream.
    func testStartDrivesTheStepLoopAndSurfacesItsFailure() async {
        let manager = makeManager(
            status: 201,
            body: #"{"process_id": "IDP1", "status": "pending", "current_step": 0, "steps": [{"step_id": "S1", "type": "enter_response"}]}"#,
            inputProvider: NeverCalledInputProvider()
        )

        await manager.start()

        var received: [ProcessEvent] = []
        for await event in manager.events {
            received.append(event)
        }

        XCTAssertEqual(received.count, 1)
        guard case .processError(.unsupportedFlow(let stepType)) = received.first else {
            return XCTFail("Expected .unsupportedFlow, got \(String(describing: received.first))")
        }
        XCTAssertEqual(stepType, "enter_response")
    }

    // MARK: - Finalization (scripted network)

    private let scriptedBaseUrl = "https://api.test/v1/processes"

    /// Builds a manager backed by ``ScriptedManagerURLStub`` (create-or-read, a
    /// scripted `GET` sequence, and cancel), with a no-op clock so the risk-wait
    /// budget is driven without real delay.
    private func makeScriptedManager(inputProvider: StepInputProviding? = CannedInputProvider()) -> TruoraProcessManager {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ScriptedManagerURLStub.self]
        let session = URLSession(configuration: config)
        let client = TruoraProcessAPIClient(
            apiKey: "test-key",
            baseUrl: scriptedBaseUrl,
            sessionConfig: .noRetry,
            session: session
        )

        return TruoraProcessManager(
            apiClient: client,
            executor: TruoraProcessRequestExecutor(retryPolicy: .none, sleep: { _ in }),
            inputProvider: inputProvider,
            sleep: { _ in }
        )
    }

    /// Drains the event stream to completion (it finishes on the terminal outcome).
    private func collectEvents(_ manager: TruoraProcessManager) async -> [ProcessEvent] {
        var events: [ProcessEvent] = []
        for await event in manager.events {
            events.append(event)
        }
        return events
    }

    /// A finished snapshot (no active step) carrying the get-results block,
    /// optionally with a risk evaluation at `riskStatus` (omitted when `nil`).
    private func getResultsProcess(
        status: String = "pending",
        riskStatus: String?,
        blocks: String? = nil
    ) -> String {
        var fields = [
            #""process_id": "IPR1""#,
            #""status": "\#(status)""#,
            #""identity_verification_names": ["document_verification", "get_validations_result"]"#
        ]
        if let riskStatus {
            fields.append(#""risk_evaluation": {"risk_evaluation_status": "\#(riskStatus)"}"#)
        }
        if let blocks {
            fields.append(#""verifications": \#(blocks)"#)
        }
        return "{\(fields.joined(separator: ","))}"
    }

    func testGetResultsFlowWaitsWhileProcessPendingThenCompletes() async {
        ScriptedManagerURLStub.reset()
        ScriptedManagerURLStub.createOrRead = ScriptedResponse(body: #"{"process_id": "IPR1", "status": "pending"}"#, status: 201)
        ScriptedManagerURLStub.processReads = [
            // StepLoop read: finished (no step to render) but the process is pending.
            ScriptedResponse(body: getResultsProcess(status: "pending", riskStatus: "pending"), status: 200),
            // Finalize re-reads: still pending once more...
            ScriptedResponse(body: getResultsProcess(status: "pending", riskStatus: "pending"), status: 200),
            // ...then the process resolves.
            ScriptedResponse(
                body: getResultsProcess(
                    status: "success",
                    riskStatus: "success",
                    blocks: #"{"document_verification:VRF_1": "success"}"#
                ),
                status: 200
            )
        ]

        let manager = makeScriptedManager()
        await manager.start()
        let events = await collectEvents(manager)

        guard case .processCompleted(let result) = events.last else {
            return XCTFail("Expected .processCompleted last, got \(String(describing: events.last))")
        }
        XCTAssertEqual(result.status, .success)
        XCTAssertEqual(result.risk?.riskEvaluationStatus, .success, "Carries the risk from the resolved read")
        // 1 StepLoop read + 2 finalize re-reads (the second resolves it).
        XCTAssertEqual(ScriptedManagerURLStub.readCount, 3)
    }

    /// Regression: the wait keys on the *process* status, not the risk status. A
    /// get-results process can be pending while its risk evaluation has not been
    /// created yet (`risk_evaluation` absent) — the SDK must keep polling, not
    /// complete prematurely on the missing risk.
    func testGetResultsWaitsWhileProcessPendingEvenWithoutRiskEvaluation() async {
        ScriptedManagerURLStub.reset()
        ScriptedManagerURLStub.createOrRead = ScriptedResponse(body: #"{"process_id": "IPR1", "status": "pending"}"#, status: 201)
        ScriptedManagerURLStub.processReads = [
            // Pending, and no risk evaluation on the wire yet.
            ScriptedResponse(body: getResultsProcess(status: "pending", riskStatus: nil), status: 200),
            // The process then resolves.
            ScriptedResponse(body: getResultsProcess(status: "success", riskStatus: "success"), status: 200)
        ]

        let manager = makeScriptedManager()
        await manager.start()
        let events = await collectEvents(manager)

        guard case .processCompleted(let result) = events.last else {
            return XCTFail("Expected .processCompleted last, got \(String(describing: events.last))")
        }
        XCTAssertEqual(result.status, .success, "Waited for the process to resolve, not for risk")
        XCTAssertEqual(ScriptedManagerURLStub.readCount, 2, "Kept polling despite the absent risk evaluation")
    }

    /// When the 300s / 3s budget is spent on a process that stays pending, the
    /// still-pending snapshot is resolved as-is rather than spinning forever.
    func testResultsWaitTimesOutAndResolvesPendingSnapshot() async {
        ScriptedManagerURLStub.reset()
        ScriptedManagerURLStub.createOrRead = ScriptedResponse(body: #"{"process_id": "IPR1", "status": "pending"}"#, status: 201)
        ScriptedManagerURLStub.processReads = [
            ScriptedResponse(body: getResultsProcess(status: "pending", riskStatus: "pending"), status: 200)
        ]

        let manager = makeScriptedManager()
        await manager.start()
        let events = await collectEvents(manager)

        guard case .processCompleted(let result) = events.last else {
            return XCTFail("Expected .processCompleted last, got \(String(describing: events.last))")
        }
        XCTAssertEqual(result.status, .pending, "Resolves the pending snapshot as-is")
        // 1 StepLoop read + 100 finalize re-reads across the budget.
        XCTAssertEqual(ScriptedManagerURLStub.readCount, 101)
    }

    func testWithoutGetResultsResolvesSnapshotAsIs() async {
        ScriptedManagerURLStub.reset()
        ScriptedManagerURLStub.createOrRead = ScriptedResponse(body: #"{"process_id": "IPR1", "status": "pending"}"#, status: 201)
        ScriptedManagerURLStub.processReads = [
            ScriptedResponse(body: #"{"process_id": "IPR1", "status": "success"}"#, status: 200)
        ]

        let manager = makeScriptedManager()
        await manager.start()
        let events = await collectEvents(manager)

        guard case .processCompleted(let result) = events.last else {
            return XCTFail("Expected .processCompleted last, got \(String(describing: events.last))")
        }
        XCTAssertEqual(result.status, .success)
        XCTAssertEqual(ScriptedManagerURLStub.readCount, 1, "No get-results flow never waits on risk")
    }

    func testEmitsOneBlockCompletedPerBlockBeforeProcessCompleted() async {
        ScriptedManagerURLStub.reset()
        ScriptedManagerURLStub.createOrRead = ScriptedResponse(body: #"{"process_id": "IPR1", "status": "pending"}"#, status: 201)
        ScriptedManagerURLStub.processReads = [
            ScriptedResponse(
                body: """
                {
                  "process_id": "IPR1",
                  "status": "success",
                  "verifications": {
                    "document_verification:VRF_1": "success",
                    "face_recognition:VRF_2": "success"
                  }
                }
                """,
                status: 200
            )
        ]

        let manager = makeScriptedManager()
        await manager.start()
        let events = await collectEvents(manager)

        XCTAssertEqual(events.count, 3)
        guard case .blockCompleted(let first) = events[0],
              case .blockCompleted(let second) = events[1],
              case .processCompleted = events[2] else {
            return XCTFail("Expected [blockCompleted, blockCompleted, processCompleted], got \(events)")
        }
        XCTAssertEqual(first.type, .documentVerification, "Emitted in sorted block order")
        XCTAssertEqual(second.type, .faceRecognition)
    }

    func testCancelPostsToBackendAndEmitsProcessCanceledOnce() async {
        ScriptedManagerURLStub.reset()
        ScriptedManagerURLStub.createOrRead = ScriptedResponse(body: #"{"process_id": "IPR1", "status": "pending"}"#, status: 201)
        ScriptedManagerURLStub.cancel = ScriptedResponse(body: #"{"process_id": "IPR1"}"#, status: 200)

        // With no input provider the run resolves `processId` in create-or-read and
        // then stops (nothing to capture) without terminating — a live process for
        // cancel to act on, with no fragile loop-parking to synchronize against.
        let manager = makeScriptedManager(inputProvider: nil)
        await manager.start()
        await manager.awaitCurrentRun()

        let resolvedId = await manager.resolvedProcessId
        XCTAssertEqual(resolvedId, "IPR1", "processId is resolved before cancel")

        async let events = collectEvents(manager)
        await manager.cancel()
        let collected = await events

        XCTAssertEqual(ScriptedManagerURLStub.cancelCount, 1, "Cancel is POSTed exactly once")
        XCTAssertEqual(collected.count, 1)
        guard case .processCanceled = collected.first else {
            return XCTFail("Expected a single .processCanceled, got \(collected)")
        }
    }

    /// When the backend rejects the cancel POST (after retries), the failure
    /// surfaces as `.processError` rather than a `.processCanceled` that never
    /// landed — mirroring the runner surfacing `identityCancel` errors.
    func testCancelSurfacesBackendFailureAsProcessError() async {
        ScriptedManagerURLStub.reset()
        ScriptedManagerURLStub.createOrRead = ScriptedResponse(body: #"{"process_id": "IPR1", "status": "pending"}"#, status: 201)
        ScriptedManagerURLStub.cancel = ScriptedResponse(body: #"{"message": "cannot cancel"}"#, status: 400)

        let manager = makeScriptedManager(inputProvider: nil)
        await manager.start()
        await manager.awaitCurrentRun()

        let resolvedId = await manager.resolvedProcessId
        XCTAssertEqual(resolvedId, "IPR1", "processId is resolved before cancel")

        async let events = collectEvents(manager)
        await manager.cancel()
        let collected = await events

        XCTAssertEqual(ScriptedManagerURLStub.cancelCount, 1)
        XCTAssertEqual(collected.count, 1)
        guard case .processError = collected.first else {
            return XCTFail("Expected a single .processError, got \(collected)")
        }
    }

    func testCancelWithoutProcessIdEmitsProcessCanceledWithoutPosting() async {
        ScriptedManagerURLStub.reset()
        let manager = makeScriptedManager()

        async let events = collectEvents(manager)
        await manager.cancel()
        let collected = await events

        XCTAssertEqual(ScriptedManagerURLStub.cancelCount, 0, "No processId means no backend call")
        XCTAssertEqual(collected.count, 1)
        guard case .processCanceled = collected.first else {
            return XCTFail("Expected a single .processCanceled, got \(collected)")
        }
    }
}

// MARK: - Input provider stub

/// The loop must reject an unsupported step before ever asking for input.
private struct NeverCalledInputProvider: StepInputProviding {
    func input(for routedStep: RoutedStep) async throws -> StepInput {
        XCTFail("The loop must not request input for an unsupported step")
        return StepInput()
    }
}

/// Returns canned input; used where the loop finishes before capture and never
/// actually asks for input.
private struct CannedInputProvider: StepInputProviding {
    func input(for routedStep: RoutedStep) async throws -> StepInput {
        StepInput(values: [TruoraStepInputValue(type: "text", name: "country", value: "CO")])
    }
}

// MARK: - Scripted URLProtocol stub

private struct ScriptedResponse {
    let body: String
    let status: Int
}

/// Routes DI calls to canned responses: `POST` to the base is create-or-read,
/// `POST …/status` is cancel, `GET` walks `processReads` (repeating the last).
/// Counts reads and cancels for assertions.
private final class ScriptedManagerURLStub: URLProtocol {
    nonisolated(unsafe) static var createOrRead = ScriptedResponse(body: #"{"process_id": "IPR1"}"#, status: 201)
    nonisolated(unsafe) static var processReads: [ScriptedResponse] = []
    nonisolated(unsafe) static var cancel = ScriptedResponse(body: #"{"process_id": "IPR1"}"#, status: 200)

    nonisolated(unsafe) static var readCount = 0
    nonisolated(unsafe) static var cancelCount = 0

    static func reset() {
        createOrRead = ScriptedResponse(body: #"{"process_id": "IPR1"}"#, status: 201)
        processReads = []
        cancel = ScriptedResponse(body: #"{"process_id": "IPR1"}"#, status: 200)
        readCount = 0
        cancelCount = 0
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
        let response: ScriptedResponse

        switch method {
        case "POST" where path.hasSuffix("/status"):
            Self.cancelCount += 1
            response = Self.cancel

        case "POST":
            response = Self.createOrRead

        default:
            let index = min(Self.readCount, max(Self.processReads.count - 1, 0))
            Self.readCount += 1
            response = Self.processReads.isEmpty
                ? ScriptedResponse(body: "{}", status: 500)
                : Self.processReads[index]
        }

        send(response)
    }

    override func stopLoading() {}

    private func send(_ stub: ScriptedResponse) {
        let response = HTTPURLResponse(
            url: request.url ?? URL(fileURLWithPath: "/"),
            statusCode: stub.status,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )

        if let response {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }

        client?.urlProtocol(self, didLoad: Data(stub.body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}

// MARK: - URLProtocol stub

/// Serves a canned (body, statusCode) so `TruoraProcessAPIClient` can be exercised over a
/// stubbed `URLSession` without real network.
private final class TruoraProcessURLStub: URLProtocol {
    static var stub: (data: Data, status: Int)?

    override static func canInit(with _: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        if let stub = Self.stub, let url = request.url,
           let response = HTTPURLResponse(
               url: url,
               statusCode: stub.status,
               httpVersion: nil,
               headerFields: ["Content-Type": "application/json"]
           ) {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: stub.data)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
