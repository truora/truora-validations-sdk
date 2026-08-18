//
//  ValidationDetail.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 05/02/26.
//

import Foundation

// MARK: - Validation Detail

/// Full validation detail returned by the Truora API after polling completes.
/// Contains the complete API response including validation inputs, user response,
/// and detailed results for face recognition, document validation, and background checks.
public struct ValidationDetail: Codable, Equatable {
    public let validationId: String
    public let type: String
    public let validationStatus: String
    public let failureStatus: String?
    public let declinedReason: String?
    public let remainingRetries: Int?
    public let creationDate: String
    public let accountId: String
    public let details: ValidationDetailInfo?
    public let validationInputs: ValidationDetailInputs?
    public let userResponse: ValidationDetailUserResponse?

    public init(
        validationId: String,
        type: String,
        validationStatus: String,
        failureStatus: String? = nil,
        declinedReason: String? = nil,
        remainingRetries: Int? = nil,
        creationDate: String,
        accountId: String,
        details: ValidationDetailInfo? = nil,
        validationInputs: ValidationDetailInputs? = nil,
        userResponse: ValidationDetailUserResponse? = nil
    ) {
        self.validationId = validationId
        self.type = type
        self.validationStatus = validationStatus
        self.failureStatus = failureStatus
        self.declinedReason = declinedReason
        self.remainingRetries = remainingRetries
        self.creationDate = creationDate
        self.accountId = accountId
        self.details = details
        self.validationInputs = validationInputs
        self.userResponse = userResponse
    }

    private enum CodingKeys: String, CodingKey {
        case validationId = "validation_id"
        case type
        case validationStatus = "validation_status"
        case failureStatus = "failure_status"
        case declinedReason = "declined_reason"
        case remainingRetries = "remaining_retries"
        case creationDate = "creation_date"
        case accountId = "account_id"
        case details
        case validationInputs = "validation_inputs"
        case userResponse = "user_response"
    }
}

// MARK: - Validation Detail Info

/// Contains the detailed results nested under the `details` key in the API response.
public struct ValidationDetailInfo: Codable, Equatable {
    public let faceRecognitionValidations: FaceRecognitionDetail?
    public let documentDetails: [String: JSONValue]?
    public let documentValidations: DocumentSubValidationResults?
    public let backgroundCheck: BackgroundCheckDetail?

    public init(
        faceRecognitionValidations: FaceRecognitionDetail? = nil,
        documentDetails: [String: JSONValue]? = nil,
        documentValidations: DocumentSubValidationResults? = nil,
        backgroundCheck: BackgroundCheckDetail? = nil
    ) {
        self.faceRecognitionValidations = faceRecognitionValidations
        self.documentDetails = documentDetails
        self.documentValidations = documentValidations
        self.backgroundCheck = backgroundCheck
    }

    private enum CodingKeys: String, CodingKey {
        case faceRecognitionValidations = "face_recognition_validations"
        case documentDetails = "document_details"
        case documentValidations = "document_validations"
        case backgroundCheck = "background_check"
    }
}

// MARK: - Face Recognition Detail

/// Detailed face recognition validation results.
public struct FaceRecognitionDetail: Codable, Equatable {
    public let confidenceScore: Double?
    public let similarityStatus: String?
    public let passiveLivenessStatus: String?
    public let enrollmentId: String?
    public let ageRange: AgeRangeDetail?
    public let faceSearch: FaceSearchDetail?

    public init(
        confidenceScore: Double? = nil,
        similarityStatus: String? = nil,
        passiveLivenessStatus: String? = nil,
        enrollmentId: String? = nil,
        ageRange: AgeRangeDetail? = nil,
        faceSearch: FaceSearchDetail? = nil
    ) {
        self.confidenceScore = confidenceScore
        self.similarityStatus = similarityStatus
        self.passiveLivenessStatus = passiveLivenessStatus
        self.enrollmentId = enrollmentId
        self.ageRange = ageRange
        self.faceSearch = faceSearch
    }

    private enum CodingKeys: String, CodingKey {
        case confidenceScore = "confidence_score"
        case similarityStatus = "similarity_status"
        case passiveLivenessStatus = "passive_liveness_status"
        case enrollmentId = "enrollment_id"
        case ageRange = "age_range"
        case faceSearch = "face_search"
    }
}

/// Age range estimated from face analysis.
public struct AgeRangeDetail: Codable, Equatable {
    public let high: Int?
    public let low: Int?

    public init(high: Int?, low: Int?) {
        self.high = high
        self.low = low
    }
}

/// Face search results from face recognition.
public struct FaceSearchDetail: Codable, Equatable {
    public let status: String?
    public let confidenceScore: Double?

    public init(status: String?, confidenceScore: Double?) {
        self.status = status
        self.confidenceScore = confidenceScore
    }

    private enum CodingKeys: String, CodingKey {
        case status
        case confidenceScore = "confidence_score"
    }
}

