//
//  ValidationError.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 30/10/25.
//

import Foundation

public enum ValidationError: Error, Equatable {
    case invalidConfiguration(String)
    case apiError(String)
    case networkError(String)
    case cancelled
    case cameraError(String)
    case internalError(String)
    case uploadFailed(String)
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
        }
    }
}
