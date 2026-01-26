//
//  CameraError.swift
//  TruoraCamera
//
//  Created by Truora on 30/10/25.
//

import Foundation

public enum CameraError: Error {
    case internalError(String)
    case frameDetectionError(String)
    case cameraNotAvailable
    case permissionDenied
    case captureSessionError

    public var localizedDescription: String {
        switch self {
        case .internalError(let message):
            message
        case .frameDetectionError(let message):
            "Frame detection error \(message)"
        case .cameraNotAvailable:
            "Camera not available"
        case .permissionDenied:
            "Camera permission denied"
        case .captureSessionError:
            "Capture session error"
        }
    }
}
