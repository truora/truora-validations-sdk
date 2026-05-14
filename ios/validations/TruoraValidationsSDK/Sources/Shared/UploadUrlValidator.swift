//
//  UploadUrlValidator.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 30/01/26.
//

import Foundation

/// Utility to check if a pre-signed S3 upload URL has expired.
/// Pre-signed URLs contain an `Expires` parameter with the Unix timestamp of expiration.
enum UploadUrlValidator {
    /// Allowed prefix for file upload URLs (Truora-controlled domain only).
    static let truoraFilesUploadURLPrefix = "https://files.truora.com/"

    /// Returns `true` when the URL targets Truora's file domain (avoids uploading to arbitrary hosts).
    static func isTruoraFilesUploadUrl(_ urlString: String?) -> Bool {
        guard let urlString, !urlString.isEmpty else {
            return false
        }
        return urlString.hasPrefix(truoraFilesUploadURLPrefix)
    }

    /// Checks if the given pre-signed URL has expired.
    /// - Parameters:
    ///   - urlString: The pre-signed S3 URL string
    ///   - currentTimestamp: The current Unix timestamp (injectable for testing)
    /// - Returns: `true` if the URL expired, `false` if valid or undetermined
    static func isExpired(
        _ urlString: String,
        currentTimestamp: TimeInterval = Date().timeIntervalSince1970
    ) -> Bool {
        guard let expirationTimestamp = getExpirationTimestamp(from: urlString) else {
            return false
        }

        return currentTimestamp >= expirationTimestamp
    }

    /// Extracts the expiration timestamp from a pre-signed URL.
    /// - Parameter urlString: The pre-signed S3 URL string
    /// - Returns: The Unix timestamp when the URL expires, or nil if not found
    static func getExpirationTimestamp(from urlString: String) -> TimeInterval? {
        guard let url = URL(string: urlString),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return nil
        }

        // Look for "Expires" parameter (Unix timestamp)
        for item in queryItems where item.name == "Expires" {
            if let value = item.value, let timestamp = TimeInterval(value) {
                return timestamp
            }
        }

        return nil
    }
}
