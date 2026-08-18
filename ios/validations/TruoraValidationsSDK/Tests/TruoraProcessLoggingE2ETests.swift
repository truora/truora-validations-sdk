//
//  TruoraProcessLoggingE2ETests.swift
//  TruoraValidationsSDKTests
//
//  Created by Truora on 22/07/26.
//

import XCTest
@testable import TruoraValidationsSDK

/// Opt-in end-to-end check that DI process logs reach the backend (and thus
/// Kibana). Skipped unless `DI_LOG_E2E=1` and `DI_STAGING_FLOW_TOKEN` are set,
/// so CI stays green offline. See `docs/50a_di_process_logging_e2e.md` for the
/// manual Kibana verification steps.
final class TruoraProcessLoggingE2ETests: XCTestCase {
    override func tearDown() async throws {
        // Reset so the staging logger config never leaks into later tests.
        await TruoraLoggerImplementation.reset()
        try await super.tearDown()
    }

    func testCancelRunEmitsAndFlushesProcessCanceled() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["DI_LOG_E2E"] == "1", "e2e opt-in not set")
        let token = try XCTUnwrap(
            ProcessInfo.processInfo.environment["DI_STAGING_FLOW_TOKEN"],
            "set DI_STAGING_FLOW_TOKEN to a staging DI flow token"
        )

        await TruoraLoggerImplementation.reset()
        try await TruoraLoggerImplementation.initialize(
            with: .production(apiKey: token, sdkVersion: "e2e-test")
        )
        let logger = try TruoraLoggerImplementation.shared

        let manager = TruoraProcessManager(apiClient: TruoraProcessAPIClient(apiKey: token), logger: logger)

        await manager.start()
        // Minimal path: cancel to force a terminal event without an input provider.
        await manager.cancel()
        for await _ in manager.events {}

        await logger.flush()

        let processId = await manager.resolvedProcessId
        print("DI process logging e2e: s_process_id=\(processId ?? "none")")
        // Manual step: verify in Kibana by s_process_id (see docs/50a_di_process_logging_e2e.md).
    }
}
