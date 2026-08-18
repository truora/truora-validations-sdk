//
//  TruoraProcessEnums.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 26/05/26.
//

import Foundation

// MARK: - DI Process Enums

// Enums for the Digital Identity Processes API responses, prefixed with "DI"
// to avoid conflicts with existing Validations models.

/// Status of a block within a DI process.
enum TruoraBlockStatus: String, Codable {
    case pending
    case success
    case failure
}

/// Type of DI process.
enum TruoraProcessType: String, Codable {
    case dynamic
}

/// Reason a process failed.
enum TruoraFailureStatus: String, Codable {
    case declined
    case expired
    case systemError = "system_error"
    case canceled
}

/// Retry availability for the current step.
enum TruoraRetryStatus: String, Codable {
    case available
    case unavailable
}

/// Step types the SDK knows how to render.
///
/// Unknown backend values decode as `.unknown` so new step types
/// never crash the SDK.
enum TruoraStepType: String, Codable {
    // Authorization
    case enterAuthorization = "enter_authorization"

    // Document block
    case enterDocumentType = "enter_document_type"
    case takeDocumentPhoto = "take_document_photo"

    // Face recognition
    case recordFacePhoto = "record_face_photo"
    case recordFaceVideo = "record_face_video"
    case recordFacePhotoLiveness = "record_face_photo_liveness"
    case recordFaceVideoLiveness = "record_face_video_liveness"
    case enterFaceVerification = "enter_face_verification"
    case enterFaceVerificationLiveness = "enter_face_verification_liveness"

    // Invoice block
    case enterInvoiceCountry = "enter_invoice_country"
    case takeInvoicePhoto = "take_invoice_photo"

    // Custom question
    case enterResponse = "enter_response"

    /// Fallback for step types the SDK does not yet handle.
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = TruoraStepType(rawValue: rawValue) ?? .unknown
    }
}

extension TruoraStepType {
    /// Safely converts a raw step type string, falling back to `.unknown`
    /// for values the SDK does not recognize.
    init(stepType: String) {
        self = TruoraStepType(rawValue: stepType) ?? .unknown
    }
}

/// Block types used by the DI Processes API.
///
/// Unknown backend values decode as `.unknown` so new block names
/// never crash the SDK.
enum TruoraBlockType: String, Codable {
    case documentVerification = "document_verification"
    case documentVerificationWithFaceRecognition = "document_verification_with_face_recognition"
    case documentVerificationWithLiveness = "document_verification_with_liveness"
    case enterAuthorization = "enter_authorization"
    case invoiceVerification = "invoice_verification"
    case faceRecognition = "face_recognition"
    case customQuestion = "custom_question"
    /// Synthetic block the backend appends to a flow to aggregate its
    /// validation results and (when applicable) run the risk evaluation.
    case getValidationsResult = "get_validations_result"

    /// Fallback for block names the SDK does not yet handle.
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = TruoraBlockType(rawValue: rawValue) ?? .unknown
    }
}

/// Status of a risk evaluation.
enum TruoraRiskEvaluationStatus: String, Codable {
    case pending
    case failure
    case success
    case completed
    case error
    case expired
    case processing
    case systemError = "system_error"
    case skipped
}

/// Result of a risk evaluation.
enum TruoraRiskEvaluationResult: String, Codable {
    case risky
    case notRisky = "not_risky"
    case notEstablished = "not_established"
    case skipped
}

/// Source that triggered a risk evaluation.
enum TruoraRiskEvaluationSource: String, Codable {
    case documentValidation = "document_validation"
    case faceValidation = "face_validation"
    case identityProcess = "identity_process"
}
