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
                    print("⏳ CameraManager: Waiting for video connection (attempt \(attempt + 1)/30)")
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                    self?.waitForVideoConnectionReady(attempt: attempt + 1)
                }
            } else {
                print("❌ CameraManager: Video connection not available after \(Double(attempt) * 0.2)s")
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
            print("✅ CameraManager: Video connection ready " +
                "(attempt: \(attempt + 1), active: \(connection.isActive), " +
                "enabled: \(connection.isEnabled))")
            delegate?.cameraReady()
        } else if attempt < 30 {
            if attempt == 0 || attempt % 5 == 0 {
                print("⏳ CameraManager: Connection exists but not active yet " +
                    "(attempt \(attempt + 1)/30, active: \(connection.isActive), " +
                    "enabled: \(connection.isEnabled))")
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.waitForVideoConnectionReady(attempt: attempt + 1)
            }
        } else {
            print("❌ CameraManager: Video connection failed to become active after \(Double(attempt) * 0.2)s")
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
            deviceTypes:
            [.builtInDualCamera, .builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified
        )

        return discoverySession.devices.first(where: { device in device.position == position }) ?? nil
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

    private func calculateVideoCropParameters(
        videoSize: CGSize,
        viewBounds: CGRect,
        preferredTransform: CGAffineTransform
    ) -> (cropRect: CGRect, renderSize: CGSize) {
        let isPortrait = preferredTransform.a == 0 && abs(preferredTransform.b) == 1.0
        let isRotatedCCW = preferredTransform.b < 0

        let displayWidth = viewBounds.width
        let displayHeight = viewBounds.height - bottomInsetPoints

        let videoDisplayWidth: CGFloat
        let videoDisplayHeight: CGFloat
        if isPortrait {
            videoDisplayWidth = videoSize.height
            videoDisplayHeight = videoSize.width
        } else {
            videoDisplayWidth = videoSize.width
            videoDisplayHeight = videoSize.height
        }

        let videoScale = max(videoDisplayWidth / displayWidth, videoDisplayHeight / displayHeight)
        let pixelsToRemove = bottomInsetPoints * videoScale

        let cropRect: CGRect
        let renderSize: CGSize

        if isPortrait {
            let croppedWidth = videoSize.width - pixelsToRemove
            if isRotatedCCW {
                cropRect = CGRect(x: pixelsToRemove, y: 0, width: croppedWidth, height: videoSize.height)
            } else {
                cropRect = CGRect(x: 0, y: 0, width: croppedWidth, height: videoSize.height)
            }
            renderSize = CGSize(width: videoSize.height, height: croppedWidth)
        } else {
            let croppedHeight = videoSize.height - pixelsToRemove
            cropRect = CGRect(x: 0, y: 0, width: videoSize.width, height: croppedHeight)
            renderSize = CGSize(width: videoSize.width, height: croppedHeight)
        }

        return (cropRect, renderSize)
    }

    private func createVideoComposition(
        asset: AVAsset,
        videoTrack: AVAssetTrack,
        cropRect: CGRect,
        renderSize: CGSize,
        preferredTransform: CGAffineTransform
    ) -> AVMutableVideoComposition {
        let composition = AVMutableVideoComposition()
        composition.renderSize = renderSize

        // Use the actual frame rate from the video track
        let frameRate = videoTrack.nominalFrameRate > 0 ? videoTrack.nominalFrameRate : 30
        composition.frameDuration = CMTime(value: 1, timescale: Int32(frameRate))

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: CMTime.zero, duration: asset.duration)

        let transformer = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        transformer.setCropRectangle(cropRect, at: CMTime.zero)
        transformer.setTransform(preferredTransform, at: CMTime.zero)

        instruction.layerInstructions = [transformer]
        composition.instructions = [instruction]

        return composition
    }

    func cropVideo(
        at sourceURL: URL,
        viewBounds: CGRect,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        guard bottomInsetPoints > 0 else {
            completion(.success(sourceURL))
            return
        }

        let asset = AVAsset(url: sourceURL)
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            let error = NSError(
                domain: "CameraManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No video track found"]
            )
            completion(.failure(error))
            return
        }

        let videoSize = videoTrack.naturalSize
        let preferredTransform = videoTrack.preferredTransform

        let (cropRect, renderSize) = calculateVideoCropParameters(
            videoSize: videoSize,
            viewBounds: viewBounds,
            preferredTransform: preferredTransform
        )

        let composition = createVideoComposition(
            asset: asset,
            videoTrack: videoTrack,
            cropRect: cropRect,
            renderSize: renderSize,
            preferredTransform: preferredTransform
        )

        exportCroppedVideo(asset: asset, composition: composition, preset: .optimal, completion: completion)
    }

    private func exportCroppedVideo(
        asset: AVAsset,
        composition: AVMutableVideoComposition,
        preset: VideoCompressionPreset,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let outputURL = getTempFilePath()

        guard let exporter = AVAssetExportSession(
            asset: asset,
            presetName: preset.exportPreset
        ) else {
            handleExportSessionCreationFailure(
                preset: preset,
                asset: asset,
                composition: composition,
                completion: completion
            )
            return
        }

        exporter.outputURL = outputURL
        exporter.outputFileType = .mp4
        exporter.videoComposition = composition

        exporter.exportAsynchronously { [weak self] in
            DispatchQueue.main.async {
                guard let self else {
                    let error = NSError(
                        domain: "CameraManager",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "CameraManager was deallocated during export"]
                    )
                    completion(.failure(error))
                    return
                }

                if exporter.status == .failed, preset != .h264Fallback {
                    let errorDesc = exporter.error?.localizedDescription ?? "unknown"
                    print("⚠️ CameraManager: Export with \(preset.exportPreset) failed " +
                        "with error: \(errorDesc), falling back to H.264")
                    self.exportCroppedVideo(
                        asset: asset,
                        composition: composition,
                        preset: .h264Fallback,
                        completion: completion
                    )
                    return
                }

                self.handleExportCompletion(exporter: exporter, outputURL: outputURL, completion: completion)
            }
        }
    }

    private func handleExportSessionCreationFailure(
        preset: VideoCompressionPreset,
        asset: AVAsset,
        composition: AVMutableVideoComposition,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        if preset != .h264Fallback {
            print("⚠️ CameraManager: Failed to create export session with \(preset.exportPreset), trying H.264 fallback")
            exportCroppedVideo(asset: asset, composition: composition, preset: .h264Fallback, completion: completion)
            return
        }

        let error = NSError(
            domain: "CameraManager",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"]
        )
        completion(.failure(error))
    }

    private func handleExportCompletion(
        exporter: AVAssetExportSession,
        outputURL: URL,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        switch exporter.status {
        case .completed:
            print("✅ CameraManager: Video cropped successfully")
            completion(.success(outputURL))
        case .failed:
            let errorDesc = exporter.error?.localizedDescription ?? "Unknown error"
            print("❌ CameraManager: Video crop failed: \(errorDesc)")
            let error = exporter.error ?? NSError(
                domain: "CameraManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Export failed"]
            )
            completion(.failure(error))
        case .cancelled:
            print("⚠️ CameraManager: Video crop cancelled")
            let error = NSError(
                domain: "CameraManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Export cancelled"]
            )
            completion(.failure(error))
        default:
            print("⚠️ CameraManager: Unknown export status: \(exporter.status.rawValue)")
            let error = NSError(
                domain: "CameraManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Unknown export status"]
            )
            completion(.failure(error))
        }
    }
}
