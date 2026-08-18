//
//  TruoraProcessRequests.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 27/05/26.
//

import Foundation

// MARK: - DI Process Request Models

// Native Swift request models for the Digital Identity Processes API, prefixed
// with "Truora" to avoid conflicts with existing Validations models and KMP exports.
// Request-only models conform to Encodable; response models conform to Codable.

// MARK: - Block Input

/// A block descriptor sent when creating a process or adding a block.
/// Mirrors KMP `DynamicBlockInput`.
struct TruoraBlockInput: Encodable {
    let type: TruoraBlockType
    let config: TruoraBlockConfigValues
}

// MARK: - Create Process Request

/// Body for `POST /v1/processes`.  Mirrors KMP `CreateIdentityRequest`.
struct TruoraCreateProcessRequest: Encodable {
    let processType: TruoraProcessType
    let block: TruoraBlockInput
    let ttl: Int?
    let label: String?
    let geolocationIp: String?
    let processIp: String?
    let city: String?
    let lang: String?
    let deviceInfo: String?

    init(
        processType: TruoraProcessType = .dynamic,
        block: TruoraBlockInput,
        ttl: Int? = nil,
        label: String? = nil,
        geolocationIp: String? = nil,
        processIp: String? = nil,
        city: String? = nil,
        lang: String? = nil,
        deviceInfo: String? = nil
    ) {
        self.processType = processType
        self.block = block
        self.ttl = ttl
        self.label = label
        self.geolocationIp = geolocationIp
        self.processIp = processIp
        self.city = city
        self.lang = lang
        self.deviceInfo = deviceInfo
    }

    private enum CodingKeys: String, CodingKey {
        case processType = "process_type"
        case block = "verification"
        case ttl
        case label
        case geolocationIp = "geolocation_ip"
        case processIp = "process_ip"
        case city
        case lang
        case deviceInfo = "device_info"
    }
}

// MARK: - Add Block Request

/// Body for `POST /v1/processes/{id}/verifications`.
/// Mirrors KMP `AddDynamicBlockRequest`.
struct TruoraAddBlockRequest: Encodable {
    let block: TruoraBlockInput

    private enum CodingKeys: String, CodingKey {
        case block = "verification"
    }
}

// MARK: - Add Block Response

/// Response from `POST /v1/processes/{id}/verifications`.
/// Mirrors KMP `AddDynamicBlockRequestResponse`.
struct TruoraAddBlockResponse: Codable {
    let blockId: String
    let stepId: String
    let stepType: TruoraStepType
    let blocks: [String: TruoraBlockStatus]?

    init(
        blockId: String,
        stepId: String,
        stepType: TruoraStepType,
        blocks: [String: TruoraBlockStatus]? = nil
    ) {
        self.blockId = blockId
        self.stepId = stepId
        self.stepType = stepType
        self.blocks = blocks
    }

    private enum CodingKeys: String, CodingKey {
        case blockId = "verification_id"
        case stepId = "step_id"
        case stepType = "step_type"
        case blocks = "verifications"
    }
}

// MARK: - Verify Step Request

/// Body for `POST /v1/processes/steps/{step_id}`.
///
/// Build the step with ``TruoraStep/settingInputValues(_:)``.
struct TruoraVerifyStepRequest: Encodable {
    let step: TruoraStep

    /// Flattens `step` into the top-level container, mirroring the embedded
    /// struct the backend decodes.
    func encode(to encoder: Encoder) throws {
        try step.encode(to: encoder)
    }
}

// MARK: - Step Input Value

/// A captured value for one of a step's `expected_inputs`.
///
/// Carries ``type`` as well as ``name`` because the backend matches an expected
/// input on both; a value whose `type` does not line up never reaches the step.
struct TruoraStepInputValue: Equatable {
    let type: String
    let name: String
    let value: String
}

// MARK: - Back Step Request

/// Body for `POST /v1/processes/steps/{step_id}/back`.
/// Mirrors KMP `IdentityBackStepRequest`, but sent as a JSON body (the DI
/// Processes API on iOS uses JSON instead of the form-urlencoded body Android
/// sends through Ktor).
struct TruoraBackStepRequest: Encodable {
    let retryStep: Bool
    let deleteAll: Bool

    private enum CodingKeys: String, CodingKey {
        case retryStep = "retry_step"
        case deleteAll = "delete_all"
    }
}

// MARK: - Cancel Process Request

/// Body for `POST /v1/processes/{id}/status`.
/// Mirrors KMP `CancelProcessRequest`, but sent as a JSON body. `failureStatus`
/// is required; the reason fields are optional and omitted when `nil`.
struct TruoraCancelProcessRequest: Encodable {
    let failureStatus: TruoraFailureStatus
    let declinedReason: String?
    let canceledReason: String?

    init(
        failureStatus: TruoraFailureStatus,
        declinedReason: String? = nil,
        canceledReason: String? = nil
    ) {
        self.failureStatus = failureStatus
        self.declinedReason = declinedReason
        self.canceledReason = canceledReason
    }

    private enum CodingKeys: String, CodingKey {
        case failureStatus = "failure_status"
        case declinedReason = "declined_reason"
        case canceledReason = "canceled_reason"
    }
}
