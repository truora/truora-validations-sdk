//
//  ErrorMapping.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 25/01/26.
//

import Foundation

// MARK: - TruoraAPIError to TruoraException Mapping

extension TruoraAPIError {
    /// Converts API errors to TruoraException.
    func toTruoraException() -> TruoraException {
        switch self {
        case .invalidURL:
            return .sdk(SDKError(type: .invalidFormat, details: "Invalid API URL"))
        case .networkError(let error):
            return .network(message: error.localizedDescription, underlyingError: error)
        case .unauthorized(let body):
            if let body {
                return .sdk(SDKError(type: .invalidApiKey, details: "Unauthorized: \(body)"))
            }
            return .sdk(SDKError(type: .invalidApiKey, details: "Unauthorized - please check your API key"))
        case .serverError(let code, let body):
            if let body {
                return .network(message: "Server error (\(code)): \(body)", underlyingError: nil)
            }
            return .network(message: "Server error (code: \(code)). Please try again later.", underlyingError: nil)
        case .decodingError(let error):
            return .sdk(
                SDKError(
                    type: .internalError,
                    details: "Failed to process server response: \(error.localizedDescription)"
                )
            )
        case .invalidResponse:
            return .network(message: "Invalid response from server", underlyingError: nil)
        }
    }
}

// MARK: - ApiKeyError to TruoraException Mapping

extension ApiKeyError {
    /// Converts API key errors to TruoraException.
    func toTruoraException() -> TruoraException {
        switch self {
        case .invalidJwtFormat:
            return .sdk(SDKError(type: .invalidApiKey, details: "Invalid API key format"))
        case .expiredKey(let expiration):
            let date = Date(timeIntervalSince1970: expiration)
            return .sdk(SDKError(type: .invalidApiKey, details: "API key expired at \(date)"))
        case .invalidKeyType(let keyType):
            return .sdk(SDKError(type: .invalidApiKey, details: "Invalid key type: \(keyType)"))
        case .generationFailed(let reason):
            return .sdk(SDKError(type: .invalidApiKey, details: "API key generation failed: \(reason)"))
        case .missingKeyType:
            return .sdk(SDKError(type: .invalidApiKey, details: "Missing key type in API key"))
        case .missingExpiration:
            return .sdk(SDKError(type: .invalidApiKey, details: "Missing expiration in API key"))
        }
    }
}

// MARK: - LogoDownloaderError to TruoraException Mapping

extension LogoDownloaderError {
    /// Converts logo download errors to TruoraException.
    /// Note: Logo failures are typically non-fatal and can be silently handled.
    func toTruoraException() -> TruoraException {
        switch self {
        case .invalidUrl:
            .sdk(SDKError(type: .invalidConfiguration, details: "Invalid logo URL"))
        case .insecureUrl:
            .sdk(SDKError(type: .invalidConfiguration, details: "Logo URL must use HTTPS"))
        case .invalidResponse:
            .network(message: "Failed to download logo: invalid response", underlyingError: nil)
        case .httpError(let statusCode):
            .network(message: "Failed to download logo: HTTP \(statusCode)", underlyingError: nil)
        case .invalidContentType(let type):
            .sdk(SDKError(type: .invalidConfiguration, details: "Logo URL returned invalid content type: \(type)"))
        case .invalidImageData:
            .sdk(SDKError(type: .invalidConfiguration, details: "Logo URL did not return a valid image"))
        case .sizeExceeded(let maxBytes):
            .sdk(SDKError(type: .invalidRange, details: "Logo exceeds maximum size (\(maxBytes / 1024 / 1024)MB)"))
        case .cancelled:
            .sdk(SDKError(type: .processCancelledByUser, details: nil))
        }
    }
}

// MARK: - CameraError to TruoraException Mapping

#if canImport(TruoraCamera)
import TruoraCamera

extension CameraError {
    /// Converts camera errors to TruoraException.
    func toTruoraException() -> TruoraException {
        switch self {
        case .permissionDenied:
            .sdk(SDKError(type: .cameraPermissionError, details: localizedDescription))
        case .internalError(let message, _),
             .frameDetectionError(let message, _):
            .sdk(SDKError(type: .internalError, details: message))
        case .cameraNotAvailable, .captureSessionError, .exportFailed:
            .sdk(SDKError(type: .internalError, details: localizedDescription))
        }
    }
}
#endif

// MARK: - Generic Error Mapping

extension Error {
    /// Attempts to convert any error to TruoraException.
    /// Falls back to SDK internal error for unknown error types.
    func toTruoraException() -> TruoraException {
        if let truoraException = self as? TruoraException {
            return truoraException
        }
        if let apiError = self as? TruoraAPIError {
            return apiError.toTruoraException()
        }
        if let apiKeyError = self as? ApiKeyError {
            return apiKeyError.toTruoraException()
        }
        if let logoError = self as? LogoDownloaderError {
            return logoError.toTruoraException()
        }
        #if canImport(TruoraCamera)
        if let cameraError = self as? CameraError {
            return cameraError.toTruoraException()
        }
        #endif

        // Handle cancellation
        if self is CancellationError {
            return .sdk(SDKError(type: .processCancelledByUser, details: nil))
        }

        // Fallback
        return .sdk(SDKError(type: .internalError, details: localizedDescription))
    }
}
