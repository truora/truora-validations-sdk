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

/// Body of `POST /validations`. The backend expects
/// `application/x-www-form-urlencoded`, so this struct is **not** serialized via
/// `JSONEncoder` — it's hand-encoded in `TruoraAPIClient.encodeToFormData(_:)`.
///
/// ⚠️ If you add a field here, add it to `TruoraAPIClient.encodeToFormData` as
/// well. `TruoraAPIClientTests.testEncodeToFormData_includesAllNonNilFields`
/// guards against this drift.
struct NativeValidationRequest: Codable {
    let type: String
    let country: String?
    let accountId: String
    let threshold: Double?
    let subvalidations: [String]?
    let documentType: String?
    let timeout: Int?
    let userAuthorized: Bool
    let checkManualReviewAvailability: Bool
    let retryOfId: String?

    init(
        type: String,
        country: String?,
        accountId: String,
        threshold: Double?,
        subvalidations: [String]?,
        documentType: String?,
        timeout: Int?,
        userAuthorized: Bool,
        checkManualReviewAvailability: Bool,
        retryOfId: String? = nil
    ) {
        self.type = type
        self.country = country
        self.accountId = accountId
        self.threshold = threshold
        self.subvalidations = subvalidations
        self.documentType = documentType
        self.timeout = timeout
        self.userAuthorized = userAuthorized
        self.checkManualReviewAvailability = checkManualReviewAvailability
        self.retryOfId = retryOfId
    }

    enum CodingKeys: String, CodingKey {
        case type
        case country
        case accountId = "account_id"
        case threshold
        case subvalidations
        case documentType = "document_type"
        case timeout
        case userAuthorized = "user_authorized"
        case checkManualReviewAvailability = "check_manual_review_availability"
        case retryOfId = "retry_of_id"
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
    let failureStatus: String?
    let declinedReason: String?
    let remainingRetries: Int?
    let validationInputs: NativeValidationInputs?
    let userResponse: NativeUserResponse?

    enum CodingKeys: String, CodingKey {
        case validationId = "validation_id"
        case validationStatus = "validation_status"
        case creationDate = "creation_date"
        case accountId = "account_id"
        case type
        case details
        case failureStatus = "failure_status"
        case declinedReason = "declined_reason"
        case remainingRetries = "remaining_retries"
        case validationInputs = "validation_inputs"
        case userResponse = "user_response"
    }

    init(
        validationId: String,
        validationStatus: String,
        creationDate: String,
        accountId: String,
        type: String,
        details: NativeValidationDetails? = nil,
        failureStatus: String? = nil,
        declinedReason: String? = nil,
        remainingRetries: Int? = nil,
        validationInputs: NativeValidationInputs? = nil,
        userResponse: NativeUserResponse? = nil
    ) {
        self.validationId = validationId
        self.validationStatus = validationStatus
        self.creationDate = creationDate
        self.accountId = accountId
        self.type = type
        self.details = details
        self.failureStatus = failureStatus
        self.declinedReason = declinedReason
        self.remainingRetries = remainingRetries
        self.validationInputs = validationInputs
        self.userResponse = userResponse
    }
}

struct NativeValidationDetails: Codable {
    let faceRecognitionValidations: NativeFaceRecognitionValidations?
    let documentDetails: NativeDocumentDetails?
    let documentValidations: NativeDocumentSubValidations?
    let backgroundCheck: NativeBackgroundCheck?

    enum CodingKeys: String, CodingKey {
        case faceRecognitionValidations = "face_recognition_validations"
        case documentDetails = "document_details"
        case documentValidations = "document_validations"
        case backgroundCheck = "background_check"
    }

    init(
        faceRecognitionValidations: NativeFaceRecognitionValidations? = nil,
        documentDetails: NativeDocumentDetails? = nil,
        documentValidations: NativeDocumentSubValidations? = nil,
        backgroundCheck: NativeBackgroundCheck? = nil
    ) {
        self.faceRecognitionValidations = faceRecognitionValidations
        self.documentDetails = documentDetails
        self.documentValidations = documentValidations
        self.backgroundCheck = backgroundCheck
    }
}

struct NativeFaceRecognitionValidations: Codable {
    let confidenceScore: Double?
    let similarityStatus: String?
    let passiveLivenessStatus: String?
    let enrollmentId: String?
    let ageRange: NativeAgeRange?
    let faceSearch: NativeFaceSearch?

    enum CodingKeys: String, CodingKey {
        case confidenceScore = "confidence_score"
        case similarityStatus = "similarity_status"
        case passiveLivenessStatus = "passive_liveness_status"
        case enrollmentId = "enrollment_id"
        case ageRange = "age_range"
        case faceSearch = "face_search"
    }

    init(
        confidenceScore: Double? = nil,
        similarityStatus: String? = nil,
        passiveLivenessStatus: String? = nil,
        enrollmentId: String? = nil,
        ageRange: NativeAgeRange? = nil,
        faceSearch: NativeFaceSearch? = nil
    ) {
        self.confidenceScore = confidenceScore
        self.similarityStatus = similarityStatus
        self.passiveLivenessStatus = passiveLivenessStatus
        self.enrollmentId = enrollmentId
        self.ageRange = ageRange
        self.faceSearch = faceSearch
    }
}

struct NativeAgeRange: Codable {
    let high: Int?
    let low: Int?
}

struct NativeFaceSearch: Codable {
    let status: String?
    let confidenceScore: Double?

