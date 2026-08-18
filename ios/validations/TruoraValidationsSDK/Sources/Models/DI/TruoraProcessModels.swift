//
//  TruoraProcessModels.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 26/05/26.
//

import Foundation

// MARK: - DI Process Response Models

// Native Swift models for the Digital Identity Processes API, prefixed with
// "Truora" to avoid conflicts with existing Validations models and KMP exports.
// Only fields the SDK consumes in Phase 1 are included; the rest are silently
// ignored by Swift's Codable.

/// Bag of arbitrary key/value data produced by a block.
///
/// Modelled as `[String: JSONValue]` so the SDK can surface backend-provided
/// fields without requiring a model change for every new key.
typealias TruoraBlockOutput = [String: JSONValue]

/// Bag of arbitrary configuration values attached to a process or step.
typealias TruoraBlockConfigValues = [String: JSONValue]

// MARK: - Step Output

/// Result the backend attaches to a step once it has been verified.
///
/// Distinct from ``TruoraBlock/outputs``, which is the data the whole block produced.
///
/// The runner reads ``status`` to decide whether the step advanced, must be
/// retried, or is still resolving — see ``TruoraProcessResponse/step(at:)`` and the
/// polling controller. Only the fields the SDK consumes are modelled.
struct TruoraStepOutput: Codable, Equatable {
    /// `nil` until the backend has evaluated the step.
    let status: TruoraBlockStatus?
    let failureStatus: TruoraFailureStatus?
    let declinedReason: String?
    let message: String?
    /// `true` once the backend has confirmed the step's media landed in storage.
    let mediaUploaded: Bool?
    let stepDataReceived: Bool?

    init(
        status: TruoraBlockStatus? = nil,
        failureStatus: TruoraFailureStatus? = nil,
        declinedReason: String? = nil,
        message: String? = nil,
        mediaUploaded: Bool? = nil,
        stepDataReceived: Bool? = nil
    ) {
        self.status = status
        self.failureStatus = failureStatus
        self.declinedReason = declinedReason
        self.message = message
        self.mediaUploaded = mediaUploaded
        self.stepDataReceived = stepDataReceived
    }

    private enum CodingKeys: String, CodingKey {
        case status
        case failureStatus = "failure_status"
        case declinedReason = "declined_reason"
        case message
        case mediaUploaded = "media_uploaded"
        case stepDataReceived = "step_data_received"
    }
}

// MARK: - Identity Process Response

/// Top-level response from the DI Processes API (`GET /v1/processes/{id}`
/// and other process endpoints).
///
/// Trimmed to the fields the SDK reads during process orchestration.
/// Optional fields not present in the JSON are silently skipped by Codable.
struct TruoraProcessResponse: Codable {
    let processId: String
    let flowId: String?
    let clientId: String?
    let status: TruoraProcessStatus?
    let processType: TruoraProcessType?
    let currentStepId: String?
    let currentStepType: TruoraStepType?
    let currentStepData: TruoraCurrentStepData?
    /// Index of the step in progress within ``steps``. The backend omits the key
    /// when it is `0`, so prefer ``currentStepIndex`` over reading this directly.
    let currentStep: Int?
    let country: String?
    /// Country the backend derived from the caller's IP. This — not ``country``,
    /// which is the process's own configured country — is the device-country
    /// analog the web runner resolves consent-terms variants against
    /// (`device.ts` seeds `deviceInfo.location.country` from it).
    let geolocationIpCountry: String?
    let failureStatus: TruoraFailureStatus?
    let declinedReason: String?
    let expiredReason: String?
    let errorMessage: String?
    let timeToLive: Int?
    let steps: [TruoraStep]?
    /// Raw block type strings, deliberately **not** ``TruoraBlockType``: consent
    /// hydration must substring-match server-controlled names (any name containing
    /// `credit_bureau` triggers the items consent), and the enum collapses unknown
    /// values to `.unknown`, losing the string.
    let identityBlockTypes: [String]?
    let identityBlocks: [TruoraIdentityBlock]?
    let blocks: [String: TruoraBlockStatus]?
    let riskEvaluation: TruoraRiskEvaluationOutput?
    let label: String?

