import Foundation
import UIKit

/// Represents media captured during the validation process
public struct CapturedMedia: Equatable {
    /// The type of media that was captured
    public let type: MediaType

    /// The captured image (for photo captures)
    public let image: UIImage?

    /// The captured video data (for video captures)
    public let videoData: Data?

    /// The URL to the captured video file (for video captures)
    public let videoURL: URL?

    /// Metadata about the capture
    public let metadata: CaptureMetadata?

    /// Timestamp when the media was captured
    public let timestamp: Date

    public init(
        type: MediaType,
        image: UIImage? = nil,
        videoData: Data? = nil,
        videoURL: URL? = nil,
        metadata: CaptureMetadata? = nil,
        timestamp: Date = Date()
    ) {
        self.type = type
        self.image = image
        self.videoData = videoData
        self.videoURL = videoURL
        self.metadata = metadata
        self.timestamp = timestamp
    }

    public static func == (lhs: CapturedMedia, rhs: CapturedMedia) -> Bool {
        lhs.type == rhs.type &&
            lhs.videoURL == rhs.videoURL &&
            lhs.timestamp == rhs.timestamp &&
            lhs.metadata == rhs.metadata
    }
}

/// Types of media that can be captured
public enum MediaType: String, Codable {
    case photo
    case video
}

/// Metadata about the captured media
public struct CaptureMetadata: Codable, Equatable {
    /// Duration of the capture (for videos)
    public let duration: TimeInterval?

    /// Resolution of the captured media
    public let resolution: CGSize?

    /// File size in bytes
    public let fileSize: Int?

    /// Additional custom metadata
    public let additionalInfo: [String: String]?

    public init(
        duration: TimeInterval? = nil,
        resolution: CGSize? = nil,
        fileSize: Int? = nil,
        additionalInfo: [String: String]? = nil
    ) {
        self.duration = duration
        self.resolution = resolution
        self.fileSize = fileSize
        self.additionalInfo = additionalInfo
    }
}
