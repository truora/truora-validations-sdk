import Foundation

/// Represents the result of a validation operation
/// - completed: Validation process finished with a result of type T
/// - error: SDK error occurred with a TruoraException
/// - canceled: Validation was canceled by the user, with an optional partial result
public enum TruoraValidationResult<T> {
    case completed(T)
    case error(TruoraException)
    case canceled(T?)
}

// MARK: - Equatable conformance (when T is Equatable)

extension TruoraValidationResult: Equatable where T: Equatable {
    public static func == (lhs: TruoraValidationResult<T>, rhs: TruoraValidationResult<T>) -> Bool {
        switch (lhs, rhs) {
        case (.completed(let lhsValue), .completed(let rhsValue)):
            lhsValue == rhsValue
        case (.error(let lhsError), .error(let rhsError)):
            lhsError == rhsError
        case (.canceled(let lhsValue), .canceled(let rhsValue)):
            lhsValue == rhsValue
        default:
            false
        }
    }
}

// MARK: - CustomStringConvertible

extension TruoraValidationResult: CustomStringConvertible {
    public var description: String {
        switch self {
        case .completed(let value):
            "TruoraValidationResult.completed(\(value))"
        case .error(let error):
            "TruoraValidationResult.error(\(error.localizedDescription))"
        case .canceled(let value):
            "TruoraValidationResult.canceled(\(String(describing: value)))"
        }
    }
}

// MARK: - Convenience Properties

public extension TruoraValidationResult {
    /// Returns true if the result is a completion
    var isCompleted: Bool {
        if case .completed = self {
            return true
        }
        return false
    }

    /// Returns true if the result is an error
    var isError: Bool {
        if case .error = self {
            return true
        }
        return false
    }

    /// Returns true if the result is a cancellation
    var isCanceled: Bool {
        if case .canceled = self {
            return true
        }
        return false
    }

    /// Extracts the completion value if available
    var completionValue: T? {
        if case .completed(let value) = self {
            return value
        }
        return nil
    }

    /// Extracts the exception if this is an error
    var exception: TruoraException? {
        if case .error(let error) = self {
            return error
        }
        return nil
    }

    /// Extracts the partial validation result if this is a cancellation
    var canceledValue: T? {
        if case .canceled(let value) = self {
            return value
        }
        return nil
    }
}