    init(
        processId: String,
        flowId: String? = nil,
        clientId: String? = nil,
        status: TruoraProcessStatus? = nil,
        processType: TruoraProcessType? = nil,
        currentStepId: String? = nil,
        currentStepType: TruoraStepType? = nil,
        currentStepData: TruoraCurrentStepData? = nil,
        currentStep: Int? = nil,
        country: String? = nil,
        geolocationIpCountry: String? = nil,
        failureStatus: TruoraFailureStatus? = nil,
        declinedReason: String? = nil,
        expiredReason: String? = nil,
        errorMessage: String? = nil,
        timeToLive: Int? = nil,
        steps: [TruoraStep]? = nil,
        identityBlockTypes: [String]? = nil,
        identityBlocks: [TruoraIdentityBlock]? = nil,
        blocks: [String: TruoraBlockStatus]? = nil,
        riskEvaluation: TruoraRiskEvaluationOutput? = nil,
        label: String? = nil
    ) {
        self.processId = processId
        self.flowId = flowId
        self.clientId = clientId
        self.status = status
        self.processType = processType
        self.currentStepId = currentStepId
        self.currentStepType = currentStepType
        self.currentStepData = currentStepData
        self.currentStep = currentStep
        self.country = country
        self.geolocationIpCountry = geolocationIpCountry
        self.failureStatus = failureStatus
        self.declinedReason = declinedReason
        self.expiredReason = expiredReason
        self.errorMessage = errorMessage
        self.timeToLive = timeToLive
        self.steps = steps
        self.identityBlockTypes = identityBlockTypes
        self.identityBlocks = identityBlocks
        self.blocks = blocks
        self.riskEvaluation = riskEvaluation
        self.label = label
    }

    private enum CodingKeys: String, CodingKey {
        case processId = "process_id"
        case status
        case flowId = "flow_id"
        case clientId = "client_id"
        case processType = "process_type"
        case currentStepId = "current_step_id"
        case currentStepType = "current_step_type"
        case currentStepData = "current_step_data"
        case currentStep = "current_step"
        case country
        case geolocationIpCountry = "geolocation_ip_country"
        case failureStatus = "failure_status"
        case declinedReason = "declined_reason"
        case expiredReason = "expired_reason"
        case errorMessage = "error_message"
        case timeToLive = "time_to_live"
        case steps
        case identityBlockTypes = "identity_verification_names"
        case identityBlocks = "identity_verifications"
        case blocks = "verifications"
        case riskEvaluation = "risk_evaluation"
        case label
    }
}

// MARK: - Step Resolution

extension TruoraProcessResponse {
    /// Index of the step in progress. `current_step` is `omitempty` on the wire,
    /// so an absent value means the first step.
    var currentStepIndex: Int {
        currentStep ?? 0
    }

    /// The step at `index`, or `nil` when `steps` cannot serve it.
    func step(at index: Int) -> TruoraStep? {
        guard let steps, index >= 0, index < steps.count else {
            return nil
        }

        return steps[index]
    }

    /// The step the SDK should render: identified by `current_step_id` when the
    /// backend supplies one, otherwise resolved positionally by `current_step`.
    func activeStep() -> TruoraStep? {
        if let currentStepId, !currentStepId.isEmpty {
            return steps?.first { $0.stepId == currentStepId }
        }

        return step(at: currentStepIndex)
    }
}

// MARK: - Current Step Data

/// Runtime payload describing the step currently in progress.
struct TruoraCurrentStepData: Codable {
    let type: String
    let output: TruoraStepOutput?
    let config: TruoraBlockConfigValues?
    let expectedInputs: [TruoraInput]?
    let asyncStep: Bool?
    let description: String?
    let retryStatus: TruoraRetryStatus?
    let retryReason: String?

    init(
        type: String,
        output: TruoraStepOutput? = nil,
        config: TruoraBlockConfigValues? = nil,
        expectedInputs: [TruoraInput]? = nil,
        asyncStep: Bool? = nil,
        description: String? = nil,
        retryStatus: TruoraRetryStatus? = nil,
        retryReason: String? = nil
    ) {
        self.type = type
        self.output = output
        self.config = config
        self.expectedInputs = expectedInputs
        self.asyncStep = asyncStep
        self.description = description
        self.retryStatus = retryStatus
        self.retryReason = retryReason
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case output = "verification_output"
        case config
        case expectedInputs = "expected_inputs"
        case asyncStep = "async_step"
        case description
        case retryStatus = "retry_status"
        case retryReason = "retry_reason"
    }
}

