//
//  CameraManager+Setup.swift
//  TruoraCamera
//
//  Created by Truora on 21/11/25.
//

import AVFoundation
import UIKit

extension CameraManager {
    func setupCamera(view: UIView, cameraOutputMode: CameraOutputMode) {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitesting") {
            debugLog("🧪 CameraManager: UI Testing mode detected. Skipping real camera setup.")
            cameraIsSetup = true
            // Simulate camera ready delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.delegate?.cameraReady()
            }
            return
        }
        #endif

        guard !cameraIsSetup else {
            debugLog("⚠️ CameraManager: setupCamera called when camera is already setup")
            return
        }

        // Mark as setup immediately to prevent race conditions with double setup calls
        cameraIsSetup = true

        // Reset paused state when starting fresh
        skipMediaNotification = false

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            debugLog("✅ CameraManager: Camera permission granted")
            configureSession(view: view, cameraOutputMode: cameraOutputMode)
        case .notDetermined:
            debugLog("⚠️ CameraManager: Camera permission not determined")
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self, self.cameraIsSetup, self.captureSession == nil else { return }
                    if granted {
                        self.configureSession(view: view, cameraOutputMode: cameraOutputMode)
                    } else {
                        self.delegate?.reportError(error: .permissionDenied(status: .denied))
                    }
                }
            }
        case .denied, .restricted:
            debugLog("❌ CameraManager: Camera permission denied or restricted")
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            delegate?.reportError(error: .permissionDenied(status: status))
            return
        @unknown default:
            debugLog("❌ CameraManager: Unknown camera permission status")
            let cameraError = CameraError.internalError("Unknown camera permission status")
            delegate?.reportError(error: cameraError)
            return
        }
    }

    private func configureSession(view: UIView, cameraOutputMode: CameraOutputMode) {
        captureSession = AVCaptureSession()

        // Use adaptive session preset from performance advisor if available,
        // otherwise default to 720p
        let preset: AVCaptureSession.Preset = sessionPresetOverride ?? .hd1280x720
        captureSession?.sessionPreset = preset
        focusGesture.isEnabled = true

        captureSession?.beginConfiguration()
        let inputAdded = setupInput()
        let outputAdded = setupOutputMode(cameraOutputMode)
        captureSession?.commitConfiguration()

        guard inputAdded, outputAdded else {
            debugLog(
                "❌ CameraManager: Failed to setup camera - input: \(inputAdded), output: \(outputAdded)"
            )
            // The failing step already reported its error.
            cameraIsSetup = false
            return
        }

        setupLivePreview(photoPreview: view)
    }

    @discardableResult
    func setupInput() -> Bool {
        guard let camera = getCamera() else {
            debugLog("❌ CameraManager: Failed to get camera device")
            let cameraError = CameraError.internalError("Error getting camera")
            delegate?.reportError(error: cameraError)
            return false
        }

        var input: AVCaptureDeviceInput?
        do {
            input = try AVCaptureDeviceInput(device: camera)
        } catch {
            debugLog("❌ CameraManager: Failed to create camera input: \(error.localizedDescription)")
            let message = "Error creating capture device input: \(error.localizedDescription)"
            delegate?.reportError(error: .internalError(message))
            return false
        }

        guard let captureSession, let input, captureSession.canAddInput(input) else {
            debugLog("❌ CameraManager: Cannot add camera input to session")
            let cameraError = CameraError.internalError("Error creating capture device input")
            delegate?.reportError(error: cameraError)
            return false
        }

        captureSession.addInput(input)
        return true
    }

    @discardableResult
    func setupOutputMode(_ newCameraOutputMode: CameraOutputMode) -> Bool {
        cameraOutputMode = newCameraOutputMode

        switch cameraOutputMode {
        case .image:
            return setImageOutput()
        case .video:
            return setVideoOutput()
        }
    }

    func setImageOutput() -> Bool {
        if imageOutput != nil {
            return true
        }

        let newImageOutput = AVCapturePhotoOutput()
        imageOutput = newImageOutput

        guard let captureSession, captureSession.canAddOutput(newImageOutput) else {
            debugLog("❌ CameraManager: Cannot add image output to session")
            let cameraError = CameraError.internalError("Unable to initialize camera")
            delegate?.reportError(error: cameraError)
            return false
        }

        captureSession.addOutput(newImageOutput)

        // Also add video data output for frame processing (detection)
        // This enables document/face detection while in still image capture mode
        let newVideoDataOutput = AVCaptureVideoDataOutput()
        newVideoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        newVideoDataOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        newVideoDataOutput.alwaysDiscardsLateVideoFrames = true

        videoDataOutput = newVideoDataOutput

        guard captureSession.canAddOutput(newVideoDataOutput) else {
            debugLog(
                "⚠️ CameraManager: Cannot add video data output for frame processing in image mode"
            )
            // Not a critical error - image capture will still work, just without frame processing
            return true
        }

        captureSession.addOutput(newVideoDataOutput)

        return true
    }

    func setVideoOutput() -> Bool {
        if videoOutput != nil {
            return true
        }

        let newVideoOutput = AVCaptureMovieFileOutput()
        newVideoOutput.movieFragmentInterval = CMTime.invalid

        videoOutput = newVideoOutput

        guard let captureSession, captureSession.canAddOutput(newVideoOutput) else {
            debugLog("❌ CameraManager: Cannot add video output to session")
            let cameraError = CameraError.internalError("Unable to initialize camera")
            delegate?.reportError(error: cameraError)
            return false
        }

        captureSession.addOutput(newVideoOutput)

        // Configure HEVC if available (iOS 13+ support)
        if let connection = newVideoOutput.connection(with: .video),
           newVideoOutput.availableVideoCodecTypes.contains(.hevc) {
            newVideoOutput.setOutputSettings(
                [AVVideoCodecKey: AVVideoCodecType.hevc], for: connection
            )
            debugLog("✅ CameraManager: HEVC codec configured for video recording")
        }

        let newVideoDataOutput = AVCaptureVideoDataOutput()
        newVideoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        newVideoDataOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        newVideoDataOutput.alwaysDiscardsLateVideoFrames = true

        videoDataOutput = newVideoDataOutput

        guard captureSession.canAddOutput(newVideoDataOutput) else {
            debugLog("❌ CameraManager: Cannot add video data output to session")
            let cameraError = CameraError.internalError("Unable to add video data output")
            delegate?.reportError(error: cameraError)
            return false
        }

        captureSession.addOutput(newVideoDataOutput)
        return true
    }

    func setupLivePreview(photoPreview: UIView) {
        guard let captureSession else { return }

        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)

        guard let videoPreviewLayer else { return }

        videoPreviewLayer.frame = photoPreview.bounds
        videoPreviewLayer.videoGravity = .resizeAspectFill
        videoPreviewLayer.connection?.videoOrientation = .portrait

        photoPreview.layer.addSublayer(videoPreviewLayer)

        startingSession = captureSession
        startingPreview = photoPreview
        observeSessionStart(captureSession)

        Self.sessionQueue.async { [weak self] in
            // Blocks until the session runs or fails; failure arrives as a runtime error.
            captureSession.startRunning()
            DispatchQueue.main.async {
                self?.evaluateSessionStart(captureSession)
            }
        }
    }

    private func observeSessionStart(_ session: AVCaptureSession) {
        removeSessionObservers()
        let center = NotificationCenter.default
        sessionObservers = [
            // Also fires when an interrupted session restarts by itself.
            center.addObserver(
                forName: AVCaptureSession.didStartRunningNotification, object: session, queue: .main
            ) { [weak self] notification in
                guard let session = notification.object as? AVCaptureSession else { return }
                self?.evaluateSessionStart(session)
            },
            center.addObserver(
                forName: AVCaptureSession.runtimeErrorNotification, object: session, queue: .main
            ) { [weak self] notification in
                guard let self,
                      let session = notification.object as? AVCaptureSession,
                      self.startingSession === session else { return }
                let error = notification.userInfo?[AVCaptureSessionErrorKey] as? Error
                self.failSessionStart(detail: error?.diagnosticCode, underlyingError: error)
            },
            center.addObserver(
                forName: AVCaptureSession.wasInterruptedNotification, object: session, queue: .main
            ) { [weak self] notification in
                guard let session = notification.object as? AVCaptureSession else { return }
                let reason = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as? Int ?? 0
                self?.scheduleStartInterruptionTimeout(session, reason: reason)
            }
        ]
    }

    private func scheduleStartInterruptionTimeout(_ session: AVCaptureSession, reason: Int) {
        // Only the video (face) screen retries a failed start; the others keep waiting.
        guard cameraOutputMode == .video else { return }

        startInterruptionTimeout?.cancel()
        // Backgrounded: the session restarts when the app returns, so it gets no timeout.
        let background = AVCaptureSession.InterruptionReason.videoDeviceNotAvailableInBackground.rawValue
        guard reason != background else { return }

        let timeout = DispatchWorkItem { [weak self] in
            guard let self, self.startingSession === session else { return }
            if session.isInterrupted {
                self.failSessionStart(detail: "interrupted, reason \(reason)")
            } else if session.isRunning {
                self.completeSessionStart()
            } else {
                // The interruption just ended and iOS may still be restarting the session.
                DispatchQueue.main.asyncAfter(deadline: .now() + Self.startRecoveryGrace) { [weak self] in
                    self?.evaluateSessionStart(session)
                }
            }
        }
        startInterruptionTimeout = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.maxStartInterruption, execute: timeout)
    }

    func removeSessionObservers() {
        for observer in sessionObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        sessionObservers = []
    }

    /// An interrupted session is not a failure: it restarts by itself.
    private func evaluateSessionStart(_ session: AVCaptureSession) {
        guard startingSession === session else { return }

        if session.isRunning {
            completeSessionStart()
        } else if !session.isInterrupted {
            failSessionStart()
        }
    }

    private func completeSessionStart() {
        startingSession = nil
        // A gone preview means the screen is gone, so there is nobody to notify.
        guard let preview = startingPreview else { return }
        startingPreview = nil

        videoPreviewLayer?.frame = preview.bounds
        attachFocus(preview)

        if cameraOutputMode == .video {
            waitForVideoConnectionReady()
        } else {
            delegate?.cameraReady()
        }
    }

    private func failSessionStart(detail: String? = nil, underlyingError: Error? = nil) {
        startingSession = nil
        startingPreview = nil
        cameraIsSetup = false

        var message = "Camera session failed to start"
        if let detail {
            message += " (\(detail))"
        }
        delegate?.reportError(error: .internalError(message, underlyingError: underlyingError))
    }

    func calculateVisibleCameraFrame(for view: UIView) -> CGRect {
        view.bounds
    }

    func updatePreviewLayerFrame(for view: UIView) {
        guard cameraIsSetup else { return }
        videoPreviewLayer?.frame = view.bounds
    }
}
