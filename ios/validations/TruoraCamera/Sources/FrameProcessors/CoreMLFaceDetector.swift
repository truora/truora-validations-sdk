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

    var onFacesDetected: (([DetectionResult]) -> Void)?

    var onError: ((Error) -> Void)?

    init() {
        #if DEBUG
        print("CoreML Face Detector initialized")
        #endif
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
                    category: .face(landmarks: observation.landmarks),
                    boundingBox: observation.boundingBox,
                    confidence: observation.confidence
                )
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
            DispatchQueue.main.async { [weak self] in
                self?.onError?(error)
            }
        }
    }

    /// Detect faces in a image
    func detectFaces(in image: UIImage) {
        guard let cgImage = image.cgImage else {
            #if DEBUG
            print("❌ CoreMLFaceDetector: Failed to get cgImage from UIImage")
            #endif
            DispatchQueue.main.async { [weak self] in
                self?.onError?(CoreMLFaceDetectionError.invalidInput)
            }
            return
        }

        #if DEBUG
        print("🔬 CoreMLFaceDetector: Processing image \(cgImage.width)x\(cgImage.height)")
        #endif

        let request = createFaceDetectionRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
        } catch {
            #if DEBUG
            print("❌ CoreMLFaceDetector: Error performing face detection: \(error)")
            #endif
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
            #if DEBUG
            print("❌ CoreMLFaceDetector: Detection error: \(error)")
            #endif
            DispatchQueue.main.async { [weak self] in
                self?.onError?(error)
            }
            return
        }

        guard let observations = request.results as? [VNFaceObservation] else {
            #if DEBUG
            print("⚠️ CoreMLFaceDetector: No observations returned")
            #endif
            DispatchQueue.main.async { [weak self] in
                self?.onFacesDetected?([])
            }
            return
        }

        #if DEBUG
        print("🔬 CoreMLFaceDetector: Found \(observations.count) face observations")
        #endif

        let faces = observations.compactMap { observation -> DetectionResult? in
            guard observation.confidence >= confidenceThreshold else {
                return nil
            }

            return DetectionResult(
                category: .face(landmarks: observation.landmarks),
                boundingBox: observation.boundingBox,
                confidence: observation.confidence
            )
        }

        #if DEBUG
        print("🔬 CoreMLFaceDetector: Returning \(faces.count) faces above threshold")
        #endif

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
