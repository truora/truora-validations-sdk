//
//  CameraManager+Utilities.swift
//  TruoraCamera
//
//  Created by Truora on 21/11/25.
//

import AVFoundation
import UIKit

extension CameraManager {
    func cleanupGestureRecognizers() {
        guard let view = focusGesture.view else { return }
        view.removeGestureRecognizer(focusGesture)
        focusGesture.removeTarget(self, action: #selector(focusStart(_:)))
    }

    func waitForVideoConnectionReady(attempt: Int = 0) {
        guard let videoOutput,
              let connection = videoOutput.connection(with: .video) else {
            if attempt < 30 {
                if attempt == 0 || attempt % 5 == 0 {
                    print(
                        "⏳ CameraManager: Waiting for video connection (attempt \(attempt + 1)/30)"
                    )
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                    self?.waitForVideoConnectionReady(attempt: attempt + 1)
                }
            } else {
                print(
                    "❌ CameraManager: Video connection not available after \(Double(attempt) * 0.2)s"
                )
                print("❌ CameraManager: Session running: \(captureSession?.isRunning ?? false)")
                print("❌ CameraManager: Session inputs: \(captureSession?.inputs.count ?? 0)")
                print("❌ CameraManager: Session outputs: \(captureSession?.outputs.count ?? 0)")
                let cameraError = CameraError.internalError(
                    "Video connection not available. Camera may be in use or restricted."
                )
                delegate?.reportError(error: cameraError)
            }
            return
        }

        if connection.isActive, connection.isEnabled {
            print(
                "✅ CameraManager: Video connection ready "
                    + "(attempt: \(attempt + 1), active: \(connection.isActive), "
                    + "enabled: \(connection.isEnabled))"
            )
            delegate?.cameraReady()
        } else if attempt < 30 {
            if attempt == 0 || attempt % 5 == 0 {
                print(
                    "⏳ CameraManager: Connection exists but not active yet "
                        + "(attempt \(attempt + 1)/30, active: \(connection.isActive), "
                        + "enabled: \(connection.isEnabled))"
                )
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.waitForVideoConnectionReady(attempt: attempt + 1)
            }
        } else {
            print(
                "❌ CameraManager: Video connection failed to become active after \(Double(attempt) * 0.2)s"
            )
            let cameraError = CameraError.internalError(
                "Video connection active timeout. Camera may be malfunctioning."
            )
            delegate?.reportError(error: cameraError)
        }
    }

    func getCamera() -> AVCaptureDevice? {
        switch cameraSide {
        case .front:
            cameraWithPosition(position: .front)
        default:
            cameraWithPosition(position: .back)
        }
    }

    func cameraWithPosition(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInDualCamera, .builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified
        )

        return discoverySession.devices.first { device in device.position == position }
    }

    func updateCameraSide() {
        guard
            let captureSession,
            let currentCameraInput: AVCaptureInput = captureSession.inputs.first else {
            return
        }

        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        captureSession.removeInput(currentCameraInput)

        let success = setupInput()
        if !success {
            print("❌ CameraManager: Failed to switch camera side")
        }
    }
}
