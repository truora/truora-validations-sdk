//
//  TruoraProcessManagerLoggingTests.swift
//  TruoraValidationsSDKTests
//

import XCTest
@testable import TruoraValidationsSDK

final class TruoraProcessManagerLoggingTests: XCTestCase {
    func testLocalCancelLogsProcessCanceled() async {
        let spy = SpyLogger()
        let manager = TruoraProcessManager(apiClient: TruoraProcessAPIClient(apiKey: "test-key"), logger: spy)

        await manager.cancel()
        for await _ in manager.events {}

        XCTAssertTrue(spy.sdkCalls.contains { $0.eventName == "process_canceled" })
    }

    /// Builds a manager whose `TruoraProcessAPIClient` is backed by a stubbed `URLSession`
    /// (`LoggingManagerURLStub`) returning a single fixed (status, body) for every
    /// request, wired to `logger` and (optionally) `inputProvider`.
    private func makeManager(
        status: Int,
        body: String,
        logger: TruoraLogger,
        inputProvider: StepInputProviding? = nil
    ) -> TruoraProcessManager {
        LoggingManagerURLStub.stub = (Data(body.utf8), status)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [LoggingManagerURLStub.self]
        let session = URLSession(configuration: config)
        let client = TruoraProcessAPIClient(apiKey: "test-key", sessionConfig: .noRetry, session: session)
        return TruoraProcessManager(
            apiClient: client,
            executor: TruoraProcessRequestExecutor(retryPolicy: .none, sleep: { _ in }),
            inputProvider: inputProvider,
            logger: logger
        )
    }

    func testCreateOrReadLogsProcessCreatedOn201() async {
        let spy = SpyLogger()
        let manager = makeManager(
            status: 201,
            body: #"{"process_id": "IDP1", "status": "pending", "account_id": "a", "client_id": "c"}"#,
            logger: spy
        )

        await manager.start()
        await manager.awaitCurrentRun()

        XCTAssertTrue(spy.sdkCalls.contains { $0.eventName == "process_created" })
        XCTAssertFalse(spy.sdkCalls.contains { $0.eventName == "process_read" })
    }

    func testCreateOrReadLogsProcessReadOn200() async {
        let spy = SpyLogger()
        let manager = makeManager(
            status: 200,
            body: #"{"process_id": "IDP1", "status": "pending", "account_id": "a", "client_id": "c"}"#,
            logger: spy
        )

        await manager.start()
        await manager.awaitCurrentRun()

        XCTAssertTrue(spy.sdkCalls.contains { $0.eventName == "process_read" })
        XCTAssertFalse(spy.sdkCalls.contains { $0.eventName == "process_created" })
    }

    func testCreateOrReadFailureLogsProcessErrorAtErrorLevel() async {
        let spy = SpyLogger()
        let manager = makeManager(
            status: 410,
            body: #"{"message": "process expired"}"#,
            logger: spy
        )

        await manager.start()
        for await _ in manager.events {}

        let error = spy.sdkCalls.first { $0.eventName == "process_error" }
        XCTAssertEqual(error?.level, .error)
        XCTAssertEqual(error?.metadata?["s_error_type"] as? String, "process_expired")
    }

    /// A resolved, non-get-results snapshot with no active step: the step loop
    /// finishes on its very first read, straight into `finalize()`.
    func testStepLoopFinishingWithNoActiveStepLogsProcessCompleted() async {
        let spy = SpyLogger()
        let manager = makeManager(
            status: 201,
            body: #"{"process_id": "IDP1", "status": "success", "flow_id": "FLW1", "account_id": "a", "client_id": "c"}"#,
            logger: spy,
            inputProvider: NoOpInputProvider()
        )

        await manager.start()
        for await _ in manager.events {}

        let completed = spy.sdkCalls.first { $0.eventName == "process_completed" }
        XCTAssertNotNil(completed)
        XCTAssertEqual(completed?.metadata?["s_status"] as? String, "success")
        XCTAssertEqual(completed?.metadata?["s_flow_id"] as? String, "FLW1")
        XCTAssertEqual(completed?.metadata?["s_client_id"] as? String, "c")
        XCTAssertEqual(completed?.metadata?["i_block_count"] as? Int, 0)
        XCTAssertEqual(completed?.metadata?["b_has_risk"] as? Bool, false)
    }
}

// MARK: - Input provider stub

/// A step is never rendered in the `process_completed` scenario (the process
/// resolves with no active step on the loop's first read), so this is never
/// actually invoked; it only satisfies the non-`nil` `inputProvider` the manager
/// requires to drive the step loop at all.
private struct NoOpInputProvider: StepInputProviding {
    func input(for routedStep: RoutedStep) async throws -> StepInput {
        StepInput()
    }
}

// MARK: - URLProtocol stub

/// Serves a single canned (body, statusCode) for every request, so create-or-read
/// and the step loop's first read (finished, no active step) can share one fixed
/// response without real network.
private final class LoggingManagerURLStub: URLProtocol {
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
