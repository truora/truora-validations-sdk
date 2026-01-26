//
//  DocumentFrameProcessor.swift
//  TruoraCamera
//
//  Created by Sergio Guzmán on 06/01/26.
//

import AVFoundation
import Foundation

/// Document frame processor that wraps DocumentDetector id detection model and forwards results to delegate
class DocumentFrameProcessor: FrameProcessor {
    private let detector = DocumentDetector()
    private weak var delegate: CameraDelegate?

    init(delegate: CameraDelegate?) {
        self.delegate = delegate
        setupDetector()
    }

    func process(sampleBuffer: CMSampleBuffer) {
        detector.detectID(in: sampleBuffer)
    }

    private func setupDetector() {
        detector.onIDDetected = { [weak self] detectionResults in
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
