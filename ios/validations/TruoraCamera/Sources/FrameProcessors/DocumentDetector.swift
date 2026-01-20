//
//  DocumentDetector.swift
//  TruoraCamera
//
//  Created by Sergio Guzmán on 06/01/2026.
//

import Accelerate
import AVFoundation
import CoreImage
import Foundation
@_implementationOnly import TensorFlowLite

enum IDError: Error {
    case modelNotFound(String)
    case invalidInput
    case preprocessingFailed
    case detectionFailed
}

class DocumentDetector {
    private var landmarkerInterpreter: Interpreter?
    private let detectionQueue = DispatchQueue(label: "com.truora.document.detection")

    var onIDDetected: (([DetectionResult]) -> Void)?
    var onError: ((Error) -> Void)?

    private let landmarkerInputWidth = 128
    private let landmarkerInputHeight = 128

    // Preprocessor matching Python ResizePadLayer behavior
    private lazy var preprocessor: ResizePadPreprocessor = .init(
        targetSize: CGSize(width: landmarkerInputWidth, height: landmarkerInputHeight),
        outputDtype: .float32 // Range [0,1] matching Python model
    )

    init() {
        loadModels()
    }

    private func loadModels() {
        do {
            // Load document detection model
            guard let landmarkerPath = Bundle.module.path(forResource: "general_int8", ofType: "tflite") else {
                throw IDError.modelNotFound("general_int8.tflite")
            }

            var landmarkerOptions = Interpreter.Options()

            landmarkerOptions.threadCount = 2
            landmarkerInterpreter = try Interpreter(modelPath: landmarkerPath, options: landmarkerOptions)

            try landmarkerInterpreter?.allocateTensors()
        } catch {
            onError?(error)
        }
    }

    func detectID(in sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            onError?(IDError.invalidInput)
            return
        }

        detectionQueue.async { [weak self] in
            self?.performDetection(on: pixelBuffer)
        }
    }

    private func performDetection(on pixelBuffer: CVPixelBuffer) {
        guard let interpreter = landmarkerInterpreter else {
            return
        }

        do {
            // Rotate image 90° clockwise to correct for back camera's landscape orientation
            // Back camera frames arrive in landscape-right orientation, need to rotate to portrait
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let rotatedImage = ciImage.oriented(.right)

            // Preprocess with aspect-ratio-preserving resize and zero padding
            guard let result = preprocessor.preprocess(ciImage: rotatedImage) else {
                throw IDError.preprocessingFailed
            }

            try interpreter.copy(result.data, toInputAt: 0)
            try interpreter.invoke()

            let detectionResults = try parseLandmarkerOutputs(
                from: interpreter,
                preprocessResult: result
            )

            DispatchQueue.main.async {
                self.onIDDetected?(detectionResults)
            }

        } catch {
            DispatchQueue.main.async {
                self.onError?(error)
            }
        }
    }

    /// Parses model output and converts to CGRect format
    /// - Parameters:
    ///   - interpreter: TFLite interpreter with output tensors
    ///   - preprocessResult: Contains scale and original size (not used since model outputs are pre-normalized)
    /// - Returns: Array of DetectionResult with normalized coordinates [0,1] relative to original image
    private func parseLandmarkerOutputs(
        from interpreter: Interpreter,
        preprocessResult: PreprocessResult
    ) throws -> [DetectionResult] {
        let landmarksOutput = try interpreter.output(at: 0)
        let landmarksData = landmarksOutput.data
        let landmarks = landmarksData.withUnsafeBytes { buffer -> [Float32] in
            Array(buffer.bindMemory(to: Float32.self))
        }

        let tensorSize = 60

        guard landmarks.count >= tensorSize else {
            return []
        }

        // Model outputs normalized coordinates [0,1] in format: (x_min, y_min, x_max, y_max, score_front, score_back)
        // We need to convert from corner format (x_min, y_min, x_max, y_max) to CGRect format (x, y, width, height)
        // where width = x_max - x_min and height = y_max - y_min

        var results: [DetectionResult] = []
        let docAttributesNumber = 6
        for resultIndex in 0 ..< tensorSize / docAttributesNumber {
            let offset = resultIndex * docAttributesNumber

            let xMin = landmarks[offset]
            let yMin = landmarks[offset + 1]
            let xMax = landmarks[offset + 2]
            let yMax = landmarks[offset + 3]

            results.append(DetectionResult(
                category: .document(scores: [landmarks[offset + 4], landmarks[offset + 5]]),
                boundingBox: CGRect(
                    x: CGFloat(xMin),
                    y: CGFloat(yMin),
                    width: CGFloat(xMax - xMin),
                    height: CGFloat(yMax - yMin)
                ),
                confidence: 1.0
            ))
        }

        return results
    }
}
