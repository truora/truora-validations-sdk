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
    /// Guards the once-per-session `face_detection_inference_failed` log.
    private var hasLoggedInferenceFailure = false

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

        let request = createFaceDetectionRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])

        do {
            try handler.perform([request])
        } catch {
            reportInferenceFailure(error)
        }
    }

    /// Logs prediction failure plus the once-per-session inference failure event, then
    /// forwards the error to `onError`. Shared by the request-setup catch and the request
    /// completion handler so both paths produce consistent telemetry.
    private func reportInferenceFailure(_ error: Error) {
        logger?.logModelPredictionFailed(
            modelName: "face_detector",
            errorMessage: error.localizedDescription
        )
        // Guarded by predictionLogLock — reportInferenceFailure is called from both the Vision
        // completion handler (background queue) and detectFaces's catch block.
        predictionLogLock.withLock {
            guard !hasLoggedInferenceFailure else { return }
            hasLoggedInferenceFailure = true
            logger?.logFaceDetectionInferenceFailed(errorMessage: error.localizedDescription)
        }
        DispatchQueue.main.async { [weak self] in
            self?.onError?(error)
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

    private func createFaceDetectionRequest() -> VNDetectFaceLandmarksRequest {
        let request = VNDetectFaceLandmarksRequest { [weak self] request, error in
            self?.handleFaceDetectionResult(request: request, error: error)
        }

        // Use landmark revisions so nose/eye regions are populated (available since iOS 11).
        if #available(iOS 15.0, *) {
            request.revision = VNDetectFaceLandmarksRequestRevision3
        } else if #available(iOS 14.0, *) {
            request.revision = VNDetectFaceLandmarksRequestRevision2
        }

        return request
    }

    private func handleFaceDetectionResult(request: VNRequest, error: Error?) {
        if let error {
            reportInferenceFailure(error)
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

        if !faces.isEmpty {
            predictionLogLock.withLock {
                guard !hasLoggedFirstPrediction else { return }
                hasLoggedFirstPrediction = true
                logger?.logModelPredictionFinished(modelName: "face_detector")
            }
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
