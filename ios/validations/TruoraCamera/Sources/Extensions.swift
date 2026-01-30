//
//  Extensions.swift
//  TruoraCamera
//
//  Created by Laura Donado on 4/11/21.
//

import Foundation
import UIKit

// MARK: - UIImage Extensions

extension UIImage {
    /// Compresses the image to fit within a maximum size while maintaining aspect ratio.
    /// Uses UIGraphicsImageRenderer (iOS 10+) for better performance and memory efficiency.
    /// - Parameter maxSize: The maximum dimension (width or height) for the output image. Defaults to 1024.
    /// - Returns: A compressed image, or nil if the source image has invalid dimensions.
    func getCompressedImage(maxSize: CGFloat = CameraConstants.maxImageSize) -> UIImage? {
        var actualHeight = size.height
        var actualWidth = size.width

        // Guard against zero or negative dimensions
        guard actualHeight > 0, actualWidth > 0 else {
            return nil
        }

        let maxHeight: CGFloat = maxSize
        let maxWidth: CGFloat = maxSize
        var imgRatio: CGFloat = actualWidth / actualHeight
        let maxRatio: CGFloat = maxWidth / maxHeight

        if actualHeight > maxHeight || actualWidth > maxWidth {
            if imgRatio < maxRatio {
                imgRatio = maxHeight / actualHeight
                actualWidth = imgRatio * actualWidth
                actualHeight = maxHeight
            } else if imgRatio > maxRatio {
                imgRatio = maxWidth / actualWidth
                actualHeight = imgRatio * actualHeight
                actualWidth = maxWidth
            } else {
                actualHeight = maxHeight
                actualWidth = maxWidth
            }
        }

        let targetSize = CGSize(width: actualWidth, height: actualHeight)

        // Use UIGraphicsImageRenderer (iOS 10+) - more efficient than deprecated UIGraphicsBeginImageContext
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

// MARK: - URL Extensions

extension URL {
    func deleteFile() {
        do {
            try FileManager.default.removeItem(at: self)
        } catch {
            #if DEBUG
            print("Error deleting file: \(error)")
            #endif
        }
    }
}
