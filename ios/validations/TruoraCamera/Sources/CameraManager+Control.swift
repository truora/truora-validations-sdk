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
        guard let captureSession else { return }
        Self.sessionQueue.async {
            captureSession.stopRunning()
        }
    }

    /// Resumes a previously paused camera session.
    /// This does not reconfigure inputs/outputs or preview layer; it only restarts the session.
    func resumeCamera() {
        assert(Thread.isMainThread, "pendingResumes is main thread only")
        guard cameraIsSetup, let captureSession else { return }

        pendingResumes += 1
        Self.sessionQueue.async { [weak self] in
            if !captureSession.isRunning {
                captureSession.startRunning()
            }
            DispatchQueue.main.async { self?.pendingResumes -= 1 }
        }
    }

    func stopCamera() {
        startingSession = nil
        startingPreview = nil
        startInterruptionTimeout?.cancel()
        removeSessionObservers()
        cleanupGestureRecognizers()

        // Remove preview layer from view
        videoPreviewLayer?.removeFromSuperlayer()
        videoPreviewLayer = nil

        if let session = captureSession {
            Self.sessionQueue.async {
                session.stopRunning()
                for input in session.inputs {
                    session.removeInput(input)
                }
                for output in session.outputs {
                    session.removeOutput(output)
                }
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
            // Interrupted or resuming sessions start by themselves, so they must not be torn down.
            let startsByItself = captureSession.map { pendingResumes > 0 || $0.isInterrupted } ?? false
            let error: CameraError = startsByItself
                ? .sessionNotReady
                : .captureSessionError(reason: "Session is not running")
            self.delegate?.reportError(error: error)
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
