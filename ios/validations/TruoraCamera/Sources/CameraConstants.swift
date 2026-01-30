//
//  CameraConstants.swift
//  TruoraCamera
//
//  Created by Truora on 25/01/26.
//

import AVFoundation
import CoreGraphics
import Foundation

/// Centralized constants for the TruoraCamera module.
/// Consolidates magic numbers and configuration values for better maintainability.
public enum CameraConstants {
    // MARK: - Connection & Retry

    /// Maximum number of attempts to wait for video connection to become ready.
    public static let maxConnectionAttempts = 30

    /// Delay in seconds between connection retry attempts.
    public static let connectionRetryDelay: TimeInterval = 0.2

    // MARK: - Focus Animation

    /// Duration of focus animation in seconds.
    public static let focusAnimationDuration: TimeInterval = 0.5

    /// Delay before hiding focus indicator after animation.
    public static let focusAnimationDelay: TimeInterval = 0.8

    /// Width/height of the focus square indicator in points.
    public static let focusSquareWidth: CGFloat = 100

    // MARK: - Image Processing

    /// Maximum dimension (width or height) for compressed images.
    public static let maxImageSize: CGFloat = 1024

    /// JPEG compression quality (0.0 to 1.0).
    public static let jpegCompressionQuality: CGFloat = 0.85

    // MARK: - Recording

    /// Countdown seconds before recording starts.
    public static let recordingCountdownSeconds = 3

    // MARK: - Detection

    /// Number of consecutive positive detections required to trigger face detected state.
    public static let faceDetectionThreshold = 3

    /// Number of consecutive negative detections required to trigger face lost state.
    public static let faceLostThreshold = 5

    // MARK: - Export Presets

    /// Returns the best available HEVC export preset for the device.
    /// Falls back to H.264 if HEVC is not available.
    public static var bestHEVCExportPreset: String {
        if #available(iOS 11.0, *) {
            return AVAssetExportPresetHEVCHighestQuality
        }
        return AVAssetExportPresetHighestQuality
    }

    /// Returns the best available 1080p HEVC preset.
    /// Note: Resolution-specific HEVC presets (720p, 540p) are macOS-only.
    /// On iOS, we use 1080p HEVC or the quality presets.
    public static var hevc1080pPreset: String {
        if #available(iOS 11.0, *) {
            return AVAssetExportPresetHEVC1920x1080
        }
        return AVAssetExportPreset1920x1080
    }

    /// Returns the 720p H.264 preset.
    /// Note: HEVC 720p preset is macOS-only.
    public static var h264720pPreset: String {
        AVAssetExportPreset1280x720
    }

    /// Returns the 540p H.264 preset.
    /// Note: HEVC 540p preset is macOS-only.
    public static var h264540pPreset: String {
        AVAssetExportPreset960x540
    }

    /// Returns the medium quality preset for smaller file sizes.
    public static var mediumQualityPreset: String {
        AVAssetExportPresetMediumQuality
    }
}
