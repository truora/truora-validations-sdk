//
//  TruoraSessionConfiguration.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 27/01/26.
//

import Foundation

/// Configuration for URLSession with retry logic and timeout settings optimized for mobile networks.
///
/// Provides a centralized way to configure HTTP behavior across all networking components,
/// including automatic retry with exponential backoff for transient errors.
public struct TruoraSessionConfiguration: Sendable {
    // MARK: - Configuration Properties

    /// Timeout for waiting for data between packets (resets on each received packet).
    /// Default: 30 seconds
    public let timeoutIntervalForRequest: TimeInterval

    /// Maximum total time for the entire request to complete.
    /// Default: 300 seconds (5 minutes)
    public let timeoutIntervalForResource: TimeInterval

    /// Whether to wait for connectivity before failing.
    /// When true, requests wait for network instead of failing immediately.
    /// Default: true
    public let waitsForConnectivity: Bool

    /// Maximum number of retries after the initial request fails.
    /// Total attempts = 1 (initial) + maxRetries.
    /// Default: 3 (meaning 4 total attempts)
    public let maxRetries: Int

    /// Base delay for exponential backoff (in seconds).
    /// Actual delays: base, base*2, base*4, etc.
    /// Default: 1.0 second
    public let retryBaseDelay: TimeInterval

    /// Maximum delay between retries (caps exponential growth).
    /// Default: 10 seconds
    public let retryMaxDelay: TimeInterval

    // MARK: - Initialization

    /// Creates a session configuration with custom settings.
    public init(
        timeoutIntervalForRequest: TimeInterval = 30,
        timeoutIntervalForResource: TimeInterval = 300,
        waitsForConnectivity: Bool = true,
        maxRetries: Int = 3,
        retryBaseDelay: TimeInterval = 1.0,
        retryMaxDelay: TimeInterval = 10.0
    ) {
        self.timeoutIntervalForRequest = timeoutIntervalForRequest
        self.timeoutIntervalForResource = timeoutIntervalForResource
        self.waitsForConnectivity = waitsForConnectivity
        self.maxRetries = maxRetries
        self.retryBaseDelay = retryBaseDelay
        self.retryMaxDelay = retryMaxDelay
    }

    // MARK: - Default Configuration

    /// Default configuration optimized for mobile networks with poor connectivity.
    public static let `default` = TruoraSessionConfiguration()

    /// Configuration with no retries (for testing or specific use cases).
    public static let noRetry = TruoraSessionConfiguration(maxRetries: 0)

    // MARK: - Session Creation

    /// Creates a configured URLSession based on this configuration.
    public func createSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeoutIntervalForRequest
        config.timeoutIntervalForResource = timeoutIntervalForResource
        config.waitsForConnectivity = waitsForConnectivity
        return URLSession(configuration: config)
    }

    // MARK: - Request Execution with Retry

    /// Performs a request with automatic retry for transient errors.
    ///
    /// Retries are attempted for:
    /// - Network errors: timeout, connection lost, not connected, cannot connect to host
    /// - Server errors: 408 (Request Timeout), 429 (Too Many Requests), 500, 502, 503, 504
    ///
    /// - Parameters:
    ///   - request: The URLRequest to perform
    ///   - session: The URLSession to use (defaults to a new session from this configuration)
    /// - Returns: Tuple of (Data, URLResponse)
    /// - Throws: The last error if all retries fail
    public func perform(
        _ request: URLRequest,
        using session: URLSession? = nil
    ) async throws -> (Data, URLResponse) {
        let isTemporarySession = session == nil
        let urlSession = session ?? createSession()
        defer {
            if isTemporarySession {
                urlSession.finishTasksAndInvalidate()
            }
        }
        var lastError: Error?

        // attempt 0 = initial request, attempts 1...maxRetries = retries
        for attempt in 0 ... maxRetries {
            do {
                let (data, response) = try await urlSession.data(for: request)

                // Check for retryable HTTP status codes
                if let httpResponse = response as? HTTPURLResponse,
                   isRetryableStatusCode(httpResponse.statusCode) {
                    if attempt < maxRetries {
                        let delay = calculateDelay(for: attempt)
                        logRetryableResponse(
                            attempt: attempt,
                            statusCode: httpResponse.statusCode,
                            body: data,
                            delay: delay
                        )
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        continue
                    }
                }

                return (data, response)
            } catch {
                lastError = error

                guard isRetryableError(error), attempt < maxRetries else {
                    throw error
                }

                let delay = calculateDelay(for: attempt)
                logRetry(attempt: attempt, reason: error.localizedDescription, delay: delay)
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }

        throw lastError ?? URLError(.unknown)
    }

    /// Performs a request to a URL with automatic retry (convenience for simple GET requests).
    public func perform(
        from url: URL,
        using session: URLSession? = nil
    ) async throws -> (Data, URLResponse) {
        try await perform(URLRequest(url: url), using: session)
    }

    // MARK: - Private Helpers

    private func isRetryableError(_ error: Error) -> Bool {
        guard let urlError = error as? URLError else {
            return false
        }

        let retryableCodes: Set<URLError.Code> = [
            .timedOut,
            .networkConnectionLost,
            .notConnectedToInternet,
            .cannotConnectToHost,
            .cannotFindHost,
            .dnsLookupFailed,
            .internationalRoamingOff,
            .dataNotAllowed
        ]

        return retryableCodes.contains(urlError.code)
    }

    private func isRetryableStatusCode(_ statusCode: Int) -> Bool {
        let retryableCodes: Set = [
            408, // Request Timeout
            429, // Too Many Requests
            500, // Internal Server Error
            502, // Bad Gateway
            503, // Service Unavailable
            504 // Gateway Timeout
        ]

        return retryableCodes.contains(statusCode)
    }

    private func calculateDelay(for attempt: Int) -> TimeInterval {
        let delay = retryBaseDelay * pow(2.0, Double(attempt))
        return min(delay, retryMaxDelay)
    }

    private func logRetry(attempt: Int, reason: String, delay: TimeInterval) {
        let delayStr = String(format: "%.1f", delay)
        debugLog("⚠️ TruoraSession: Retry \(attempt + 1)/\(maxRetries) after \(delayStr)s - \(reason)")
    }

    private func logRetryableResponse(attempt: Int, statusCode: Int, body: Data, delay: TimeInterval) {
        let delayStr = String(format: "%.1f", delay)
        var message = "⚠️ TruoraSession: Retry \(attempt + 1)/\(maxRetries) after \(delayStr)s - HTTP \(statusCode)"

        // Log response body for server errors (5xx) - useful for debugging
        if statusCode >= 500, let bodyString = String(data: body.prefix(500), encoding: .utf8), !bodyString.isEmpty {
            message += " | Body: \(bodyString)"
        }

        debugLog(message)
    }
}

// MARK: - Protocol for Testing

/// Protocol for abstracting session configuration behavior in tests.
public protocol SessionConfigurationProtocol {
    func perform(_ request: URLRequest, using session: URLSession?) async throws -> (Data, URLResponse)
    func perform(from url: URL, using session: URLSession?) async throws -> (Data, URLResponse)
    func createSession() -> URLSession
}

extension TruoraSessionConfiguration: SessionConfigurationProtocol {}
