//
//  VideoCompressor.swift
//  TruoraCamera
//
//  Created by Truora on 30/12/25.
//

import AVFoundation

enum VideoCompressionPreset {
    case hevcHighest // iOS 11.0+ - Best quality HEVC
    case hevc1080p // iOS 11.0+ - 1080p HEVC
    case hevc720p // iOS 11.0+ - 720p HEVC (Matches capture)
    case hevc540p // iOS 14.0+ - 540p HEVC (Ultra-low size)
    case h264Fallback // Fallback for edge cases

    var exportPreset: String {
        switch self {
        case .hevcHighest:
            if #available(iOS 11.0, *) {
                return "AVAssetExportPresetHEVCHighestQuality"
            }
            return AVAssetExportPresetHighestQuality
        case .hevc1080p:
            if #available(iOS 11.0, *) {
                return "AVAssetExportPresetHEVC1920x1080"
            }
            return AVAssetExportPreset1920x1080
        case .hevc720p:
            if #available(iOS 11.0, *) {
                return "AVAssetExportPresetHEVC1280x720"
            }
            return AVAssetExportPreset1280x720
        case .hevc540p:
            if #available(iOS 14.0, *) {
                return "AVAssetExportPresetHEVC960x540"
            } else if #available(iOS 11.0, *) {
                return "AVAssetExportPresetHEVC1280x720"
            }
            return AVAssetExportPreset1280x720
        case .h264Fallback:
            return AVAssetExportPresetMediumQuality
        }
    }

    static var optimal: VideoCompressionPreset {
        // We use 720p as optimal to match the capture resolution (1280x720)
        // while using the modern HEVC codec for maximum compression.
        .hevc720p
    }
}
