//
//  TruoraProcessErrorMapper.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 01/07/26.
//

import Foundation

/// Maps DI API responses and transport failures to a classified ``TruoraProcessApiError``.
///
/// Mapping precedence:
/// 1. Semantic message markers (invalid step type, invalid current step,
///    read-only field, ...), because the backend returns these distinct cases
///    under the same generic 4xx status.
/// 2. HTTP status code (400/404/409/410/429/5xx).
public enum TruoraProcessErrorMapper {
    // Lowercase markers matched against the backend error message.
    private static let markerMissingParams = "missing params"
    private static let markerInvalidCurrentStep = "invalid current step"
    private static let markerInvalidStepType = "invalid step type"
    private static let markerReadOnly = "the field is read only"
    private static let markerProcessExpired = "process expired"
    private static let markerRateLimit = "max rate limit reached"

    private static let serverErrorRange = 500 ... 599

    private static let decoder = JSONDecoder()

    // MARK: - Public API

    /// Maps an HTTP status code and optional response body to a ``TruoraProcessApiError``.
    public static func from(httpCode: Int, responseBody: String?) -> TruoraProcessApiError {
        let apiError = parseApiError(responseBody)
        return mapByMessage(apiError?.message, apiError: apiError)
            ?? mapByStatus(httpCode, apiError: apiError)
    }

    /// Maps an already-parsed ``ApiErrorResponse`` body to a ``TruoraProcessApiError``.
    public static func from(apiError: ApiErrorResponse) -> TruoraProcessApiError {
        mapByMessage(apiError.message, apiError: apiError)
            ?? mapByStatus(apiError.httpCode, apiError: apiError)
    }

    /// Maps a thrown error to a ``TruoraProcessApiError``.
    public static func from(error: Error) -> TruoraProcessApiError {
        if let diApiError = error as? TruoraProcessApiError {
            return diApiError
        }

        if let transport = error as? TruoraProcessAPIError {
            return from(transport: transport)
        }

        if let urlError = error as? URLError {
            return .network(message: urlError.localizedDescription, underlyingError: urlError)
        }

        return .network(message: error.localizedDescription, underlyingError: error)
    }

    // MARK: - Private Helpers

    private static func from(transport: TruoraProcessAPIError) -> TruoraProcessApiError {
        switch transport {
        case .serverError(let statusCode, let body):
            from(httpCode: statusCode, responseBody: body)
        case .unauthorized(let body):
            from(httpCode: 401, responseBody: body)
        case .networkError(let underlying), .uploadFailed(let underlying):
            .network(message: underlying.localizedDescription, underlyingError: underlying)
        case .invalidResponse:
            .network(message: "Invalid response from server")
        // Deterministic client-side failures: never retriable.
        case .invalidURL,
             .encodingError,
             .decodingError,
             .emptyProcessId,
             .emptyStepId,
             .emptyUploadUrl,
             .emptyFileData:
            .unknown(httpCode: 0, message: transport.errorDescription ?? "Unknown error")
        }
    }

    private static func mapByMessage(_ message: String?, apiError: ApiErrorResponse?) -> TruoraProcessApiError? {
        guard let message, !message.isEmpty else {
            return nil
        }

        let normalized = message.lowercased()
        if normalized.contains(markerReadOnly) {
            return .readOnlyField(apiError: apiError)
        }
        if normalized.contains(markerInvalidStepType) {
            return .unsupportedStep(apiError: apiError)
        }
        if normalized.contains(markerInvalidCurrentStep) {
            return .invalidStep(apiError: apiError)
        }
        if normalized.contains(markerProcessExpired) {
            return .processExpired(apiError: apiError)
        }
        if normalized.contains(markerRateLimit) {
            return .rateLimit(apiError: apiError)
        }
        if normalized.contains(markerMissingParams) {
            return .invalidRequest(apiError: apiError)
        }
        return nil
    }

    private static func mapByStatus(_ httpCode: Int, apiError: ApiErrorResponse?) -> TruoraProcessApiError {
        switch httpCode {
        case 400:
            .invalidRequest(apiError: apiError)
        case 404:
            .notFound(apiError: apiError)
        case 409:
            .conflict(apiError: apiError)
        case 410:
            .processExpired(apiError: apiError)
        case 429:
            .rateLimit(apiError: apiError)
        case serverErrorRange:
            .server(httpCode: httpCode, apiError: apiError)
        default:
            .unknown(httpCode: httpCode, message: apiError?.message ?? "Unknown error", apiError: apiError)
        }
    }

    private static func parseApiError(_ responseBody: String?) -> ApiErrorResponse? {
        guard let responseBody, !responseBody.isEmpty, let data = responseBody.data(using: .utf8) else {
            return nil
        }
        return try? decoder.decode(ApiErrorResponse.self, from: data)
    }
}
