//
//  CameraError.swift
//  TruoraCamera
//
//  Created by Truora on 30/10/25.
//

import AVFoundation
import Foundation

/// Errors that can occur during camera operations.
/// Conforms to LocalizedError for better error messages in UI.
public enum CameraError: Error, LocalizedError {
    /// Internal error with descriptive message and optional underlying cause.
    case internalError(String, underlyingError: Error? = nil)

    /// Frame detection/processing error with descriptive message.
    case frameDetectionError(String, underlyingError: Error? = nil)

    /// Camera hardware not available for the requested position.
    case cameraNotAvailable(position: CameraSide? = nil)

    /// Camera permission was denied by the user.
    case permissionDenied(status: AVAuthorizationStatus? = nil)

    /// Capture session error with reason.
    case captureSessionError(reason: String? = nil)

    /// Video export failed with status and optional error.
    case exportFailed(status: AVAssetExportSession.Status? = nil, error: Error? = nil)

    // MARK: - LocalizedError Conformance

    public var errorDescription: String? {
        switch self {
        case .internalError(let message, _):
            return "Internal error: \(message)"
        case .frameDetectionError(let message, _):
            return "Frame detection error: \(message)"
        case .cameraNotAvailable(let position):
            if let position {
                return "\(position == .front ? "Front" : "Back") camera not available"
            }
            return "Camera not available"
        case .permissionDenied(let status):
            if let status {
                return "Camera permission denied (status: \(status.rawValue))"
            }
            return "Camera permission denied"
        case .captureSessionError(let reason):
            if let reason {
                return "Capture session error: \(reason)"
            }
            return "Capture session error"
        case .exportFailed(let status, _):
            if let status {
                return "Video export failed (status: \(status.rawValue))"
            }
            return "Video export failed"
        }
    }

    public var failureReason: String? {
        switch self {
        case .internalError(_, let underlyingError),
             .frameDetectionError(_, let underlyingError),
             .exportFailed(_, let underlyingError):
            underlyingError?.localizedDescription
        default:
            nil
        }
    }

    // MARK: - Backward Compatibility

    /// Provides backward-compatible localized description.
    /// - Note: Prefer using errorDescription from LocalizedError conformance.
    public var localizedDescription: String {
        errorDescription ?? "Unknown camera error"
    }
}
