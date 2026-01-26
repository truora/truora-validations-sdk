//
//  ReferenceFace.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 17/11/25.
//

import Foundation

/// Represents a reference face image for face comparison validations.
///
/// Usage:
/// ```swift
/// let ref1 = try ReferenceFace.from("https://example.com/face.jpg")
/// let ref2 = try ReferenceFace.from("/path/to/file.jpg")
/// let ref3 = ReferenceFace.from(myData)
///
/// // Get URL for upload (can be remote URL or local file):
/// let url = ref1.url
/// ```
public final class ReferenceFace {
    /// The URL pointing to the reference face.
    /// Can be a remote URL (http/https) or local file URL (file://).
    public let url: URL

    private let isTemporary: Bool

    private init(url: URL, isTemporary: Bool = false) {
        self.url = url
        self.isTemporary = isTemporary
    }

    deinit {
        if isTemporary {
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Factory Methods

    /// Creates a reference face from a String.
    ///
    /// - Parameter source: URL string or file path
    /// - Returns: A ReferenceFace instance
    /// - Throws: ReferenceFaceError.invalidArgument if source is empty
    public static func from(_ source: String) throws -> ReferenceFace {
        guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ReferenceFaceError.invalidArgument("Source cannot be null or empty")
        }

        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)

        if let url = URL(string: trimmed), url.scheme != nil {
            return ReferenceFace(url: url)
        }

        return ReferenceFace(url: URL(fileURLWithPath: trimmed))
    }

    /// Creates a reference face from a URL.
    ///
    /// - Parameter url: URL pointing to the reference face (remote or local)
    /// - Returns: A ReferenceFace instance
    public static func from(_ url: URL) -> ReferenceFace {
        ReferenceFace(url: url)
    }

    /// Creates a reference face from a file path.
    ///
    /// - Parameter filePath: File path string
    /// - Returns: A ReferenceFace instance
    /// - Throws: ReferenceFaceError.invalidArgument if path is empty
    public static func from(filePath: String) throws -> ReferenceFace {
        guard !filePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ReferenceFaceError.invalidArgument("Path cannot be null or empty")
        }
        return ReferenceFace(url: URL(fileURLWithPath: filePath))
    }

    /// Creates a reference face from an InputStream.
    ///
    /// - Parameter stream: InputStream containing image data
    /// - Returns: A ReferenceFace instance
    /// - Throws: ReferenceFaceError.conversionFailed if stream cannot be read
    public static func from(_ stream: InputStream) throws -> ReferenceFace {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg")

        let wasNotOpen = stream.streamStatus == .notOpen
        if wasNotOpen {
            stream.open()
        }
        defer {
            if wasNotOpen {
                stream.close()
            }
        }

        guard let outputStream = OutputStream(url: tempURL, append: false) else {
            throw ReferenceFaceError.conversionFailed("Failed to create output stream")
        }

        outputStream.open()
        defer { outputStream.close() }

        let bufferSize = 8192
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while stream.hasBytesAvailable {
            let bytesRead = stream.read(buffer, maxLength: bufferSize)
            if bytesRead < 0 {
                try? FileManager.default.removeItem(at: tempURL)
                throw ReferenceFaceError.conversionFailed("Failed to read from InputStream")
            }
            if bytesRead == 0 {
                break
            }

            let bytesWritten = outputStream.write(buffer, maxLength: bytesRead)
            if bytesWritten < 0 {
                try? FileManager.default.removeItem(at: tempURL)
                throw ReferenceFaceError.conversionFailed("Failed to write to temporary file")
            }
        }

        return ReferenceFace(url: tempURL, isTemporary: true)
    }

    /// Creates a reference face from Data.
    ///
    /// - Parameter data: Data containing image
    /// - Returns: A ReferenceFace instance
    public static func from(_ data: Data) -> ReferenceFace {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg")

        do {
            try data.write(to: tempURL, options: .atomic)
            return ReferenceFace(url: tempURL, isTemporary: true)
        } catch {
            fatalError("Failed to write to temporary directory: \(error)")
        }
    }
}

// MARK: - Error Types

public enum ReferenceFaceError: LocalizedError {
    case invalidArgument(String)
    case conversionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidArgument(let message):
            "Invalid argument: \(message)"
        case .conversionFailed(let message):
            "Conversion failed: \(message)"
        }
    }
}
