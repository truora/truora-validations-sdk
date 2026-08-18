//
//  ProcessResult.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 07/07/26.
//

import Foundation

// MARK: - Process Result

/// Final outcome of a completed DI process, delivered via
/// ``ProcessEvent/processCompleted(_:)``.
///
/// Aggregates the terminal process status, the reason it failed (if any), the
/// per-block results and the optional risk evaluation. Its shape mirrors
/// the KMP process runner's `ProcessResult` (PROC-6965) 1:1.
struct ProcessResult {
    let processId: String
    let status: TruoraProcessStatus
    let failureStatus: TruoraFailureStatus?
    let blocks: [TruoraBlock]
    let risk: TruoraRiskEvaluationOutput?

    init(
        processId: String,
        status: TruoraProcessStatus,
        failureStatus: TruoraFailureStatus? = nil,
        blocks: [TruoraBlock] = [],
        risk: TruoraRiskEvaluationOutput? = nil
    ) {
        self.processId = processId
        self.status = status
        self.failureStatus = failureStatus
        self.blocks = blocks
        self.risk = risk
    }
}
