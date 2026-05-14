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

/// Camera delegate protocol for receiving camera events.
/// All delegate methods are called on the main thread by the camera implementation.
public protocol CameraDelegate: AnyObject {
    func cameraReady()
    func mediaReady(media: Data)
    func lastFrameCaptured(frameData: Data)
    func reportError(error: CameraError)
    func detectionsReceived(_ results: [DetectionResult])
    /// Called when autocapture becomes unavailable (e.g., ML model failed to load).
    /// The error parameter provides debugging information about the failure cause.
    func autocaptureUnavailable(error: Error?)
}

/// Frame processor protocol for processing camera frames
public protocol FrameProcessor {
    func process(sampleBuffer: CMSampleBuffer)

    /// Callback invoked with inference latency in seconds after each detection.
    /// Set by the host module to feed into the performance advisor's inference tracker.
    var onInferenceLatency: ((TimeInterval) -> Void)? { get set }
}

/// Detection type enum for frame processing
public enum DetectionType {
    case face
    case document
    case none
}

/// Detection category enum with associated type-specific data
public enum DetectionCategory {
    case face(landmarks: VNFaceLandmarks2D?, yaw: Double?)
    case document(scores: [Float]?)
}

/// Lightweight logging protocol for ML model lifecycle events within TruoraCamera.
/// Implemented by the parent module (TruoraValidationsSDK) to bridge to TruoraLogger.
/// All methods are fire-and-forget; implementations should not block.
public protocol MLLifecycleLogger: AnyObject {
    func logModelLoadSucceeded(modelName: String)
    func logModelLoadFailed(modelName: String, errorMessage: String)
    func logModelInitSucceeded(modelName: String)
    func logModelInitFailed(modelName: String, errorMessage: String)
    func logModelPredictionFinished(modelName: String)
    func logModelPredictionFailed(modelName: String, errorMessage: String)
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
