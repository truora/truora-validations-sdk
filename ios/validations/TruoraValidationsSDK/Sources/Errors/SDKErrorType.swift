//
//  SDKErrorType.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 22/01/26.
//

import Foundation

/// Enum defining SDK error types
/// These errors occur due to SDK internal issues, misconfiguration, or platform-specific problems
///
/// Error code ranges:
/// - 20001-20008: Authentication and API key errors
/// - 20009-20016: Process and validation errors
/// - 20017-20026: Configuration and state errors
/// - 20500+: Internal/system errors
public enum SDKErrorType: Int, CaseIterable {
    /// Authentication and API key errors (20001-20008)
    case apiKeyMissing = 20001

    /// Process and validation errors (20009-20016)
    case validationError = 20009
    case processCancelledByUser = 20010
    case cameraPermissionError = 20011
    case invalidFileUploadLink = 20012
    case processInterrupted = 20013
    case missingModule = 20014
    case identityProcessResultsTimedOut = 20016

    /// Configuration and state errors (20017-20026)
    case invalidApiKey = 20017
    case missingValidationsClient = 20018
    case invalidAccountId = 20019
    case nullParameter = 20020
    case invalidRange = 20021
    case invalidFormat = 20022
    case invalidState = 20023
    case invalidConfiguration = 20024
    case networkError = 20025
    case uploadFailed = 20026

    /// Internal/system errors (20500+)
    case internalError = 20500

    /// Human-readable error message for this error type
    public var message: String {
        switch self {
        // Authentication and API key errors
        case .apiKeyMissing:
            "API Key is missing"
        // Process and validation errors
        case .validationError:
            "Validation failed"
        case .processCancelledByUser:
            "Process cancelled by the user"
        case .cameraPermissionError:
            "Camera permission denied, process cannot continue"
        case .invalidFileUploadLink:
            "File upload link is invalid"
        case .processInterrupted:
            "Process was interrupted. Please try again"
        case .missingModule:
            "Missing module"
        case .identityProcessResultsTimedOut:
            "Identity process results timed out"
        // Configuration and state errors
        case .invalidApiKey:
            "Invalid API Key sent"
        case .missingValidationsClient:
            "Missing validations client"
        case .invalidAccountId:
            "Invalid account id"
        case .nullParameter:
            "Required parameter is null or empty"
        case .invalidRange:
            "Parameter value is out of valid range"
        case .invalidFormat:
            "Parameter format is invalid"
        case .invalidState:
            "Operation cannot be performed in current state"
        case .invalidConfiguration:
            "Invalid configuration"
        case .networkError:
            "Network connection failed"
        case .uploadFailed:
            "File upload failed"
        // Internal/system errors
        case .internalError:
            "Unexpected error"
        }
    }
}
