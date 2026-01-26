//
//  LogoDownloader.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 06/01/26.
//

import Foundation

protocol LogoDownloading {
    @discardableResult
    func downloadLogo(from url: URL, completion: @escaping (Result<Data, Error>) -> Void) -> URLSessionDataTask?
    func downloadLogoSync(from url: URL) -> Result<Data, Error>
}

enum LogoDownloaderError: LocalizedError, Equatable {
    case invalidUrl
    case insecureUrl
    case invalidResponse
    case httpError(statusCode: Int)
    case invalidContentType(String)
    case invalidImageData
    case sizeExceeded(maxBytes: Int)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .invalidUrl:
            "Invalid URL"
        case .insecureUrl:
            "URL must use https scheme for security"
        case .invalidResponse:
            "Invalid response"
        case .httpError(let statusCode):
            "Unexpected HTTP status code: \(statusCode)"
        case .invalidContentType(let type):
            "URL did not return an image. Content-Type: \(type)"
        case .invalidImageData:
            "Data does not appear to be a valid image"
        case .sizeExceeded(let maxBytes):
            "Logo size exceeds maximum allowed (\(maxBytes) bytes)"
        case .cancelled:
            "Request was cancelled"
        }
    }
}

final class LogoDownloader: LogoDownloading {
    private static let maxLogoSizeBytes: Int = 5 * 1024 * 1024 // 5MB

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    private func isValidImageData(_ data: Data) -> Bool {
        guard data.count >= 4 else { return false }

        let bytes = [UInt8](data.prefix(12))

        // PNG: 89 50 4E 47 0D 0A 1A 0A
        if bytes.count >= 8, bytes[0] == 0x89, bytes[1] == 0x50, bytes[2] == 0x4E, bytes[3] == 0x47 {
            return true
        }

        // JPEG: FF D8 FF
        if bytes[0] == 0xFF, bytes[1] == 0xD8, bytes[2] == 0xFF {
            return true
        }

        // GIF: "GIF87a" or "GIF89a"
        if bytes.count >= 6, bytes[0] == 0x47, bytes[1] == 0x49, bytes[2] == 0x46,
           bytes[3] == 0x38, bytes[4] == 0x37 || bytes[4] == 0x39, bytes[5] == 0x61 {
            return true
        }

        // WebP: "RIFF....WEBP"
        if bytes.count >= 12, bytes[0] == 0x52, bytes[1] == 0x49, bytes[2] == 0x46, bytes[3] == 0x46,
           bytes[8] == 0x57, bytes[9] == 0x45, bytes[10] == 0x42, bytes[11] == 0x50 {
            return true
        }

        // SVG: Check for XML declaration or <svg tag
        if let string = String(data: data.prefix(256), encoding: .utf8) {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("<?xml") || trimmed.hasPrefix("<svg") {
                return true
            }
        }

        return false
    }

    private func validateResponse(
        data: Data?,
        response: URLResponse?,
        error: Error?
    ) -> Result<Data, Error> {
        if let urlError = error as? URLError, urlError.code == .cancelled {
            return .failure(LogoDownloaderError.cancelled)
        }

        if let error {
            return .failure(error)
        }

        guard let http = response as? HTTPURLResponse else {
            return .failure(LogoDownloaderError.invalidResponse)
        }

        guard (200 ... 299).contains(http.statusCode) else {
            return .failure(LogoDownloaderError.httpError(statusCode: http.statusCode))
        }

        let contentType = (http.value(forHTTPHeaderField: "Content-Type") ?? http.mimeType ?? "").lowercased()
        guard !contentType.isEmpty, contentType.hasPrefix("image/") else {
            return .failure(LogoDownloaderError.invalidContentType(contentType))
        }

        let expected = http.expectedContentLength
        if expected > 0, expected > Int64(Self.maxLogoSizeBytes) {
            return .failure(LogoDownloaderError.sizeExceeded(maxBytes: Self.maxLogoSizeBytes))
        }

        guard let data else {
            return .failure(LogoDownloaderError.invalidResponse)
        }

        guard !data.isEmpty else {
            return .failure(LogoDownloaderError.invalidResponse)
        }

        guard data.count <= Self.maxLogoSizeBytes else {
            return .failure(LogoDownloaderError.sizeExceeded(maxBytes: Self.maxLogoSizeBytes))
        }

        guard isValidImageData(data) else {
            return .failure(LogoDownloaderError.invalidImageData)
        }

        return .success(data)
    }

    @discardableResult
    func downloadLogo(from url: URL, completion: @escaping (Result<Data, Error>) -> Void) -> URLSessionDataTask? {
        guard let scheme = url.scheme?.lowercased(), scheme == "https" else {
            completion(.failure(LogoDownloaderError.insecureUrl))
            return nil
        }

        let task = session.dataTask(with: url) { data, response, error in
            let result = self.validateResponse(data: data, response: response, error: error)
            completion(result)
        }

        task.resume()
        return task
    }

    func downloadLogoSync(from url: URL) -> Result<Data, Error> {
        guard let scheme = url.scheme?.lowercased(), scheme == "https" else {
            return .failure(LogoDownloaderError.insecureUrl)
        }

        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<Data, Error>?

        let task = session.dataTask(with: url) { data, response, error in
            defer { semaphore.signal() }
            result = self.validateResponse(data: data, response: response, error: error)
        }

        task.resume()
        semaphore.wait()

        return result ?? .failure(LogoDownloaderError.invalidResponse)
    }
}
