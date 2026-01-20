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
    var lastSampleBuffer: CMSampleBuffer?
    let videoDataOutputQueue = DispatchQueue(label: "com.truora.camera.videoDataOutput")

    // Cached date formatter for performance
    static let fileDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy_MM_dd_HH_mm_ss_SSS"
        return formatter
    }()

    weak var delegate: CameraDelegate?

    var cameraOutputMode: CameraOutputMode = .image
    var bottomInsetPoints: CGFloat = 0
    var cameraSide: CameraSide = .back {
        didSet {
            if cameraIsSetup, cameraSide != oldValue {
                updateCameraSide()
            }
        }
    }

    private var frameProcessor: FrameProcessor?

    init(frameProcessor: FrameProcessor? = nil) {
        self.frameProcessor = frameProcessor
        super.init()
        let focusSquareImage = UIImage(
            named: focusSquareImageName,
            in: Bundle(for: CameraManager.self),
            compatibleWith: nil
        )
        focusSquare = UIImageView(image: focusSquareImage)
    }
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
