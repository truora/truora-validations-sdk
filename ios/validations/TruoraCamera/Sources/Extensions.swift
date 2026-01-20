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
    func getCompressedImage() -> UIImage? {
        let maxSize: CGFloat = 1024

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

        let rect = CGRect(x: 0.0, y: 0.0, width: actualWidth, height: actualHeight)
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 1.0)
        defer { UIGraphicsEndImageContext() }

        draw(in: rect)
        let img = UIGraphicsGetImageFromCurrentImageContext()

        return img
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
