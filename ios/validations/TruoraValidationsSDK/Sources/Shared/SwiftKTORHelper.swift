//
//  SwiftKTORHelper.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 26/11/25.
//

import Foundation
import TruoraShared

/// Helper utilities for parsing Ktor responses in Swift
enum SwiftKTORHelper {
    /// Parses a Ktor HTTP response into a Decodable Swift type
    ///
    /// - Parameters:
    ///   - response: The Ktor HTTP response to parse
    ///   - type: The target Decodable type to decode into
    /// - Returns: The decoded object of type T
    /// - Throws: ValidationError if parsing fails
    static func parseResponse<T: Decodable>(
        _ response: TruoraShared.Ktor_client_coreHttpResponse,
        as type: T.Type
    ) async throws -> T {
        // Use ResponseParser from KMP module to get body as text
        let bodyText: String
        do {
            bodyText = try await TruoraShared.ResponseParser.shared.bodyAsText(response: response)
        } catch {
            print("❌ SwiftKTORHelper: Failed to read response body: \(error)")
            throw ValidationError.apiError("Failed to read response body: \(error.localizedDescription)")
        }

        guard let data = bodyText.data(using: String.Encoding.utf8) else {
            print("❌ SwiftKTORHelper: Failed to convert response text to UTF-8 data")
            throw ValidationError.apiError("Failed to convert response text to data")
        }

        // Decode JSON
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(type, from: data)
        } catch {
            print("❌ SwiftKTORHelper: Failed to decode response as \(type): \(error)")
            throw ValidationError.apiError("Failed to decode response: \(error.localizedDescription)")
        }
    }
}
