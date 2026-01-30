//
//  VideoCompressorTests.swift
//  TruoraValidationsSDKTests
//
//  Created by Truora on 30/12/25.
//

import AVFoundation
import XCTest
@testable import TruoraCamera

@MainActor final class VideoCompressorTests: XCTestCase {
    func testVideoCompressionPreset_exportPresets() {
        // Test HEVC Highest
        if #available(iOS 11.0, *) {
            XCTAssertEqual(VideoCompressionPreset.hevcHighest.exportPreset, "AVAssetExportPresetHEVCHighestQuality")
        } else {
            XCTAssertEqual(VideoCompressionPreset.hevcHighest.exportPreset, AVAssetExportPresetHighestQuality)
        }

        // Test HEVC 1080p
        if #available(iOS 11.0, *) {
            XCTAssertEqual(VideoCompressionPreset.hevc1080p.exportPreset, "AVAssetExportPresetHEVC1920x1080")
        } else {
            XCTAssertEqual(VideoCompressionPreset.hevc1080p.exportPreset, AVAssetExportPreset1920x1080)
        }

        // Test H.264 720p (HEVC 720p is macOS-only)
        XCTAssertEqual(VideoCompressionPreset.h264720p.exportPreset, AVAssetExportPreset1280x720)

        // Test H.264 540p (HEVC 540p is macOS-only)
        XCTAssertEqual(VideoCompressionPreset.h264540p.exportPreset, AVAssetExportPreset960x540)

        // Test Medium Quality (fallback)
        XCTAssertEqual(VideoCompressionPreset.mediumQuality.exportPreset, AVAssetExportPresetMediumQuality)
    }

    func testVideoCompressionPreset_optimal() {
        let optimal = VideoCompressionPreset.optimal

        // Optimal should be h264720p to match capture resolution
        XCTAssertEqual(optimal, .h264720p)
    }
}
