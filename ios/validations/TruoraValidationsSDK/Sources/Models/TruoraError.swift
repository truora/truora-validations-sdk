//
//  TruoraError.swift
//  TruoraValidationsSDK
//
//  Created by Brayan Escobar on 10/11/25.
//

import Foundation

/// Represents an error that occurred during the validation process.
/// Received in the `onError` callback.
public struct TruoraError: Error, Codable, Equatable {
    public let description: String

    public let currentValidation: String

    public let type: String

    public let code: String

    public init(
        description: String,
        currentValidation: String,
        type: String,
        code: String
    ) {
        self.description = description
        self.currentValidation = currentValidation
        self.type = type
        self.code = code
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case description
        case currentValidation = "current_validation"
        case type
        case code
    }
}
