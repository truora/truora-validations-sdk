//
//  CameraManager+Control.swift
//  TruoraCamera
//
//  Created by Truora on 21/11/25.
//

import AVFoundation
import UIKit

extension CameraManager {
    func isSessionRunning() -> Bool {
        captureSession?.isRunning ?? false
    }

    /// Pauses the camera session without tearing down.
    /// The preview layer freezes on the last frame, preserving the visual state.
    /// Use this during upload to save resources while keeping the UI intact.
    func pauseCamera() {
        captureSession?.stopRunning()
    }

    func stopCamera() {
        pauseCamera()
        cleanupGestureRecognizers()

        // Remove preview layer from view
        videoPreviewLayer?.removeFromSuperlayer()
        videoPreviewLayer = nil

        // Clean up session and outputs
        if let session = captureSession {
            for input in session.inputs {
                session.removeInput(input)
            }
            for output in session.outputs {
                session.removeOutput(output)
            }
        }
        captureSession = nil
        videoOutput = nil
        videoDataOutput = nil
        imageOutput = nil
        lastSampleBuffer = nil

        cameraIsSetup = false
        // Note: Don't reset skipMediaNotification here - let it survive for async video completion callback
        // It will be reset in setupCamera() when starting fresh
    }

    func takePicture(delegate: AVCapturePhotoCaptureDelegate) {
        guard cameraOutputMode != .video else {
            let cameraError = CameraError.internalError("Wrong capture session output")
            self.delegate?.reportError(error: cameraError)
            return
        }

        let photoSettings = AVCapturePhotoSettings()

        guard let photoPreviewType = photoSettings.availablePreviewPhotoPixelFormatTypes.first else { return }

        photoSettings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: photoPreviewType]

        imageOutput?.capturePhoto(with: photoSettings, delegate: delegate)

        videoPreviewLayer?.connection?.isEnabled = false
    }

    func startRecordingVideo(delegate: AVCaptureFileOutputRecordingDelegate) {
        guard cameraOutputMode != .image else {
            let cameraError = CameraError.internalError("Wrong capture session output")
            self.delegate?.reportError(error: cameraError)
            return
        }

        guard isSessionRunning() else {
            return
        }

        guard let videoOutput else {
            let cameraError = CameraError.internalError("Video output not initialized")
            self.delegate?.reportError(error: cameraError)
            return
        }

        guard !videoOutput.isRecording else {
            return
        }

        // Reset pause flag when resuming
        skipMediaNotification = false

        // Check if there are active connections
        guard let connection = videoOutput.connection(with: .video), connection.isEnabled, connection.isActive else {
            let cameraError = CameraError.internalError(
                "No active video connection. Camera may not be available on simulator."
            )
            self.delegate?.reportError(error: cameraError)
            return
        }

        videoOutput.startRecording(to: getTempFilePath(), recordingDelegate: delegate)
    }

    func stopVideoRecording(skipMedia: Bool) {
        skipMediaNotification = skipMedia

        guard
            let captureSession, captureSession.isRunning, let runningVideoOutput = videoOutput,
            runningVideoOutput.isRecording else {
            if skipMediaNotification {
                return
            }

            let cameraError = CameraError.internalError("Unable to stop video recording")
            delegate?.reportError(error: cameraError)
            return
        }

        runningVideoOutput.stopRecording()

        if let frameData = captureLastFrame() {
            delegate?.lastFrameCaptured(frameData: frameData)
        }
    }

    func captureLastFrame() -> Data? {
        guard let sampleBuffer = lastSampleBuffer else {
            return nil
        }

        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }

        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext()

        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }

        let orientation: UIImage.Orientation = cameraSide == .front ? .leftMirrored : .right
        let uiImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: orientation)
        return uiImage.jpegData(compressionQuality: 0.85)
    }

    func getTempFilePath() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("VID_\(Self.fileDateFormatter.string(from: Date()))").appendingPathExtension("mp4")
    }
}
