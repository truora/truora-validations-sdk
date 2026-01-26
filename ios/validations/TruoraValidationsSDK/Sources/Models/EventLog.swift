//
//  EventLog.swift
//  TruoraValidationsSDK
//
//  Created by Brayan Escobar on 10/11/25.
//

import Foundation

/// Represents a generic event log for analytics or debugging.
/// Received in the `logger` callback.
public struct EventLog: Codable, Equatable {
    public let name: String

    public let currentView: String

    public let date: String

    public init(
        name: String,
        currentView: String,
        date: String
    ) {
        self.name = name
        self.currentView = currentView
        self.date = date
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case name
        case currentView = "current_view"
        case date
    }
}
