//
//  ValidationApiError.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 22/01/26.
//

import Foundation

/// Enum representing errors returned by the Validations API
///
/// Known errors have explicit types, while unknown errors are wrapped in Unknown
///
/// Note: Some error cases (validationDeclined, validationExpired) return -1 for httpCode
/// as they represent logical validation states rather than HTTP responses
public enum ValidationApiError: Error, LocalizedError, Equatable {
    /// File upload link has expired (HTTP 403)
    case expiredFileUploadLink(httpCode: Int)

    /// Face not detected in document (HTTP 400)
    case faceNotFound(httpCode: Int)

    /// Temporary API key has expired (HTTP 403)
    case expiredApiKey(httpCode: Int)

    /// Validation was declined by the API (not an HTTP error)
    case validationDeclined

    /// Validation has expired (not an HTTP error)
    case validationExpired

    /// System error from the API (HTTP 500)
    case validationSystemError(httpCode: Int)

    /// Generic wrapper for unknown API errors
    case unknown(httpCode: Int, message: String)

    /// The error code for this validation API error
    public var code: Int {
        switch self {
        case .expiredFileUploadLink:
            30001
        case .faceNotFound:
            30002
        case .expiredApiKey:
            30003
        case .validationDeclined:
            30006
        case .validationExpired:
            30007
        case .validationSystemError:
            30008
        case .unknown:
            30000
        }
    }

    /// The HTTP status code associated with this error
    /// Returns -1 for logical validation states that don't have an associated HTTP response
    public var httpCode: Int {
        switch self {
        case .expiredFileUploadLink(let httpCode),
             .faceNotFound(let httpCode),
             .expiredApiKey(let httpCode),
             .validationSystemError(let httpCode):
            httpCode
        case .validationDeclined, .validationExpired:
            -1 // Not an HTTP error, represents validation state
        case .unknown(let httpCode, _):
            httpCode
        }
    }

    /// Localized error description
    public var errorDescription: String? {
        switch self {
        case .expiredFileUploadLink:
            "File could not be uploaded. Please try again"
        case .faceNotFound:
            "Face not detected in document. Please try again"
        case .expiredApiKey:
            "The temporary api key has expired. Please try again"
        case .validationDeclined:
            "Validation declined"
        case .validationExpired:
            "Validation expired"
        case .validationSystemError:
            "Validation failed due to system error"
        case .unknown(_, let message):
            message
        }
    }
}
