//
//  ErrorHelpers.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 22/01/26.
//

import Foundation

/// Helper functions to create standardized errors
enum ErrorHelpers {
    /// Creates a TruoraException.sdk error from SDKErrorType
    /// - Parameters:
    ///   - type: The SDK error type
    ///   - details: Optional additional details
    /// - Returns: A TruoraException.sdk instance
    static func sdkError(type: SDKErrorType, details: String? = nil) -> TruoraException {
        let sdkError = SDKError(type: type, details: details)
        return TruoraException.sdk(sdkError)
    }

    /// Creates a TruoraException.network error
    /// - Parameters:
    ///   - message: Error message
    ///   - underlyingError: Optional underlying error
    /// - Returns: A TruoraException.network instance
    static func networkError(message: String, underlyingError: Error? = nil) -> TruoraException {
        TruoraException.network(message: message, underlyingError: underlyingError)
    }

    /// Creates a TruoraException.validationApi error
    /// - Parameter error: The ValidationApiError
    /// - Returns: A TruoraException.validationApi instance
    static func validationApiError(_ error: ValidationApiError) -> TruoraException {
        TruoraException.validationApi(error)
    }

    /// Gets the error code from a TruoraException
    /// - Parameter exception: The TruoraException
    /// - Returns: The error code, or 0 for Network errors
    static func getErrorCode(_ exception: TruoraException) -> Int {
        exception.code
    }

    /// Gets the error domain from a TruoraException
    /// - Parameter exception: The TruoraException
    /// - Returns: The error domain string
    static func getErrorDomain(_ exception: TruoraException) -> String {
        exception.domain
    }

    /// Converts a TruoraException to TruoraError for callbacks
    /// - Parameters:
    ///   - exception: The TruoraException
    ///   - currentValidation: The current validation type
    /// - Returns: A TruoraError struct for serialization
    static func toTruoraError(
        _ exception: TruoraException,
        currentValidation: String
    ) -> TruoraError {
        let code = exception.code
        let domain = exception.domain
        let message = exception.errorDescription ?? "Unknown error"

        return TruoraError(
            description: message,
            currentValidation: currentValidation,
            type: domain,
            code: String(code)
        )
    }
}
