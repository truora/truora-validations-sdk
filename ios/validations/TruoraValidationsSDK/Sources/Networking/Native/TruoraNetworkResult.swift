//
//  TruoraNetworkResult.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 01/07/26.
//

import Foundation

/// Outcome of a Digital Identity request executed through ``TruoraProcessRequestExecutor``.
///
/// Either a ``success(_:)`` carrying the produced value, or a ``failure(_:)`` carrying the
/// mapped ``TruoraProcessApiError``. This keeps recoverable API/transport failures off the
/// exception path so callers can handle them exhaustively.
public enum TruoraNetworkResult<Success> {
    /// The request completed successfully with the given value.
    case success(Success)

    /// The request failed (after exhausting retries, if any) with the given error.
    case failure(TruoraProcessApiError)

    public var isSuccess: Bool {
        if case .success = self {
            return true
        }
        return false
    }

    public var isFailure: Bool {
        !isSuccess
    }

    /// The success value, or `nil` if this is a ``failure(_:)``.
    public var value: Success? {
        if case .success(let value) = self {
            return value
        }
        return nil
    }

    /// The error, or `nil` if this is a ``success(_:)``.
    public var error: TruoraProcessApiError? {
        if case .failure(let error) = self {
            return error
        }
        return nil
    }

    /// Folds this result into a single value by applying `onSuccess` or `onFailure`.
    public func fold<T>(onSuccess: (Success) -> T, onFailure: (TruoraProcessApiError) -> T) -> T {
        switch self {
        case .success(let value):
            onSuccess(value)
        case .failure(let error):
            onFailure(error)
        }
    }
}
