//
//  LogOutputs.swift
//  TruoraValidationsSDK
//
//  Created by AI Assistant on 2025-02-01.
//

import Foundation

// MARK: - Console Output

/// Console output for debugging
actor ConsoleLogOutput {
    func output(event: SDKEvent) {
        let emoji = event.level.emoji
        let json = event.toJSON() ?? "{}"
        debugLog("\(emoji) [TruoraLogger] \(event.eventType.rawValue): \(event.eventName)")
        debugLog(json)
    }
}

// MARK: - API Output

/// Where the logger sends its batches; tests swap in a fake one.
protocol LogBatchOutput: Sendable {
    func output(batch: SDKLog) async -> Bool
}

/// API output for sending to Truora endpoint
actor APILogOutput: LogBatchOutput {
    private let client: SdkLogClient
    private let sdkVersion: String

    init(apiKey: String, endpoint: String, sdkVersion: String) {
        self.sdkVersion = sdkVersion
        // Configuration is validated in LoggerConfiguration, so this should not fail
        // swiftlint:disable:next force_try
        self.client = try! SdkLogClient(
            baseUrl: endpoint,
            apiKey: apiKey,
            sdkVersion: sdkVersion
        )
    }

    func output(batch: SDKLog) async -> Bool {
        do {
            _ = try await client.log(batch)
            debugLog("🟢 [TruoraLogger] Sent \(batch.events.count) events")
            return true
        } catch {
            let desc = error.localizedDescription
            debugLog("❌ [TruoraLogger] Failed to send: \(desc)")
            return false
        }
    }
}