// MARK: - JSON Value

/// Represents a dynamically-typed value (string, number, bool, null, object, or array).
/// Used for `document_details` so the API can evolve without SDK changes.
public enum JSONValue: Codable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null
    case object([String: JSONValue])
    case array([JSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
            return
        }
        if let value = try? container.decode(String.self) {
            self = .string(value)
            return
        }
        if let value = try? container.decode(Int.self) {
            self = .int(value)
            return
        }
        if let value = try? container.decode(Double.self) {
            self = .double(value)
            return
        }
        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
            return
        }
        if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
            return
        }
        if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
            return
        }
        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Invalid JSON value"
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .null: try container.encodeNil()
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        }
    }

    /// Returns the string value when this is `.string(s)`, otherwise `nil`.
    public var stringValue: String? {
        if case .string(let value) = self {
            return value
        }
        return nil
    }
}

// MARK: - Document Sub-Validation Results

/// Results of document sub-validations (data consistency, government checks, etc.).
public struct DocumentSubValidationResults: Codable, Equatable {
    public let dataConsistency: [SubValidationDetail]?
    public let governmentDatabase: [SubValidationDetail]?
    public let imageAnalysis: [SubValidationDetail]?
    public let photocopyAnalysis: [SubValidationDetail]?
    public let manualAnalysis: [SubValidationDetail]?
    public let photoOfPhoto: [SubValidationDetail]?

    public init(
        dataConsistency: [SubValidationDetail]? = nil,
        governmentDatabase: [SubValidationDetail]? = nil,
        imageAnalysis: [SubValidationDetail]? = nil,
        photocopyAnalysis: [SubValidationDetail]? = nil,
        manualAnalysis: [SubValidationDetail]? = nil,
        photoOfPhoto: [SubValidationDetail]? = nil
    ) {
        self.dataConsistency = dataConsistency
        self.governmentDatabase = governmentDatabase
        self.imageAnalysis = imageAnalysis
        self.photocopyAnalysis = photocopyAnalysis
        self.manualAnalysis = manualAnalysis
        self.photoOfPhoto = photoOfPhoto
    }

    private enum CodingKeys: String, CodingKey {
        case dataConsistency = "data_consistency"
        case governmentDatabase = "government_database"
        case imageAnalysis = "image_analysis"
        case photocopyAnalysis = "photocopy_analysis"
        case manualAnalysis = "manual_analysis"
        case photoOfPhoto = "photo_of_photo"
    }
}

/// Individual sub-validation result entry.
/// All fields except `dataValidations` are optional to allow partial decoding
/// when the API omits fields, preventing a single missing field from causing
/// the entire validation detail to fail to decode.
public struct SubValidationDetail: Codable, Equatable {
    public let validationName: String?
    public let result: String?
    public let validationType: String?
    public let message: String?
    public let manuallyReviewed: Bool?
    public let createdAt: String?
    public let dataValidations: [String: String]?

    public init(
        validationName: String? = nil,
        result: String? = nil,
        validationType: String? = nil,
        message: String? = nil,
        manuallyReviewed: Bool? = nil,
        createdAt: String? = nil,
        dataValidations: [String: String]? = nil
    ) {
        self.validationName = validationName
        self.result = result
        self.validationType = validationType
        self.message = message
        self.manuallyReviewed = manuallyReviewed
        self.createdAt = createdAt
        self.dataValidations = dataValidations
    }

    private enum CodingKeys: String, CodingKey {
        case validationName = "validation_name"
        case result
        case validationType = "validation_type"
        case message
        case manuallyReviewed = "manually_reviewed"
        case createdAt = "created_at"
        case dataValidations = "data_validations"
    }
}

// MARK: - Background Check Detail

/// Background check results.
public struct BackgroundCheckDetail: Codable, Equatable {
    public let checkId: String?
    public let checkUrl: String?

    public init(checkId: String?, checkUrl: String?) {
        self.checkId = checkId
        self.checkUrl = checkUrl
    }

    private enum CodingKeys: String, CodingKey {
        case checkId = "check_id"
        case checkUrl = "check_url"
    }
}

// MARK: - Validation Inputs

/// Input parameters submitted with the validation (country, document type, etc.).
public struct ValidationDetailInputs: Codable, Equatable {
    public let country: String?
    public let documentType: String?

    public init(
        country: String? = nil,
        documentType: String? = nil
    ) {
        self.country = country
        self.documentType = documentType
    }

    private enum CodingKeys: String, CodingKey {
        case country
        case documentType = "document_type"
    }
}

// MARK: - User Response

/// User response data returned by the API.
public struct ValidationDetailUserResponse: Codable, Equatable {
    public let inputFiles: [String]?

    public init(inputFiles: [String]? = nil) {
        self.inputFiles = inputFiles
    }

    private enum CodingKeys: String, CodingKey {
        case inputFiles = "input_files"
    }
}
