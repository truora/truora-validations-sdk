//
//  TruoraException.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 22/01/26.
//

import Foundation

/// Base enum for all Truora SDK errors
///
/// Separates Validation API errors from SDK internal errors and network errors
///
/// ## Usage Examples
///
/// ### Creating SDK Errors
/// ```swift
/// // Using helper
/// throw ErrorHelpers.sdkError(type: .invalidApiKey, details: "Key expired")
///
/// // Direct creation
/// let error = SDKError(type: .invalidConfiguration, details: "Missing config")
/// throw TruoraException.sdk(error)
/// ```
///
/// ### Creating Network Errors
/// ```swift
/// throw ErrorHelpers.networkError(message: "Connection timeout", underlyingError: urlError)
/// // or
/// throw TruoraException.network(message: "Connection failed", underlyingError: nil)
/// ```
///
/// ### Creating Validation API Errors
/// ```swift
/// let apiError = ValidationApiError.expiredApiKey(httpCode: 403)
/// throw TruoraException.validationApi(apiError)
/// // or using helper
/// throw ErrorHelpers.validationApiError(.faceNotFound(httpCode: 400))
/// ```
///
/// ### Converting to TruoraError for callbacks
/// ```swift
/// let exception = TruoraException.sdk(SDKError(type: .invalidApiKey))
/// let truoraError = ErrorHelpers.toTruoraError(exception, currentValidation: "face")
/// onError?(truoraError)
/// ```
public enum TruoraException: Error, LocalizedError, Equatable {
    /// Error from the Validation API
    case validationApi(ValidationApiError)

    /// Internal SDK error (misconfiguration, invalid state, etc.)
    case sdk(SDKError)

    /// Network-related error
    case network(message: String, underlyingError: Error? = nil)

    /// The error code
    public var code: Int {
        switch self {
        case .validationApi(let error):
            error.code
        case .sdk(let error):
            error.code
        case .network:
            0
        }
    }

    /// The error domain string
    public var domain: String {
        switch self {
        case .validationApi:
            "ValidationApiError"
        case .sdk:
            "SDKError"
        case .network:
            "NetworkError"
        }
    }

    /// Localized error description
    public var errorDescription: String? {
        switch self {
        case .validationApi(let error):
            let description = error.errorDescription ?? "Validation API error"
            if error.httpCode > 0 {
                return "\(description)\nhttp code: \(error.httpCode)"
            }
            return description
        case .sdk(let error):
            return error.errorDescription
        case .network(let message, _):
            return message
        }
    }

    /// The underlying error if available
    public var underlyingError: Error? {
        switch self {
        case .validationApi, .sdk:
            nil
        case .network(_, let underlyingError):
            underlyingError
        }
    }

    // MARK: - Equatable

    public static func == (lhs: TruoraException, rhs: TruoraException) -> Bool {
        switch (lhs, rhs) {
        case (.validationApi(let lhsError), .validationApi(let rhsError)):
            lhsError == rhsError
        case (.sdk(let lhsError), .sdk(let rhsError)):
            lhsError == rhsError
        case (.network(let lhsMsg, _), .network(let rhsMsg, _)):
            // Compare only message, not underlyingError (which may not be Equatable)
            lhsMsg == rhsMsg
        default:
            false
        }
    }
}
