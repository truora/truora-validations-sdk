import Foundation

/// Represents the result of a validation operation
/// - complete: Validation completed successfully with a result of type T
/// - failure: Validation failed with a ValidationError
/// - capture: Media was captured during validation
public enum TruoraValidationResult<T> {
    case complete(T)
    case failure(ValidationError)
    case capture(CapturedMedia)
}

// MARK: - Equatable conformance (when T is Equatable)

extension TruoraValidationResult: Equatable where T: Equatable {
    public static func == (lhs: TruoraValidationResult<T>, rhs: TruoraValidationResult<T>) -> Bool {
        switch (lhs, rhs) {
        case (.complete(let lhsValue), .complete(let rhsValue)):
            lhsValue == rhsValue
        case (.failure(let lhsError), .failure(let rhsError)):
            lhsError == rhsError
        case (.capture(let lhsMedia), .capture(let rhsMedia)):
            lhsMedia == rhsMedia
        default:
            false
        }
    }
}

// MARK: - CustomStringConvertible

extension TruoraValidationResult: CustomStringConvertible {
    public var description: String {
        switch self {
        case .complete(let value):
            "TruoraValidationResult.complete(\(value))"
        case .failure(let error):
            "TruoraValidationResult.failure(\(error.localizedDescription))"
        case .capture(let media):
            "TruoraValidationResult.capture(\(media))"
        }
    }
}

// MARK: - Convenience Properties

public extension TruoraValidationResult {
    /// Returns true if the result is a completion
    var isComplete: Bool {
        if case .complete = self { return true }
        return false
    }

    /// Returns true if the result is a failure
    var isFailure: Bool {
        if case .failure = self { return true }
        return false
    }

    /// Returns true if the result is a capture
    var isCapture: Bool {
        if case .capture = self { return true }
        return false
    }

    /// Extracts the completion value if available
    var completionValue: T? {
        if case .complete(let value) = self { return value }
        return nil
    }

    /// Extracts the error if this is a failure
    var error: ValidationError? {
        if case .failure(let error) = self { return error }
        return nil
    }

    /// Extracts the captured media if available
    var capturedMedia: CapturedMedia? {
        if case .capture(let media) = self { return media }
        return nil
    }
}
