//
//  ResizePadPreprocessor.swift
//  TruoraCamera
//
//  Created by Sergio Guzmán on 06/01/26.
//

import Accelerate
import AVFoundation
import CoreImage
import Foundation

/// Result of preprocessing containing all info needed to map coordinates back
struct PreprocessResult {
    let data: Data // Preprocessed image data for model input
    let scale: Float // Scale factor: originalSize * scale = scaledSize
    let originalSize: CGSize // Original image dimensions before preprocessing
    let scaledSize: CGSize // Size of content area in model input (excludes padding)
}

/// Preprocessor that matches Python ResizePadLayer behavior:
/// - Preserves aspect ratio
/// - Resizes to fit within target size
/// - Pads bottom/right with zeros (black pixels)
/// - Returns float32 data in [0,1] range
///
/// Note: This is a class (not struct) because it caches a CIContext for performance.
/// CIContext is heavyweight and should be reused for real-time camera processing.
final class ResizePadPreprocessor {
    let targetSize: CGSize
    let outputDtype: OutputDtype

    // Cached CIContext - lazy to defer creation until first use
    private lazy var ciContext = CIContext(options: [.useSoftwareRenderer: false])

    enum OutputDtype {
        case float32 // Range [0,1]
        case uint8 // Range [0,255]
    }

    init(targetSize: CGSize, outputDtype: OutputDtype) {
        self.targetSize = targetSize
        self.outputDtype = outputDtype
    }

    /// Preprocesses a CVPixelBuffer with aspect-ratio-preserving resize and zero padding
    /// - Parameters:
    ///   - pixelBuffer: Input image buffer
    /// - Returns: PreprocessResult containing data and coordinate mapping info, or nil on failure
    func preprocess(_ pixelBuffer: CVPixelBuffer) -> PreprocessResult? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        return preprocess(ciImage: ciImage)
    }

    /// Preprocesses a CIImage with aspect-ratio-preserving resize and zero padding
    /// - Parameters:
    ///   - ciImage: Input Core Image
    /// - Returns: PreprocessResult containing data and coordinate mapping info, or nil on failure
    func preprocess(ciImage: CIImage) -> PreprocessResult? {
        // Get original dimensions
        let originalWidth = ciImage.extent.width
        let originalHeight = ciImage.extent.height

        guard originalWidth > 0, originalHeight > 0 else {
            return nil
        }

        // Calculate scale factor preserving aspect ratio (matches Python: min(target/max_size))
        let maxSize = max(originalWidth, originalHeight)
        let scale = min(
            targetSize.width / maxSize,
            targetSize.height / maxSize
        )

        // Calculate scaled dimensions (content area size in model input space)
        let scaledWidth = originalWidth * scale
        let scaledHeight = originalHeight * scale

        // Resize image preserving aspect ratio
        let scaledImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        // Render scaled image to CGImage
        guard let scaledCGImage = ciContext.createCGImage(
            scaledImage,
            from: CGRect(x: 0, y: 0, width: scaledWidth, height: scaledHeight)
        ) else {
            return nil
        }

        // Extract RGB data directly from a single CGContext (no double context creation)
        guard let rgbData = extractRGBData(
            from: scaledCGImage,
            scaledWidth: scaledWidth,
            scaledHeight: scaledHeight
        ) else {
            return nil
        }

        return PreprocessResult(
            data: rgbData,
            scale: Float(scale),
            originalSize: CGSize(width: originalWidth, height: originalHeight),
            scaledSize: CGSize(width: scaledWidth, height: scaledHeight)
        )
    }

    /// Extracts RGB data from scaled image, applying padding and format conversion in a single pass
    /// - Parameters:
    ///   - scaledImage: The scaled CGImage to process
    ///   - scaledWidth: Width of the content area
    ///   - scaledHeight: Height of the content area
    /// - Returns: RGB data in the specified format, or nil on failure
    private func extractRGBData(
        from scaledImage: CGImage,
        scaledWidth: CGFloat,
        scaledHeight: CGFloat
    ) -> Data? {
        let width = Int(targetSize.width)
        let height = Int(targetSize.height)
        let bytesPerPixel = 4
        let bytesPerRow = ((width * bytesPerPixel) + 63) & ~63 // Align to 64 bytes

        // Create a single CGContext for drawing with padding
        guard
            let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
            ) else {
            return nil
        }

        // Fill with black (zeros) - this is the padding
        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        // Draw scaled image at origin (0,0) - bottom/right will remain black (padding)
        context.draw(scaledImage, in: CGRect(x: 0, y: 0, width: scaledWidth, height: scaledHeight))

        // Extract RGB data directly from this context (no second context needed)
        guard let contextData = context.data else { return nil }
        let rawBytes = contextData.assumingMemoryBound(to: UInt8.self)

        // Convert to output format with preallocated Data (no intermediate array copy)
        return convertToRGBData(
            rawBytes: rawBytes,
            width: width,
            height: height,
            bytesPerRow: bytesPerRow,
            bytesPerPixel: bytesPerPixel
        )
    }

    /// Converts BGRA pixel data to RGB Data in the specified output format
    /// Uses preallocated Data to avoid intermediate array copies
    private func convertToRGBData(
        rawBytes: UnsafePointer<UInt8>,
        width: Int,
        height: Int,
        bytesPerRow: Int,
        bytesPerPixel: Int
    ) -> Data {
        let pixelCount = width * height

        switch outputDtype {
        case .float32:
            // Preallocate Data with exact size needed (3 floats per pixel)
            let byteCount = pixelCount * 3 * MemoryLayout<Float32>.size
            var data = Data(count: byteCount)

            data.withUnsafeMutableBytes { buffer in
                let floatPtr = buffer.bindMemory(to: Float32.self)
                var floatIndex = 0

                for row in 0 ..< height {
                    for col in 0 ..< width {
                        let offset = row * bytesPerRow + col * bytesPerPixel

                        // Extract RGB from BGRA format (B=0, G=1, R=2, A=3)
                        floatPtr[floatIndex] = Float32(rawBytes[offset + 2]) / 255.0 // R
                        floatPtr[floatIndex + 1] = Float32(rawBytes[offset + 1]) / 255.0 // G
                        floatPtr[floatIndex + 2] = Float32(rawBytes[offset]) / 255.0 // B
                        floatIndex += 3
                    }
                }
            }

            return data

        case .uint8:
            // Preallocate Data with exact size needed (3 bytes per pixel)
            let byteCount = pixelCount * 3
            var data = Data(count: byteCount)

            data.withUnsafeMutableBytes { buffer in
                let uint8Ptr = buffer.bindMemory(to: UInt8.self)
                var byteIndex = 0

                for row in 0 ..< height {
                    for col in 0 ..< width {
                        let offset = row * bytesPerRow + col * bytesPerPixel

                        // Extract RGB from BGRA format
                        uint8Ptr[byteIndex] = rawBytes[offset + 2] // R
                        uint8Ptr[byteIndex + 1] = rawBytes[offset + 1] // G
                        uint8Ptr[byteIndex + 2] = rawBytes[offset] // B
                        byteIndex += 3
                    }
                }
            }

            return data
        }
    }
}
