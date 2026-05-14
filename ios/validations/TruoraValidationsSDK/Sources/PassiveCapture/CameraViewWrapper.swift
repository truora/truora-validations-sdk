//
//  CameraViewWrapper.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 23/01/26.
//

import AVFoundation
import SwiftUI
import TruoraCamera
import UIKit

struct CameraViewWrapper: UIViewRepresentable {
    @ObservedObject var viewModel: PassiveCaptureViewModel

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    func makeUIView(context: Context) -> CameraView {
        let mlLogger: MLLifecycleLogger? = {
            guard let logger = try? TruoraLoggerImplementation.shared else {
                return nil
            }
            return MLLifecycleLoggerAdapter(logger: logger)
        }()
        var processor = FrameProcessorFactory.createProcessor(
            for: .face,
            delegate: context.coordinator,
            logger: mlLogger
        )
        // Wire inference latency tracking if the presenter set a callback
        processor?.onInferenceLatency = context.coordinator.inferenceLatencyCallback
        let cameraView = CameraView(frameProcessor: processor)
        cameraView.backgroundColor = .clear
        cameraView.delegate = context.coordinator
        context.coordinator.cameraView = cameraView
        viewModel.cameraViewDelegate = context.coordinator
        return cameraView
    }

    func updateUIView(_: CameraView, context _: Context) {}

    @MainActor class Coordinator: NSObject, @preconcurrency CameraDelegate, CameraViewDelegate {
        let viewModel: PassiveCaptureViewModel
        weak var cameraView: CameraView?

        /// Callback for inference latency reporting, set by the presenter
        /// to feed into the performance advisor's inference tracker.
        var inferenceLatencyCallback: ((TimeInterval) -> Void)?

        init(viewModel: PassiveCaptureViewModel) {
            self.viewModel = viewModel
        }

        func setupCamera() {
            guard let cameraView else {
                debugLog("⚠️ setupCamera() failed - cameraView is nil")
                viewModel.errorMessage = "Camera view not available. Please restart the validation."
                viewModel.showError = true
                return
            }
            // Passive capture always uses front camera only - camera switching is not supported
            cameraView.startCamera(side: .front, cameraOutputMode: .video)
        }

        func configureSessionPreset(_ preset: AVCaptureSession.Preset) {
            cameraView?.sessionPresetOverride = preset
        }

        func setInferenceLatencyCallback(_ callback: ((TimeInterval) -> Void)?) {
            inferenceLatencyCallback = callback
        }

        func startRecording() {
            guard let cameraView else {
                debugLog("⚠️ CameraViewDelegate: startRecording() called but cameraView is nil")
                viewModel.errorMessage = "Camera not ready to record. Please try again."
                viewModel.showError = true
                return
            }
            cameraView.startRecordingVideo()
        }

        func stopRecording(skipMediaNotification: Bool) {
            guard let cameraView else {
                debugLog("⚠️ CameraViewDelegate: stopRecording() called but cameraView is nil")
                viewModel.errorMessage = "Unable to stop recording. " +
                    "Camera resources may not be released properly."
                viewModel.showError = true
                return
            }
            cameraView.stopVideoRecording(skipMediaNotification: skipMediaNotification)
        }

        func stopCamera() {
            guard let cameraView else {
                debugLog("⚠️ CameraViewDelegate: stopCamera() called but cameraView is nil")
                return
            }
            cameraView.stopCamera()
        }

        func pauseCamera() {
            guard let cameraView else {
                debugLog("⚠️ CameraViewDelegate: pauseCamera() called but cameraView is nil")
                return
            }
            cameraView.pauseCamera()
        }

        func resumeCamera() {
            guard let cameraView else {
                debugLog("⚠️ CameraViewDelegate: resumeCamera() called but cameraView is nil")
                return
            }
            cameraView.resumeCamera()
        }

        func convertVisionBoundingBoxToViewRect(_ visionBox: CGRect) -> CGRect? {
            cameraView?.convertVisionBoundingBoxToViewRect(visionBox)
        }

        func cameraReady() {
            viewModel.cameraReady()
        }

        func mediaReady(media: Data) {
            debugLog("🟢 CameraViewWrapper: Video recording completed, \(media.count) bytes")
            viewModel.videoRecordingCompleted(videoData: media)
        }

        func lastFrameCaptured(frameData: Data) {
            viewModel.lastFrameCaptured(frameData: frameData)
        }

        func reportError(error: CameraError) {
            debugLog("❌ CameraViewWrapper: Camera error: \(error)")

            if case .permissionDenied = error {
                viewModel.cameraPermissionDenied()
            } else {
                let errorMessage = error.localizedDescription
                viewModel.cameraError(errorMessage)
                viewModel.showError("Camera error: \(errorMessage)")
            }
        }

        func detectionsReceived(_ results: [DetectionResult]) {
            viewModel.detectionsReceived(results)
        }

        func autocaptureUnavailable(error: Error?) {
            // Not applicable for face capture - autocapture is always available
            // Face detection uses Vision framework which doesn't require ML model download
            _ = error
        }
    }
}

@MainActor
protocol CameraViewDelegate: AnyObject {
    func setupCamera()
    func configureSessionPreset(_ preset: AVCaptureSession.Preset)
    func setInferenceLatencyCallback(_ callback: ((TimeInterval) -> Void)?)
    func startRecording()
    func stopRecording(skipMediaNotification: Bool)
    func stopCamera()
    func pauseCamera()
    func resumeCamera()
    func convertVisionBoundingBoxToViewRect(_ visionBox: CGRect) -> CGRect?
}
