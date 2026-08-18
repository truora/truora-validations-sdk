//
//  TruoraBlock.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 07/07/26.
//

import Foundation

// MARK: - DI Block

/// Status-bearing view of a single block within a DI process.
///
/// Distinct from ``TruoraIdentityBlock`` (the *flow-definition* type carrying
/// config/steps/logic): ``TruoraBlock`` is the *result* projection the process
/// runner surfaces once a block reaches a terminal state. Its shape
/// mirrors the KMP process runner's `Block` leaf (PROC-6965) 1:1; the
/// type name follows iOS conventions and deliberately differs from KMP's.
struct TruoraBlock: Codable {
    let blockId: String
    let type: TruoraBlockType
    let status: TruoraBlockStatus
    let failureStatus: TruoraFailureStatus?
    let declinedReason: String?
    /// Data the whole block produced. Distinct from ``TruoraStepOutput``, which is
    /// a single step's result.
    let outputs: TruoraBlockOutput?

    init(
        blockId: String,
        type: TruoraBlockType,
        status: TruoraBlockStatus,
        failureStatus: TruoraFailureStatus? = nil,
        declinedReason: String? = nil,
        outputs: TruoraBlockOutput? = nil
    ) {
        self.blockId = blockId
        self.type = type
        self.status = status
        self.failureStatus = failureStatus
        self.declinedReason = declinedReason
        self.outputs = outputs
    }

    private enum CodingKeys: String, CodingKey {
        case blockId = "verification_id"
        case type = "name"
        case status
        case failureStatus = "failure_status"
        case declinedReason = "declined_reason"
        case outputs
    }
}
