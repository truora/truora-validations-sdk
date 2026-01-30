//
//  VideoCompressor.swift
//  TruoraCamera
//
//  Created by Truora on 30/12/25.
//

import AVFoundation

/// Video compression presets for iOS devices.
/// Uses HEVC where available for better compression, with H.264 fallbacks.
/// Note: Resolution-specific HEVC presets (720p, 540p) are macOS-only;
/// on iOS we use quality presets or H.264 resolution presets.
enum VideoCompressionPreset {
    /// Best quality HEVC (iOS 11.0+)
    case hevcHighest
    /// 1080p HEVC (iOS 11.0+)
    case hevc1080p
    /// 720p H.264 - matches capture resolution
    case h264720p
    /// 540p H.264 for smaller size
    case h264540p
    /// Medium quality for smallest file size
    case mediumQuality

    /// The AVAssetExportSession preset string for this compression level.
    /// Uses SDK constants instead of string literals for type safety.
    var exportPreset: String {
        switch self {
        case .hevcHighest:
            if #available(iOS 11.0, *) {
                return AVAssetExportPresetHEVCHighestQuality
            }
            return AVAssetExportPresetHighestQuality

        case .hevc1080p:
            if #available(iOS 11.0, *) {
                return AVAssetExportPresetHEVC1920x1080
            }
            return AVAssetExportPreset1920x1080

        case .h264720p:
            return AVAssetExportPreset1280x720

        case .h264540p:
            return AVAssetExportPreset960x540

        case .mediumQuality:
            return AVAssetExportPresetMediumQuality
        }
    }

    /// The optimal preset for face validation videos.
    /// Uses 720p to match the capture resolution (1280x720).
    /// While H.264 has less compression than HEVC, 720p provides
    /// good balance of quality and file size for validation.
    static var optimal: VideoCompressionPreset {
        .h264720p
    }
}
