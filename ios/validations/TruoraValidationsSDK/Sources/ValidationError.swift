//
//  ValidationError.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 30/10/25.
//

import Foundation

/// Legacy error enum - prefer using TruoraException directly
public enum ValidationError: Error, Equatable {
    case invalidConfiguration(String)
    case apiError(String)
    case networkError(String)
    case cancelled
    case cameraError(String)
    case internalError(String)
    case uploadFailed(String)
    /// API key is invalid, expired, or could not be resolved
    case invalidApiKey(String)
}

extension ValidationError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidConfiguration(let message):
            "Invalid configuration: \(message)"
        case .apiError(let message):
            "API error: \(message)"
        case .networkError(let message):
            "Network error: \(message)"
        case .cancelled:
            "Validation cancelled"
        case .cameraError(let message):
            "Camera error: \(message)"
        case .internalError(let message):
            "Internal error: \(message)"
        case .uploadFailed(let message):
            "Upload failed: \(message)"
        case .invalidApiKey(let message):
            "Invalid API key: \(message)"
        }
    }
}
