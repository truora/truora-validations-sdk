//
//  TruoraProcessStatus.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 07/07/26.
//

import Foundation

// MARK: - DI Process Status

/// Terminal status of a Digital Identity *process* (not a single block).
///
/// Deliberately its own type rather than reusing ``TruoraBlockStatus``:
/// although the raw values currently coincide, the process- and block-level
/// lifecycles are independent and may diverge. Its shape mirrors the KMP
/// process runner's `ProcessStatus` (PROC-6965) 1:1; the type name follows iOS
/// conventions and deliberately differs from KMP's.
enum TruoraProcessStatus: String, Codable {
    case pending
    case success
    case failure
}
