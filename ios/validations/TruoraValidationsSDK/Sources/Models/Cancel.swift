//
//  Cancel.swift
//  TruoraValidationsSDK
//
//  Created by Brayan Escobar on 10/11/25.
//

import Foundation

/// Represents a user cancellation event.
/// Received in the `onUserCancel` callback.
public struct Cancel: Codable, Equatable {
    public let reason: String

    public let currentValidation: String

    public let currentView: String

    public init(
        reason: String,
        currentValidation: String,
        currentView: String
    ) {
        self.reason = reason
        self.currentValidation = currentValidation
        self.currentView = currentView
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case reason
        case currentValidation = "current_validation"
        case currentView = "current_view"
    }
}
