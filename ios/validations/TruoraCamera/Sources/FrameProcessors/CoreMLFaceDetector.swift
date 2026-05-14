//
//  CoreMLFaceDetector.swift
//  TruoraFaceDetection
//
//  Created by Brayan Escobar on 10/14/25.
//

import AVFoundation
import CoreML
import Foundation
import UIKit
import Vision

/// CoreML face detector using Vision Framework
class CoreMLFaceDetector {
    private let confidenceThreshold: Float = 0.5 // only for testing purpose
    private weak var logger: MLLifecycleLogger?
    private var hasLoggedFirstPrediction = false
    private let predictionLogLock = NSLock()

    var onFacesDetected: (([DetectionResult]) -> Void)?

    var onError: ((Error) -> Void)?

    init(logger: MLLifecycleLogger? = nil) {
        self.logger = logger
        // Vision framework is bundled with iOS — no model file to load.
        // Log init succeeded since the detector is ready immediately.
        logger?.logModelInitSucceeded(modelName: "face_detector")
        debugLog("CoreML Face Detector initialized")
    }

    /// Detect faces in a video buffer
    func detectFaces(in sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            DispatchQueue.main.async { [weak self] in
                self?.onError?(CoreMLFaceDetectionError.invalidInput)
            }
            return
        }

        let request = VNDetectFaceRectanglesRequest { [weak self] request, error in
            if let error {
                self?.logger?.logModelPredictionFailed(
                    modelName: "face_detector",
                    errorMessage: error.localizedDescription
                )
                DispatchQueue.main.async {
                    self?.onError?(error)
                }
                return
            }

            guard let observations = request.results as? [VNFaceObservation] else {
                return
            }

            let faces = observations.compactMap { observation -> DetectionResult? in
                guard observation.confidence >= (self?.confidenceThreshold ?? 0.5) else {
                    return nil
                }

                return DetectionResult(
                    category: .face(landmarks: observation.landmarks, yaw: observation.yaw?.doubleValue),
                    boundingBox: observation.boundingBox,
                    confidence: observation.confidence
                )
            }

            if !faces.isEmpty {
                self?.predictionLogLock.withLock {
                    guard self?.hasLoggedFirstPrediction == false else { return }
                    self?.hasLoggedFirstPrediction = true
                    self?.logger?.logModelPredictionFinished(modelName: "face_detector")
                }
            }

            DispatchQueue.main.async {
                self?.onFacesDetected?(faces)
            }
        }

        // Configure request for better performance
        if #available(iOS 15.0, *) {
            request.revision = VNDetectFaceRectanglesRequestRevision3
        } else if #available(iOS 14.0, *) {
            request.revision = VNDetectFaceRectanglesRequestRevision2
        }

        // iOS 11-13 uses default revision automatically

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])

        do {
            try handler.perform([request])
        } catch {
            logger?.logModelPredictionFailed(
                modelName: "face_detector",
                errorMessage: error.localizedDescription
            )
            DispatchQueue.main.async { [weak self] in
                self?.onError?(error)
            }
        }
    }

    /// Detect faces in a image
    func detectFaces(in image: UIImage) {
        guard let cgImage = image.cgImage else {
            debugLog("❌ CoreMLFaceDetector: Failed to get cgImage from UIImage")
            DispatchQueue.main.async { [weak self] in
                self?.onError?(CoreMLFaceDetectionError.invalidInput)
            }
            return
        }

        let request = createFaceDetectionRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
        } catch {
            debugLog("❌ CoreMLFaceDetector: Error performing face detection: \(error)")
            DispatchQueue.main.async { [weak self] in
                self?.onError?(error)
            }
        }
    }

    private func createFaceDetectionRequest() -> VNDetectFaceRectanglesRequest {
        let request = VNDetectFaceRectanglesRequest { [weak self] request, error in
            self?.handleFaceDetectionResult(request: request, error: error)
        }

        if #available(iOS 15.0, *) {
            request.revision = VNDetectFaceRectanglesRequestRevision3
        } else if #available(iOS 14.0, *) {
            request.revision = VNDetectFaceRectanglesRequestRevision2
        }

        return request
    }

    private func handleFaceDetectionResult(request: VNRequest, error: Error?) {
        if let error {
            debugLog("❌ CoreMLFaceDetector: Detection error: \(error)")
            DispatchQueue.main.async { [weak self] in
                self?.onError?(error)
            }
            return
        }

        guard let observations = request.results as? [VNFaceObservation] else {
            DispatchQueue.main.async { [weak self] in
                self?.onFacesDetected?([])
            }
            return
        }

        let faces = observations.compactMap { observation -> DetectionResult? in
            guard observation.confidence >= confidenceThreshold else {
                return nil
            }

            return DetectionResult(
                category: .face(landmarks: observation.landmarks, yaw: observation.yaw?.doubleValue),
                boundingBox: observation.boundingBox,
                confidence: observation.confidence
            )
        }

        DispatchQueue.main.async { [weak self] in
            self?.onFacesDetected?(faces)
        }
    }
}

/// Error enum for CoreML face detection
enum CoreMLFaceDetectionError: Error {
    case invalidInput
    case detectionFailed
}
