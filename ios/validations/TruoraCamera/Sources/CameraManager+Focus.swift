//
//  CameraManager+Focus.swift
//  TruoraCamera
//
//  Created by Truora on 21/11/25.
//

import AVFoundation
import UIKit

// MARK: UIGestureRecognizerDelegate

extension CameraManager: UIGestureRecognizerDelegate {
    func attachFocus(_ view: UIView) {
        focusGesture.addTarget(self, action: #selector(focusStart(_:)))
        view.addGestureRecognizer(focusGesture)
        focusGesture.delegate = self
    }

    @objc
    func focusStart(_ recognizer: UITapGestureRecognizer) {
        guard let camera = getCamera() else { return }

        guard
            let validPreviewLayer = videoPreviewLayer,
            let view = recognizer.view else {
            return
        }

        let pointInPreviewLayer = view.layer.convert(recognizer.location(in: view), to: validPreviewLayer)
        let pointOfInterest = validPreviewLayer.captureDevicePointConverted(fromLayerPoint: pointInPreviewLayer)

        do {
            try camera.lockForConfiguration()

            showFocusRectangleAtPoint(pointInPreviewLayer, inLayer: view)

            if camera.isFocusPointOfInterestSupported, camera.isFocusModeSupported(.continuousAutoFocus) {
                camera.focusPointOfInterest = pointOfInterest
                camera.focusMode = .continuousAutoFocus
            }

            if camera.isExposurePointOfInterestSupported,
               camera.isExposureModeSupported(.continuousAutoExposure) {
                camera.exposurePointOfInterest = pointOfInterest
                camera.exposureMode = .continuousAutoExposure
            }

            camera.unlockForConfiguration()
        } catch {
            #if DEBUG
            print(error)
            #endif
        }
    }

    func showFocusRectangleAtPoint(_ focusPoint: CGPoint, inLayer view: UIView) {
        guard let focusSquare else { return }

        focusSquare.frame = CGRect(
            x: focusPoint.x - focusSquareWidth / 2,
            y: focusPoint.y - focusSquareWidth / 2,
            width: focusSquareWidth,
            height: focusSquareWidth
        )

        focusSquare.alpha = 1
        view.addSubview(focusSquare)

        UIView.animate(
            withDuration: focusAnimationDuration,
            delay: focusAnimationDelay,
            options: .curveEaseOut,
            animations: { focusSquare.alpha = 0 },
            completion: { _ in
                focusSquare.removeFromSuperview()
            }
        )
    }
}
