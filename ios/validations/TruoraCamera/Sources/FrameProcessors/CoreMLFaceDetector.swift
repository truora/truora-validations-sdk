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
    private let confidenceThreshold: Float = 0.5 /// only for testing purpose

    var onFacesDetected: (([DetectionResult]) -> Void)?

    var onError: ((Error) -> Void)?

    init() {
        print("CoreML Face Detector initialized")
    }

    /// Detect faces in a video buffer
    func detectFaces(in sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            onError?(CoreMLFaceDetectionError.invalidInput)

            return
        }

        let request = VNDetectFaceRectanglesRequest { [weak self] request, error in
            if let error {
                self?.onError?(error)

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

        /// Configure request for better performance
        if #available(iOS 15.0, *) {
            request.revision = VNDetectFaceRectanglesRequestRevision3
        } else if #available(iOS 14.0, *) {
            request.revision = VNDetectFaceRectanglesRequestRevision2
        }

        /// iOS 11-13 uses default revision automatically

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])

        do {
            try handler.perform([request])
        } catch {
            onError?(error)
        }
    }

    /// Detect faces in a image
    func detectFaces(in image: UIImage) {
        guard let cgImage = image.cgImage else {
            onError?(CoreMLFaceDetectionError.invalidInput)

            return
        }

        let request = VNDetectFaceRectanglesRequest { [weak self] request, error in
            if let error {
                self?.onError?(error)

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

        if #available(iOS 15.0, *) {
            request.revision = VNDetectFaceRectanglesRequestRevision3
        } else if #available(iOS 14.0, *) {
            request.revision = VNDetectFaceRectanglesRequestRevision2
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
        } catch {
            onError?(error)
        }
    }
}

/// Error enum for CoreML face detection
enum CoreMLFaceDetectionError: Error {
    case invalidInput
    case detectionFailed
}
