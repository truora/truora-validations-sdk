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

#if !COCOAPODS
import TensorFlowLite
#endif

// MARK: - Bundle Helper for CocoaPods/SPM/Tuist compatibility

private extension Bundle {
    /// Returns the resource bundle for TruoraCamera.
    /// Works with CocoaPods (resource_bundles), SPM (Bundle.module), and Tuist.
    /// Cached to avoid repeated lookups during frame processing.
    static let truoraCameraResources: Bundle = {
        #if COCOAPODS
        /// CocoaPods - look for the resource bundle by name
        let frameworkBundle = Bundle(for: DocumentDetector.self)
        if let resourceBundleURL = frameworkBundle.url(forResource: "TruoraCameraResources", withExtension: "bundle"),
           let resourceBundle = Bundle(url: resourceBundleURL) {
            return resourceBundle
        }
        // Fallback to framework bundle
        return frameworkBundle
        #else
        // SPM / Tuist / Xcode - uses generated Bundle.module from Derived/Sources
        return Bundle.module
        #endif
    }()
}

enum IDError: Error {
    case modelNotFound(String)
    case modelDownloadFailed(String)
    case modelNotReady
    case invalidInput
    case preprocessingFailed
    case detectionFailed
}

class DocumentDetector {
    private var landmarkerInterpreter: Interpreter?
    private let detectionQueue = DispatchQueue(label: "com.truora.document.detection")

    var onIDDetected: (([DetectionResult]) -> Void)?
    var onError: ((Error) -> Void)?
    var onModelReady: (() -> Void)?

    private let landmarkerInputWidth = 128
    private let landmarkerInputHeight = 128

    /// On-Demand Resource request for the ML model
    /// Kept as instance variable to maintain strong reference during download
    private var modelResourceRequest: NSBundleResourceRequest?

    /// Lock for thread-safe access to isModelLoaded flag
    private let modelLoadedLock = NSLock()

    /// Whether the model has been successfully loaded (protected by modelLoadedLock)
    private var _isModelLoaded = false
    private var isModelLoaded: Bool {
        get {
            modelLoadedLock.lock()
            defer { modelLoadedLock.unlock() }
            return _isModelLoaded
        }
        set {
            modelLoadedLock.lock()
            defer { modelLoadedLock.unlock() }
            _isModelLoaded = newValue
        }
    }

    /// ODR tag for the document detection model (must match Project.swift)
    private static let modelODRTag = "ml-document-model"

    /// Preprocessor matching Python ResizePadLayer behavior
    private lazy var preprocessor: ResizePadPreprocessor = .init(
        targetSize: CGSize(width: landmarkerInputWidth, height: landmarkerInputHeight),
        outputDtype: .float32 // Range [0,1] matching Python model
    )

    init() {
        loadModelWithODR()
    }

    deinit {
        // End accessing ODR resources when detector is deallocated
        modelResourceRequest?.endAccessingResources()
    }

    // MARK: - On-Demand Resource Loading

    /// Loads the ML model using On-Demand Resources
    /// The model will be downloaded if not already cached on device
    private func loadModelWithODR() {
        let tags: Set<String> = [Self.modelODRTag]
        modelResourceRequest = NSBundleResourceRequest(tags: tags)

        // Set loading priority to high since we need it for detection
        modelResourceRequest?.loadingPriority = NSBundleResourceRequestLoadingPriorityUrgent

        modelResourceRequest?.beginAccessingResources { [weak self] error in
            if let error {
                DispatchQueue.main.async {
                    self?.onError?(IDError.modelDownloadFailed(error.localizedDescription))
                }
                return
            }

            // Resources are now available, load the model
            self?.loadModels()
        }
    }

    /// Conditionally accesses ODR resources before loading model
    /// Useful to check if model is already downloaded without triggering download
    func checkModelAvailability(completion: @escaping (Bool) -> Void) {
        let tags: Set<String> = [Self.modelODRTag]
        let request = NSBundleResourceRequest(tags: tags)
        // Capture request strongly in closure to prevent deallocation before completion
        request.conditionallyBeginAccessingResources { available in
            _ = request // Keep request alive until completion handler executes
            completion(available)
        }
    }

    private func loadModels() {
        detectionQueue.async { [weak self] in
            guard let self else { return }

            do {
                // Load document detection model from bundle
                // After ODR download, the resource is available in Bundle.module
                guard let landmarkerPath = Bundle.truoraCameraResources.path(
                    forResource: "general_int8", ofType: "tflite"
                ) else {
                    throw IDError.modelNotFound("general_int8.tflite")
                }

                var landmarkerOptions = Interpreter.Options()
                landmarkerOptions.threadCount = 2
                self.landmarkerInterpreter = try Interpreter(modelPath: landmarkerPath, options: landmarkerOptions)

                try self.landmarkerInterpreter?.allocateTensors()
                self.isModelLoaded = true

                DispatchQueue.main.async {
                    self.onModelReady?()
                }
            } catch {
                DispatchQueue.main.async {
                    self.onError?(error)
                }
            }
        }
    }

    // MARK: - Detection

    func detectID(in sampleBuffer: CMSampleBuffer) {
        guard isModelLoaded else {
            // Model not ready yet - silently skip frame
            // The camera will continue sending frames and we'll process once ready
            return
        }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            DispatchQueue.main.async { [weak self] in
                self?.onError?(IDError.invalidInput)
            }
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
    ///   - preprocessResult: Contains scale and original size for coordinate mapping
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

        // Calculate normalization factors for mapping centered-padded coordinates back to original [0,1]
        // This matches Android's approach in DocumentDetectorImpl.parseResults
        let originalWidth = Float(preprocessResult.originalSize.width)
        let originalHeight = Float(preprocessResult.originalSize.height)

        // Guard against division by zero for invalid image dimensions
        guard originalWidth > 0, originalHeight > 0 else {
            return []
        }

        let maxDim = max(originalWidth, originalHeight)
        let normFactorX = maxDim / originalWidth
        let normFactorY = maxDim / originalHeight

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

            // Map centered-padded coordinates back to original normalized [0..1]
            // Formula: norm_coord = (model_coord - 0.5) * normFactor + 0.5
            let left = (xMin - 0.5) * normFactorX + 0.5
            let top = (yMin - 0.5) * normFactorY + 0.5
            let right = (xMax - 0.5) * normFactorX + 0.5
            let bottom = (yMax - 0.5) * normFactorY + 0.5

            let width = right - left
            let height = bottom - top

            // Skip invalid bounding boxes with non-positive dimensions
            guard width > 0, height > 0 else {
                continue
            }

            results.append(DetectionResult(
                category: .document(scores: [landmarks[offset + 4], landmarks[offset + 5]]),
                boundingBox: CGRect(
                    x: CGFloat(left),
                    y: CGFloat(top),
                    width: CGFloat(width),
                    height: CGFloat(height)
                ),
                confidence: 1.0
            ))
        }

        return results
    }
}
