//
//  TruoraNativeModels.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 23/01/26.
//

import Foundation

// MARK: - Native API Models

// These are native Swift models for API communication, prefixed with "Native"
// to avoid conflicts with KMP exported types during the migration period.

struct NativeValidationRequest: Codable {
    let type: String
    let country: String?
    let accountId: String
    let threshold: Double?
    let subvalidations: [String]?
    let documentType: String?
    let timeout: Int?

    enum CodingKeys: String, CodingKey {
        case type
        case country
        case accountId = "account_id"
        case threshold
        case subvalidations
        case documentType = "document_type"
        case timeout
    }
}

struct NativeValidationCreateResponse: Codable {
    let validationId: String
    let instructions: NativeValidationInstructions?

    enum CodingKeys: String, CodingKey {
        case validationId = "validation_id"
        case instructions
    }
}

struct NativeValidationInstructions: Codable {
    let fileUploadLink: String?
    let frontUrl: String?
    let reverseUrl: String?

    enum CodingKeys: String, CodingKey {
        case fileUploadLink = "file_upload_link"
        case frontUrl = "front_url"
        case reverseUrl = "reverse_url"
    }
}

struct NativeValidationDetailResponse: Codable {
    let validationId: String
    let validationStatus: String
    let creationDate: String
    let accountId: String
    let type: String
    let details: NativeValidationDetails?

    enum CodingKeys: String, CodingKey {
        case validationId = "validation_id"
        case validationStatus = "validation_status"
        case creationDate = "creation_date"
        case accountId = "account_id"
        case type
        case details
    }
}

struct NativeValidationDetails: Codable {
    let faceRecognitionValidations: NativeFaceRecognitionValidations?

    enum CodingKeys: String, CodingKey {
        case faceRecognitionValidations = "face_recognition_validations"
    }
}

struct NativeFaceRecognitionValidations: Codable {
    let confidenceScore: Double?

    enum CodingKeys: String, CodingKey {
        case confidenceScore = "confidence_score"
    }
}

// MARK: - Enrollment Models

struct NativeEnrollmentRequest: Codable {
    let type: String
    let userAuthorized: Bool
    let accountId: String?
    let confirmation: String?

    enum CodingKeys: String, CodingKey {
        case type
        case userAuthorized = "user_authorized"
        case accountId = "account_id"
        case confirmation
    }
}

struct NativeEnrollmentResponse: Codable {
    let enrollmentId: String
    let accountId: String
    let fileUploadLink: String?
    let status: String
    let reason: String?
    let creationDate: String
    let updateDate: String?
    let validationType: String?

    enum CodingKeys: String, CodingKey {
        case enrollmentId = "enrollment_id"
        case accountId = "account_id"
        case fileUploadLink = "file_upload_link"
        case status, reason
        case creationDate = "creation_date"
        case updateDate = "update_date"
        case validationType = "validation_type"
    }
}

// MARK: - Image Evaluation Models

struct NativeImageEvaluationRequest: Codable {
    let image: String
    let country: String
    let documentType: String
    let documentSide: String
    let validationId: String?
    let evaluationType: String

    enum CodingKeys: String, CodingKey {
        case image
        case country
        case documentType = "document_type"
        case documentSide = "document_side"
        case validationId = "validation_id"
        case evaluationType = "evaluation_type"
    }

    init(
        image: String,
        country: String,
        documentType: String,
        documentSide: String,
        validationId: String?,
        evaluationType: String = "document"
    ) {
        self.image = image
        self.country = country
        self.documentType = documentType
        self.documentSide = documentSide
        self.validationId = validationId
        self.evaluationType = evaluationType
    }
}

struct NativeImageEvaluationResponse: Codable {
    let status: String?
    let feedback: NativeImageEvaluationFeedback?
}

struct NativeImageEvaluationFeedback: Codable {
    let reason: String?
    let hints: [String]?
}

// MARK: - Enums

enum NativeValidationTypeEnum: String {
    case faceRecognition = "face-recognition"
    case documentValidation = "document-validation"
}

enum NativeSubValidationTypeEnum: String {
    case passiveLiveness = "passive_liveness"
    case similarity
}
