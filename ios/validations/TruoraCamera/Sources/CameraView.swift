//
//  CameraView.swift
//  TruoraCamera
//
//  Created by Adriana Pineda on 7/15/21.
//

import AVFoundation
import CoreImage
import Foundation
import UIKit

public enum PictureOrientation {
    case horizontal, vertical
}

public class CameraView: UIView {
    var cameraManager: CameraManager
    public var orientation = PictureOrientation.horizontal
    public weak var delegate: CameraDelegate?

    public init(frameProcessor: FrameProcessor? = nil) {
        self.cameraManager = CameraManager(frameProcessor: frameProcessor)
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        self.cameraManager = CameraManager(frameProcessor: nil)
        super.init(coder: coder)
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        cameraManager.updatePreviewLayerFrame(for: self)
    }

    public func startCamera(side: CameraSide, cameraOutputMode: CameraOutputMode = .image) {
        cameraManager.cameraSide = side
        cameraManager.delegate = delegate
        cameraManager.setupCamera(view: self, cameraOutputMode: cameraOutputMode)
    }

    public func stopCamera() {
        cameraManager.stopCamera()
    }

    /// Pauses the camera session without tearing down.
    /// The preview layer freezes on the last frame.
    public func pauseCamera() {
        cameraManager.pauseCamera()
    }

    public func isSessionRunning() -> Bool {
        cameraManager.isSessionRunning()
    }

    /// Switches between front and back camera.
    /// Note: This should NOT be called for passive/face capture flows, which must always use front camera only.
    public func switchCamera() {
        guard cameraManager.cameraIsSetup else {
            print("⚠️ CameraView: Cannot switch camera - camera not setup")
            return
        }
        cameraManager.cameraSide = cameraManager.cameraSide == .front ? .back : .front
    }

    public func takePicture() {
        cameraManager.takePicture(delegate: self)
    }

    public func startRecordingVideo() {
        cameraManager.startRecordingVideo(delegate: self)
    }

    public func stopVideoRecording(skipMediaNotification: Bool) {
        cameraManager.stopVideoRecording(skipMedia: skipMediaNotification)
    }
}

extension CameraView: AVCapturePhotoCaptureDelegate {
    private func getDataAndImageFromOrientation(photo: AVCapturePhoto) -> (Data?, UIImage?) {
        var data = photo.fileDataRepresentation()
        var image = UIImage(data: data ?? Data())

        if self.orientation == .horizontal, let cgImg = photo.cgImageRepresentation() {
            image = UIImage(cgImage: cgImg, scale: 1, orientation: .up)
            data = image?.pngData()
        } else if self.orientation == .vertical, let cgImg = photo.cgImageRepresentation() {
            // For vertical/portrait orientation, rotate using CIImage
            // Back camera captures in landscape, front camera is mirrored

            let ciOrientation: CGImagePropertyOrientation =
                cameraManager.cameraSide == .front ? .leftMirrored : .right
            let ciImage = CIImage(cgImage: cgImg).oriented(ciOrientation)
            let context = CIContext()
            if let rotatedCGImage = context.createCGImage(ciImage, from: ciImage.extent) {
                image = UIImage(cgImage: rotatedCGImage)
                data = image?.pngData()
            }
        }

        return (data, image)
    }

    public func photoOutput(
        _: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        defer {
            cameraManager.videoPreviewLayer?.connection?.isEnabled = true
        }

        if let error {
            let cameraError =
                CameraError
                    .internalError("Error unable to take picture:  \(error.localizedDescription)")
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.reportError(error: cameraError)
            }
            return
        }

        let (data, image) = getDataAndImageFromOrientation(photo: photo)

        guard let imgData = data else { return }

        guard
            let compressedImage = image?.getCompressedImage(),
            let compressedData = compressedImage.pngData() else {
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.mediaReady(media: imgData)
            }
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.delegate?.mediaReady(media: compressedData)
        }
    }
}

// MARK: AVCaptureFileOutputRecordingDelegate

extension CameraView: AVCaptureFileOutputRecordingDelegate {
    public func fileOutput(
        _: AVCaptureFileOutput,
        didFinishRecordingTo url: URL,
        from _: [AVCaptureConnection],
        error: Error?
    ) {
        let manager = cameraManager

        if let error {
            // If camera was stopped (e.g., app went to background), silently ignore the interruption
            // This is expected behavior - iOS interrupts recordings when app becomes inactive
            if !manager.cameraIsSetup {
                print("⚠️ CameraView: Recording interrupted (camera stopped), ignoring error")
                url.deleteFile()
                return
            }

            let cameraError =
                CameraError
                    .internalError("Error unable to record video:  \(error.localizedDescription)")
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.reportError(error: cameraError)
            }
            url.deleteFile()
            return
        }

        // If camera was paused (e.g., help dialog), discard this video file
        // and don't process it. Only process videos from normal recordings.
        if manager.skipMediaNotification {
            url.deleteFile()
            return
        }

        defer { url.deleteFile() }

        do {
            let data = try Data(contentsOf: url)
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.mediaReady(media: data)
            }
        } catch {
            let cameraError = CameraError.internalError(
                "Error reading video: \(error.localizedDescription)"
            )
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.reportError(error: cameraError)
            }
        }
    }
}
