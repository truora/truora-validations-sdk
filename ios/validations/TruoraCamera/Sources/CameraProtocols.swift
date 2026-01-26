//
//  CameraProtocols.swift
//  TruoraCamera
//
//  Created by Adriana Pineda on 7/15/21.
//

import AVFoundation
import CoreGraphics
import Foundation
import Vision

public protocol CameraDelegate: AnyObject {
    func cameraReady()
    func mediaReady(media: Data)
    func lastFrameCaptured(frameData: Data)
    func reportError(error: CameraError)
    func detectionsReceived(_ results: [DetectionResult])
}

/// Frame processor protocol for processing camera frames
public protocol FrameProcessor {
    func process(sampleBuffer: CMSampleBuffer)
}

/// Detection type enum for frame processing
public enum DetectionType {
    case face
    case document
    case none
}

/// Detection category enum with associated type-specific data
public enum DetectionCategory {
    case face(landmarks: VNFaceLandmarks2D?)
    case document(scores: [Float]?)
}

/// Unified detection result structure for all detection types
public struct DetectionResult {
    public let category: DetectionCategory
    public let boundingBox: CGRect
    public let confidence: Float

    public init(category: DetectionCategory, boundingBox: CGRect, confidence: Float) {
        self.category = category
        self.boundingBox = boundingBox
        self.confidence = confidence
    }
}