// MARK: - Step

/// Description of a single step the user must complete inside a process.
struct TruoraStep: Codable {
    let stepId: String
    let processId: String?
    let blockId: String?
    let blockType: TruoraBlockType?
    let type: TruoraStepType
    let output: TruoraStepOutput?
    let title: String?
    let isProcessFirstStep: Bool?
    let isProcessFinalStep: Bool?
    let description: String?
    let config: TruoraBlockConfigValues?
    var expectedInputs: [TruoraInput]?
    let filesUploadUrls: [TruoraFileUpload]?
    let remainingRetries: Int?
    let asyncStep: Bool?
    let validationIndex: Int?

    init(
        stepId: String,
        processId: String? = nil,
        blockId: String? = nil,
        blockType: TruoraBlockType? = nil,
        type: TruoraStepType,
        output: TruoraStepOutput? = nil,
        title: String? = nil,
        isProcessFirstStep: Bool? = nil,
        isProcessFinalStep: Bool? = nil,
        description: String? = nil,
        config: TruoraBlockConfigValues? = nil,
        expectedInputs: [TruoraInput]? = nil,
        filesUploadUrls: [TruoraFileUpload]? = nil,
        remainingRetries: Int? = nil,
        asyncStep: Bool? = nil,
        validationIndex: Int? = nil
    ) {
        self.stepId = stepId
        self.processId = processId
        self.blockId = blockId
        self.blockType = blockType
        self.type = type
        self.output = output
        self.title = title
        self.isProcessFirstStep = isProcessFirstStep
        self.isProcessFinalStep = isProcessFinalStep
        self.description = description
        self.config = config
        self.expectedInputs = expectedInputs
        self.filesUploadUrls = filesUploadUrls
        self.remainingRetries = remainingRetries
        self.asyncStep = asyncStep
        self.validationIndex = validationIndex
    }

    private enum CodingKeys: String, CodingKey {
        case stepId = "step_id"
        case processId = "process_id"
        case blockId = "verification_id"
        case blockType = "verification_type"
        case type
        case output = "verification_output"
        case title
        case isProcessFirstStep = "is_process_first_step"
        case isProcessFinalStep = "is_process_final_step"
        case description
        case config
        case expectedInputs = "expected_inputs"
        case filesUploadUrls = "files_upload_urls"
        case remainingRetries = "remaining_retries"
        case asyncStep = "async_step"
        case validationIndex = "validation_index"
    }
}

// MARK: - Step Input Filling

extension TruoraStep {
    /// Returns a copy of the step with `values` applied to the matching entries of
    /// ``expectedInputs``.
    ///
    /// The backend pairs a submitted value with an expected input on **both**
    /// `type` and `name` (`Step.GetInputValue`), so a value whose type does not
    /// line up is silently dropped server-side. Inputs with no matching value are
    /// forwarded untouched.
    func settingInputValues(_ values: [TruoraStepInputValue]) -> TruoraStep {
        guard let expectedInputs else {
            return self
        }

        var copy = self
        copy.expectedInputs = expectedInputs.map { input in
            guard let match = values.first(where: { $0.type == input.type && $0.name == input.name }) else {
                return input
            }

            var filled = input
            filled.value = match.value
            return filled
        }

        return copy
    }
}

// MARK: - Input

/// A single input the user is expected to provide for a step.
struct TruoraInput: Codable {
    let type: String
    let name: String
    var value: String?
    let description: String?
    let options: [String]?
    let optional: Bool?
    let length: Int?
    let readOnly: Bool?
    let mediaUrl: String?
    let mediaName: String?
    let mediaType: String?
    let messageMediaType: String?
    let fileUploadUrl: String?
    let mediaId: String?

    init(
        type: String,
        name: String,
        value: String? = nil,
        description: String? = nil,
        options: [String]? = nil,
        optional: Bool? = nil,
        length: Int? = nil,
        readOnly: Bool? = nil,
        mediaUrl: String? = nil,
        mediaName: String? = nil,
        mediaType: String? = nil,
        messageMediaType: String? = nil,
        fileUploadUrl: String? = nil,
        mediaId: String? = nil
    ) {
        self.type = type
        self.name = name
        self.value = value
        self.description = description
        self.options = options
        self.optional = optional
        self.length = length
        self.readOnly = readOnly
        self.mediaUrl = mediaUrl
        self.mediaName = mediaName
        self.mediaType = mediaType
        self.messageMediaType = messageMediaType
        self.fileUploadUrl = fileUploadUrl
        self.mediaId = mediaId
    }

