//
//  ValidationModels.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 30/10/25.
//

import Foundation

// MARK: - Validation Result

public struct ValidationResult: Codable, Equatable {
    public let validationId: String
    public let status: ValidationStatus
    public let confidence: Double?
    public let metadata: [String: Int]? // Changed from [String: Any] for Codable compatibility

    public init(
        validationId: String,
        status: ValidationStatus,
        confidence: Double? = nil,
        metadata: [String: Int]? = nil
    ) {
        self.validationId = validationId
        self.status = status
        self.confidence = confidence
        self.metadata = metadata
    }
}

public enum ValidationStatus: String, Codable {
    case pending
    case success
    case failed
    case processing
}

// MARK: - Enrollment Models

public struct EnrollmentData {
    public let enrollmentId: String
    public let accountId: String
    public let uploadUrl: String?
    public let createdAt: Date

    public init(
        enrollmentId: String,
        accountId: String,
        uploadUrl: String?,
        createdAt: Date
    ) {
        self.enrollmentId = enrollmentId
        self.accountId = accountId
        self.uploadUrl = uploadUrl
        self.createdAt = createdAt
    }
}

// MARK: - Validation Request

public struct ValidationRequest {
    public let accountId: String
    public let enrollmentId: String
    public let videoData: Data

    public init(
        accountId: String,
        enrollmentId: String,
        videoData: Data
    ) {
        self.accountId = accountId
        self.enrollmentId = enrollmentId
        self.videoData = videoData
    }
}

// MARK: - API Response Models

public struct EnrollmentResponse: Decodable {
    public let enrollmentId: String
    public let accountId: String
    public let fileUploadLink: String?
    public let status: String
    public let reason: String?
    public let creationDate: String
    public let updateDate: String?
    public let validationType: String?

    private enum CodingKeys: String, CodingKey {
        case enrollmentId = "enrollment_id"
        case accountId = "account_id"
        case fileUploadLink = "file_upload_link"
        case status
        case reason
        case creationDate = "creation_date"
        case updateDate = "update_date"
        case validationType = "validation_type"
    }
}

public struct ValidationCreateResponse: Decodable {
    public let validationId: String
    public let accountId: String
    public let type: String
    public let validationStatus: String
    public let lifecycleStatus: String?
    public let threshold: Double?
    public let creationDate: String
    public let ipAddress: String?
    public let details: ValidationDetails?
    public let instructions: ValidationInstructions?

    private enum CodingKeys: String, CodingKey {
        case validationId = "validation_id"
        case accountId = "account_id"
        case type
        case validationStatus = "validation_status"
        case lifecycleStatus = "lifecycle_status"
        case threshold
        case creationDate = "creation_date"
        case ipAddress = "ip_address"
        case details
        case instructions
    }
}

public struct ValidationInstructions: Decodable {
    public let fileUploadLink: String?
    public let frontUrl: String?
    public let reverseUrl: String?

    init(
        fileUploadLink: String? = nil,
        frontUrl: String? = nil,
        reverseUrl: String? = nil
    ) {
        self.fileUploadLink = fileUploadLink
        self.frontUrl = frontUrl
        self.reverseUrl = reverseUrl
    }

    private enum CodingKeys: String, CodingKey {
        case fileUploadLink = "file_upload_link"
        case frontUrl = "front_url"
        case reverseUrl = "reverse_url"
    }
}

public struct ValidationDetailResponse: Decodable {
    public let validationId: String
    public let validationStatus: String
    public let details: ValidationDetails?

    private enum CodingKeys: String, CodingKey {
        case validationId = "validation_id"
        case validationStatus = "validation_status"
        case details
    }
}

public struct ValidationDetails: Decodable {
    public let faceRecognitionValidations: FaceRecognitionValidations?

    private enum CodingKeys: String, CodingKey {
        case faceRecognitionValidations = "face_recognition_validations"
    }
}

public struct FaceRecognitionValidations: Decodable {
    public let confidenceScore: Double?
    public let passiveLivenessStatus: String?
    public let similarityStatus: String?

    private enum CodingKeys: String, CodingKey {
        case confidenceScore = "confidence_score"
        case passiveLivenessStatus = "passive_liveness_status"
        case similarityStatus = "similarity_status"
    }
}

// MARK: - Image Evaluation Models

public struct ImageEvaluationResponse: Decodable {
    public let status: String
    public let feedback: ImageEvaluationFeedback?
    public let llmEvaluation: [String: String]?

    private enum CodingKeys: String, CodingKey {
        case status
        case feedback
        case llmEvaluation = "llm_evaluation"
    }
}

public struct ImageEvaluationFeedback: Decodable {
    public let reason: String?
    public let message: String?
}
