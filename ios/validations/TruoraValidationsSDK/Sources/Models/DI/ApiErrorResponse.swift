//
//  ApiErrorResponse.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 01/07/26.
//

import Foundation

/// Raw error body returned by the Digital Identity (DI) Processes API.
///
/// Parsed from a non-2xx response body and carried inside ``TruoraProcessApiError`` so callers can
/// inspect the backend-provided `code` / `message` when needed.
public struct ApiErrorResponse: Codable, Equatable {
    public let code: String
    public let httpCode: Int
    public let message: String

    public init(code: String, httpCode: Int, message: String) {
        self.code = code
        self.httpCode = httpCode
        self.message = message
    }

    private enum CodingKeys: String, CodingKey {
        case code
        case httpCode = "http_code"
        case message
    }
}
