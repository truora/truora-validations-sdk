//
//  TruoraProcessApiError.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 01/07/26.
//

import Foundation

/// Digital Identity (DI) API error, classified into the semantic cases the
/// orchestrator reacts to.
///
/// Whereas ``TruoraProcessAPIError`` is the *transport* enum thrown by ``TruoraProcessAPIClient`` (URLSession
/// failures, raw status codes, input-validation guards), ``TruoraProcessApiError`` is the
/// *classified* error produced by ``TruoraProcessErrorMapper`` from an HTTP status + body.
///
/// Modelled as a `struct` (mirroring the KMP abstract class with a stable
/// ``code``, originating ``httpCode``, ``message`` and parsed
/// ``ApiErrorResponse``) rather than an enum, so associated data can carry
/// sensible defaults via the static factories.
///
/// Retriability is *not* part of the error data (see ``isRetriable``); only
/// transient failures (429, 5xx, network) may be retried.

public struct TruoraProcessApiError: Error, LocalizedError, Equatable {
    /// The specific classified error.
    public enum Kind: Equatable {
        case invalidRequest
        case invalidStep
        case unsupportedStep
        case readOnlyField
        /// HTTP 404 - resource not found.
        case notFound
        /// HTTP 409 - step/block state conflict.
        case conflict
        /// HTTP 410 - the identity process has expired.
        case processExpired
        /// HTTP 429 - rate limit reached. Retriable.
        case rateLimit
        /// HTTP 5xx - server error. Retriable.
        case server
        /// Transport-level failure (no response, timeout, connection reset). Retriable.
        case network
        /// Generic wrapper for unclassified API errors.
        case unknown
    }

    /// The classified error kind.
    public let kind: Kind

    /// Stable SDK error code (mirrors the KMP `TruoraProcessApiError.code`).
    public let code: Int

    /// The originating HTTP status code (`0` for transport-level failures).
    public let httpCode: Int

    /// Human-readable error message.
    public let message: String

    /// The parsed API error response, if available.
    public let apiErrorResponse: ApiErrorResponse?

    /// The underlying transport error for ``Kind/network`` failures, if any.
    public let underlyingError: Error?

    private init(
        kind: Kind,
        code: Int,
        httpCode: Int,
        message: String,
        apiErrorResponse: ApiErrorResponse? = nil,
        underlyingError: Error? = nil
    ) {
        self.kind = kind
        self.code = code
        self.httpCode = httpCode
        self.message = message
        self.apiErrorResponse = apiErrorResponse
        self.underlyingError = underlyingError
    }

    /// Only transient failures are retriable: rate limiting (``Kind/rateLimit`` /
    /// 429), server errors (``Kind/server`` / 5xx) and transport failures
    /// (``Kind/network``). All other errors are deterministic given the same
    /// request and must not be retried.
    public var isRetriable: Bool {
        switch kind {
        case .rateLimit, .server, .network:
            true
        default:
            false
        }
    }

    public var errorDescription: String? {
        httpCode > 0 ? "\(message)\nhttp code: \(httpCode)" : message
    }

    // MARK: - Factories (mirror KMP data classes)

    /// HTTP 400 - missing or invalid parameters.
    public static func invalidRequest(apiError: ApiErrorResponse? = nil) -> TruoraProcessApiError {
        TruoraProcessApiError(
            kind: .invalidRequest,
            code: 11400,
            httpCode: 400,
            message: "Invalid request: missing or invalid parameters",
            apiErrorResponse: apiError
        )
    }

    /// The current step does not match the step being verified.
    public static func invalidStep(apiError: ApiErrorResponse? = nil) -> TruoraProcessApiError {
        TruoraProcessApiError(
            kind: .invalidStep,
            code: 11401,
            httpCode: 409,
            message: "Invalid current step",
            apiErrorResponse: apiError
        )
    }

    /// The step type is an invalid step.
    public static func unsupportedStep(apiError: ApiErrorResponse? = nil) -> TruoraProcessApiError {
        TruoraProcessApiError(
            kind: .unsupportedStep,
            code: 11402,
            httpCode: 400,
            message: "Invalid step type",
            apiErrorResponse: apiError
        )
    }

    /// A read-only field was modified.
    public static func readOnlyField(apiError: ApiErrorResponse? = nil) -> TruoraProcessApiError {
        TruoraProcessApiError(
            kind: .readOnlyField,
            code: 11403,
            httpCode: 400,
            message: "The field is read only",
            apiErrorResponse: apiError
        )
    }

    /// HTTP 404 - resource not found.
    public static func notFound(apiError: ApiErrorResponse? = nil) -> TruoraProcessApiError {
        TruoraProcessApiError(
            kind: .notFound,
            code: 11404,
            httpCode: 404,
            message: "Resource not found",
            apiErrorResponse: apiError
        )
    }

    /// HTTP 409 - step/block state conflict.
    public static func conflict(apiError: ApiErrorResponse? = nil) -> TruoraProcessApiError {
        TruoraProcessApiError(
            kind: .conflict,
            code: 11409,
            httpCode: 409,
            message: "Step or block state conflict",
            apiErrorResponse: apiError
        )
    }

    /// HTTP 410 - the identity process has expired.
    public static func processExpired(apiError: ApiErrorResponse? = nil) -> TruoraProcessApiError {
        TruoraProcessApiError(
            kind: .processExpired,
            code: 11410,
            httpCode: 410,
            message: "The identity process has expired",
            apiErrorResponse: apiError
        )
    }

    /// HTTP 429 - rate limit reached. Retriable.
    public static func rateLimit(apiError: ApiErrorResponse? = nil) -> TruoraProcessApiError {
        TruoraProcessApiError(
            kind: .rateLimit,
            code: 11429,
            httpCode: 429,
            message: "Max rate limit reached",
            apiErrorResponse: apiError
        )
    }

    /// HTTP 5xx - server error. Retriable.
    public static func server(httpCode: Int = 500, apiError: ApiErrorResponse? = nil) -> TruoraProcessApiError {
        TruoraProcessApiError(
            kind: .server,
            code: 11500,
            httpCode: httpCode,
            message: "Server error",
            apiErrorResponse: apiError
        )
    }

    /// Transport-level failure (no response, timeout, connection reset). Retriable.
    public static func network(
        message: String = "Network error",
        underlyingError: Error? = nil,
        apiError: ApiErrorResponse? = nil
    ) -> TruoraProcessApiError {
        TruoraProcessApiError(
            kind: .network,
            code: 11000,
            httpCode: 0,
            message: message,
            apiErrorResponse: apiError,
            underlyingError: underlyingError
        )
    }

    /// Generic wrapper for unclassified API errors.
    public static func unknown(
        httpCode: Int, message: String, apiError: ApiErrorResponse? = nil
    ) -> TruoraProcessApiError {
        TruoraProcessApiError(
            kind: .unknown,
            code: 11999,
            httpCode: httpCode,
            message: message,
            apiErrorResponse: apiError
        )
    }

    // MARK: - Equatable

    /// Compares by classification and data; the non-`Equatable` ``underlyingError``
    /// is ignored (matching ``TruoraException``'s convention).
    public static func == (lhs: TruoraProcessApiError, rhs: TruoraProcessApiError) -> Bool {
        lhs.kind == rhs.kind &&
            lhs.code == rhs.code &&
            lhs.httpCode == rhs.httpCode &&
            lhs.message == rhs.message &&
            lhs.apiErrorResponse == rhs.apiErrorResponse
    }
}