    enum CodingKeys: String, CodingKey {
        case status
        case confidenceScore = "confidence_score"
    }
}

struct NativeDocumentDetails: Codable {
    let docId: String?
    let country: String?
    let documentType: String?
    let documentNumber: String?
    let name: String?
    let lastName: String?
    let dateOfBirth: String?
    let gender: String?
    let issueDate: String?
    let expirationDate: String?
    let expeditionPlace: String?
    let birthPlace: String?
    let height: String?
    let rh: String?
    let mimeType: String?
    let clientId: String?
    let creationDate: String?
    let frontUrl: String?
    let reverseUrl: String?

    enum CodingKeys: String, CodingKey {
        case docId = "doc_id"
        case country
        case documentType = "document_type"
        case documentNumber = "document_number"
        case name
        case lastName = "last_name"
        case dateOfBirth = "date_of_birth"
        case gender
        case issueDate = "issue_date"
        case expirationDate = "expiration_date"
        case expeditionPlace = "expedition_place"
        case birthPlace = "birth_place"
        case height, rh
        case mimeType = "mime_type"
        case clientId = "client_id"
        case creationDate = "creation_date"
        case frontUrl = "front_url"
        case reverseUrl = "reverse_url"
    }

    // swiftlint:disable function_parameter_count
    init(
        docId: String? = nil,
        country: String? = nil,
        documentType: String? = nil,
        documentNumber: String? = nil,
        name: String? = nil,
        lastName: String? = nil,
        dateOfBirth: String? = nil,
        gender: String? = nil,
        issueDate: String? = nil,
        expirationDate: String? = nil,
        expeditionPlace: String? = nil,
        birthPlace: String? = nil,
        height: String? = nil,
        rh: String? = nil,
        mimeType: String? = nil,
        clientId: String? = nil,
        creationDate: String? = nil,
        frontUrl: String? = nil,
        reverseUrl: String? = nil
    ) {
        self.docId = docId
        self.country = country
        self.documentType = documentType
        self.documentNumber = documentNumber
        self.name = name
        self.lastName = lastName
        self.dateOfBirth = dateOfBirth
        self.gender = gender
        self.issueDate = issueDate
        self.expirationDate = expirationDate
        self.expeditionPlace = expeditionPlace
        self.birthPlace = birthPlace
        self.height = height
        self.rh = rh
        self.mimeType = mimeType
        self.clientId = clientId
        self.creationDate = creationDate
        self.frontUrl = frontUrl
        self.reverseUrl = reverseUrl
    }
    // swiftlint:enable function_parameter_count
}

struct NativeDocumentSubValidations: Codable {
    let dataConsistency: [NativeSubValidationResult]?
    let governmentDatabase: [NativeSubValidationResult]?
    let imageAnalysis: [NativeSubValidationResult]?
    let photocopyAnalysis: [NativeSubValidationResult]?
    let manualAnalysis: [NativeSubValidationResult]?
    let photoOfPhoto: [NativeSubValidationResult]?

    enum CodingKeys: String, CodingKey {
        case dataConsistency = "data_consistency"
        case governmentDatabase = "government_database"
        case imageAnalysis = "image_analysis"
        case photocopyAnalysis = "photocopy_analysis"
        case manualAnalysis = "manual_analysis"
        case photoOfPhoto = "photo_of_photo"
    }
}

struct NativeSubValidationResult: Codable {
    let validationName: String?
    let result: String?
    let validationType: String?
    let message: String?
    let manuallyReviewed: Bool?
    let createdAt: String?
    let dataValidations: [String: String]?

    enum CodingKeys: String, CodingKey {
        case validationName = "validation_name"
        case result
        case validationType = "validation_type"
        case message
        case manuallyReviewed = "manually_reviewed"
        case createdAt = "created_at"
        case dataValidations = "data_validations"
    }
}

struct NativeBackgroundCheck: Codable {
    let checkId: String?
    let checkUrl: String?

    enum CodingKeys: String, CodingKey {
        case checkId = "check_id"
        case checkUrl = "check_url"
    }
}

struct NativeValidationInputs: Codable {
    let country: String?
    let documentType: String?

    enum CodingKeys: String, CodingKey {
        case country
        case documentType = "document_type"
    }
}

struct NativeUserResponse: Codable {
    let inputFiles: [String]?

    enum CodingKeys: String, CodingKey {
        case inputFiles = "input_files"
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

// MARK: - Document Selection Models

struct NativeDocumentSelectionResponse: Codable {
    let countries: [NativeCountryResponse]
}

struct NativeCountryResponse: Codable {
    let country: String
    let displayName: String
    let flag: NativeFlagResponse
    let documentTypes: [NativeDocTypeResponse]

    enum CodingKeys: String, CodingKey {
        case country
        case displayName = "display_name"
        case flag
        case documentTypes = "document_types"
    }
}

struct NativeFlagResponse: Codable {
    let url: String
}

struct NativeDocTypeResponse: Codable {
    let documentType: String
    let displayName: String
    let examples: [NativeExampleResponse]

    enum CodingKeys: String, CodingKey {
        case documentType = "document_type"
        case displayName = "display_name"
        case examples
    }
}

struct NativeExampleResponse: Codable {
    let assetId: String
    let url: String
    let caption: String

    enum CodingKeys: String, CodingKey {
        case assetId = "asset_id"
        case url
        case caption
    }
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
