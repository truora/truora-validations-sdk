//
//  VideoCompressorTests.swift
//  TruoraValidationsSDKTests
//
//  Created by Truora on 30/12/25.
//

import AVFoundation
import XCTest
@testable import TruoraCamera

final class VideoCompressorTests: XCTestCase {
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

        // Test HEVC 720p
        if #available(iOS 11.0, *) {
            XCTAssertEqual(VideoCompressionPreset.hevc720p.exportPreset, "AVAssetExportPresetHEVC1280x720")
        } else {
            XCTAssertEqual(VideoCompressionPreset.hevc720p.exportPreset, AVAssetExportPreset1280x720)
        }

        // Test HEVC 540p
        if #available(iOS 14.0, *) {
            XCTAssertEqual(VideoCompressionPreset.hevc540p.exportPreset, "AVAssetExportPresetHEVC960x540")
        } else if #available(iOS 11.0, *) {
            XCTAssertEqual(VideoCompressionPreset.hevc540p.exportPreset, "AVAssetExportPresetHEVC1280x720")
        } else {
            XCTAssertEqual(VideoCompressionPreset.hevc540p.exportPreset, AVAssetExportPreset1280x720)
        }

        // Test H264 Fallback
        XCTAssertEqual(VideoCompressionPreset.h264Fallback.exportPreset, AVAssetExportPresetMediumQuality)
    }

    func testVideoCompressionPreset_optimal() {
        let optimal = VideoCompressionPreset.optimal

        // Optimal should always be hevc720p to match capture resolution
        XCTAssertEqual(optimal, .hevc720p)
    }
}
