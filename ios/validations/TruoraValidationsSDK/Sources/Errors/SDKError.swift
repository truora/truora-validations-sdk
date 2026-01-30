//
//  SDKError.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 22/01/26.
//

import Foundation

/// Struct representing an SDK error
///
/// Wraps an SDKErrorType with optional additional details
public struct SDKError: Error, LocalizedError, Equatable {
    /// The error type
    public let type: SDKErrorType

    /// Optional additional details about the error
    public var details: String?

    /// Creates an SDK error
    /// - Parameters:
    ///   - type: The error type
    ///   - details: Optional additional details
    public init(type: SDKErrorType, details: String? = nil) {
        self.type = type
        self.details = details
    }

    /// The error code
    public var code: Int {
        type.rawValue
    }

    /// Localized error description
    public var errorDescription: String? {
        if let details {
            "\(type.message)\n\(details)"
        } else {
            type.message
        }
    }
}