    private enum CodingKeys: String, CodingKey {
        case type, name, value, description, options, optional, length
        case readOnly = "read_only"
        case mediaUrl = "media_url"
        case mediaName = "media_name"
        case mediaType = "media_type"
        case messageMediaType = "message_media_type"
        case fileUploadUrl = "file_upload_url"
        case mediaId = "media_id"
    }
}

// MARK: - File Upload

/// Pre-signed upload target the SDK can `PUT` a captured asset to.
struct TruoraFileUpload: Codable {
    let name: String
    let url: String
    let description: String?
    let placeholder: String?
    let mediaUrl: String?
    let messageMediaType: String?
    let mediaType: String?
    let mediaId: String?

    init(
        name: String,
        url: String,
        description: String? = nil,
        placeholder: String? = nil,
        mediaUrl: String? = nil,
        messageMediaType: String? = nil,
        mediaType: String? = nil,
        mediaId: String? = nil
    ) {
        self.name = name
        self.url = url
        self.description = description
        self.placeholder = placeholder
        self.mediaUrl = mediaUrl
        self.messageMediaType = messageMediaType
        self.mediaType = mediaType
        self.mediaId = mediaId
    }

    private enum CodingKeys: String, CodingKey {
        case name, url, description, placeholder
        case mediaUrl = "media_url"
        case messageMediaType = "message_media_type"
        case mediaType = "media_type"
        case mediaId = "media_id"
    }
}

// MARK: - Identity Block

/// Identity block grouping inside a process.
struct TruoraIdentityBlock: Codable {
    let blockId: String
    let type: TruoraBlockType
    let config: TruoraBlockConfigValues?
    let steps: [TruoraStep]?
    let logic: [String]?

    init(
        blockId: String,
        type: TruoraBlockType,
        config: TruoraBlockConfigValues? = nil,
        steps: [TruoraStep]? = nil,
        logic: [String]? = nil
    ) {
        self.blockId = blockId
        self.type = type
        self.config = config
        self.steps = steps
        self.logic = logic
    }

    private enum CodingKeys: String, CodingKey {
        case blockId = "verification_id"
        case type = "name"
        case config
        case steps
        // Backend serializes this as "if" (JSON Logic conditional expressions)
        case logic = "if"
    }
}

// MARK: - Risk Evaluation Output

/// Typed risk evaluation output attached to a DI process.
struct TruoraRiskEvaluationOutput: Codable {
    let riskEvaluationId: String?
    let riskEvaluationStatus: TruoraRiskEvaluationStatus?
    let riskEvaluationResult: TruoraRiskEvaluationResult?
    let documentValidationId: String?
    let faceValidationId: String?
    let manuallyReviewed: Bool?
    let source: TruoraRiskEvaluationSource?

    init(
        riskEvaluationId: String? = nil,
        riskEvaluationStatus: TruoraRiskEvaluationStatus? = nil,
        riskEvaluationResult: TruoraRiskEvaluationResult? = nil,
        documentValidationId: String? = nil,
        faceValidationId: String? = nil,
        manuallyReviewed: Bool? = nil,
        source: TruoraRiskEvaluationSource? = nil
    ) {
        self.riskEvaluationId = riskEvaluationId
        self.riskEvaluationStatus = riskEvaluationStatus
        self.riskEvaluationResult = riskEvaluationResult
        self.documentValidationId = documentValidationId
        self.faceValidationId = faceValidationId
        self.manuallyReviewed = manuallyReviewed
        self.source = source
    }

    private enum CodingKeys: String, CodingKey {
        case riskEvaluationId = "risk_evaluation_id"
        case riskEvaluationStatus = "risk_evaluation_status"
        case riskEvaluationResult = "risk_evaluation_result"
        case documentValidationId = "document_validation_id"
        case faceValidationId = "face_validation_id"
        case manuallyReviewed = "manually_reviewed"
        case source
    }
}
