//
//  FaceFrameProcessor.swift
//  TruoraCamera
//
//  Created by Brayan Escobar on 11/26/25.
//

import AVFoundation
import Foundation

/// Face frame processor that wraps CoreMLFaceDetector and forwards results to delegate
class FaceFrameProcessor: FrameProcessor {
    private let detector = CoreMLFaceDetector()
    private weak var delegate: CameraDelegate?

    init(delegate: CameraDelegate?) {
        self.delegate = delegate
        setupDetector()
    }

    func process(sampleBuffer: CMSampleBuffer) {
        detector.detectFaces(in: sampleBuffer)
    }

    private func setupDetector() {
        detector.onFacesDetected = { [weak self] detectionResults in
            self?.delegate?.detectionsReceived(detectionResults)
        }

        detector.onError = { [weak self] error in
            let cameraError = CameraError.frameDetectionError(
                error.localizedDescription
            )

            self?.delegate?.reportError(error: cameraError)
        }
    }
}
