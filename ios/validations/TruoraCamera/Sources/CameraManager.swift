//
//  CameraManager.swift
//  TruoraCamera
//
//  Created by Laura Donado on 22/10/21.
//

import AVFoundation
import Foundation
import UIKit

public enum CameraSide {
    case front, back
}

public enum CameraOutputMode {
    case image, video
}

class CameraManager: NSObject {
    let focusSquareImageName = "FocusSquare"
    let focusSquareWidth: CGFloat = 100
    let focusAnimationDuration = 0.5
    let focusAnimationDelay = 0.8

    var captureSession: AVCaptureSession?
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    var imageOutput: AVCapturePhotoOutput?
    var videoOutput: AVCaptureMovieFileOutput?
    var videoDataOutput: AVCaptureVideoDataOutput?
    var cameraIsSetup = false
    var skipMediaNotification = false
    private(set) lazy var focusGesture = UITapGestureRecognizer()
    var focusSquare: UIImageView?

    /// Thread-safe access to the last sample buffer.
    /// Access is synchronized via a dedicated serial queue to prevent data races
    /// between the video data output queue and the main thread.
    private let sampleBufferAccessQueue = DispatchQueue(
        label: "com.truora.camera.sampleBufferAccess"
    )
    private var _lastSampleBuffer: CMSampleBuffer?
    var lastSampleBuffer: CMSampleBuffer? {
        get { sampleBufferAccessQueue.sync { _lastSampleBuffer } }
        set { sampleBufferAccessQueue.sync { _lastSampleBuffer = newValue } }
    }

    let videoDataOutputQueue = DispatchQueue(label: "com.truora.camera.videoDataOutput")

    /// Cached date formatter for performance
    static let fileDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy_MM_dd_HH_mm_ss_SSS"
        return formatter
    }()

    weak var delegate: CameraDelegate?

    var cameraOutputMode: CameraOutputMode = .image
    var cameraSide: CameraSide = .back {
        didSet {
            if cameraIsSetup, cameraSide != oldValue {
                updateCameraSide()
            }
        }
    }

    private var frameProcessor: FrameProcessor?
    private var uiTestTimer: Timer?
    #if DEBUG
    private var uiTestDetector: CoreMLFaceDetector?
    #endif

    init(frameProcessor: FrameProcessor? = nil) {
        self.frameProcessor = frameProcessor
        super.init()
        let focusSquareImage = UIImage(
            named: focusSquareImageName,
            in: Bundle(for: CameraManager.self),
            compatibleWith: nil
        )
        focusSquare = UIImageView(image: focusSquareImage)

        #if DEBUG
        if let mode = UITestMode.current(), mode != .realCamera {
            startUITestMock(mode: mode)
        }
        // For .realCamera mode, we don't mock - the real camera will be used
        #endif
    }

    deinit {
        stopUITestMock()
    }

    /// Stops the UI test mock timer and cleans up resources.
    /// Call this when the camera is stopped or deinitialized.
    func stopUITestMock() {
        uiTestTimer?.invalidate()
        uiTestTimer = nil
        #if DEBUG
        uiTestDetector?.onFacesDetected = nil
        uiTestDetector?.onError = nil
        uiTestDetector = nil
        #endif
    }

    #if DEBUG
    /// UI Test modes for Firebase Test Lab and local testing
    enum UITestMode {
        /// Mock mode: Returns hardcoded detection results based on test image name
        /// Fast and reliable for UI flow testing
        case mock

        /// Real ML mode: Loads test image from bundle and runs through CoreML/Vision
        /// Tests actual ML model inference on device hardware
        case realML

        /// Real camera mode: Uses actual AVCaptureSession with CoreML processing
        /// Tests full camera + ML pipeline on Firebase Test Lab devices
        case realCamera

        static func current() -> UITestMode? {
            let args = ProcessInfo.processInfo.arguments
            guard args.contains("--uitesting") else { return nil }
            if args.contains("--real-camera") { return .realCamera }
            if args.contains("--real-ml") { return .realML }
            return .mock
        }
    }

    private func startUITestMock(mode: UITestMode) {
        // Set up detector for real ML mode
        if mode == .realML {
            uiTestDetector = CoreMLFaceDetector()
            uiTestDetector?.onFacesDetected = { [weak self] results in
                self?.delegate?.detectionsReceived(results)
            }
            uiTestDetector?.onError = { [weak self] error in
                print("⚠️ CameraManager: Real ML detection error: \(error)")
                self?.delegate?.reportError(error: .frameDetectionError(error.localizedDescription))
            }
        }

        uiTestTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.processUITestFrame(mode: mode)
        }
    }

    private func processUITestFrame(mode: UITestMode) {
        let testImageName = ProcessInfo.processInfo.arguments
            .first { $0.hasPrefix("--test-image=") }?
            .replacingOccurrences(of: "--test-image=", with: "") ?? "test_face_none"

        switch mode {
        case .mock:
            processMockFrame(testImageName: testImageName)

        case .realML:
            processRealMLFrame(testImageName: testImageName)

        case .realCamera:
            // Real camera mode doesn't use the timer - actual capture session handles frames
            break
        }
    }

    private func processMockFrame(testImageName: String) {
        // Return hardcoded detection results based on the image name
        // Fast and reliable for UI flow testing
        let results: [DetectionResult] = switch testImageName {
        case "test_face_single":
            [DetectionResult(category: .face(landmarks: nil), boundingBox: .zero, confidence: 0.95)]
        case "test_face_multiple":
            [
                DetectionResult(category: .face(landmarks: nil), boundingBox: .zero, confidence: 0.9),
                DetectionResult(category: .face(landmarks: nil), boundingBox: .zero, confidence: 0.8)
            ]
        default:
            []
        }

        DispatchQueue.main.async {
            self.delegate?.detectionsReceived(results)
        }
    }

    private func processRealMLFrame(testImageName: String) {
        // Load actual test image from app bundle and run through CoreML
        // This tests real Vision/CoreML inference on device hardware

        // Try multiple loading strategies since we're in a framework but
        // the images are in the app bundle
        let image: UIImage? = loadTestImage(named: testImageName)

        guard let image else {
            // Image not found - log error and report empty detection
            print("⚠️ CameraManager: Failed to load test image '\(testImageName)' from app bundle")
            DispatchQueue.main.async {
                self.delegate?.detectionsReceived([])
            }
            return
        }

        uiTestDetector?.detectFaces(in: image)
    }

    private func loadTestImage(named name: String) -> UIImage? {
        // Strategy 1: Try Bundle.main (app bundle) with UIImage(named:)
        if let image = UIImage(named: name) {
            return image
        }

        // Strategy 2: Try direct path in main bundle with various extensions
        let extensions = ["jpg", "jpeg", "png"]
        for ext in extensions {
            if let path = Bundle.main.path(forResource: name, ofType: ext),
               let image = UIImage(contentsOfFile: path) {
                return image
            }
        }

        // Strategy 3: Search in TestImages subdirectory
        for ext in extensions {
            if let path = Bundle.main.path(forResource: name, ofType: ext, inDirectory: "TestImages"),
               let image = UIImage(contentsOfFile: path) {
                return image
            }
        }

        return nil
    }
    #endif
}

// MARK: AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        lastSampleBuffer = sampleBuffer
        frameProcessor?.process(sampleBuffer: sampleBuffer)
    }
}
