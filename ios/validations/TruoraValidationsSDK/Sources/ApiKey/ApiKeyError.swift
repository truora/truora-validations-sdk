import Foundation

/// Errors that can occur during API key resolution.
///
/// These errors match the Android SDK's `ApiKeyException` types for cross-platform parity.
public enum ApiKeyError: Error, Equatable, LocalizedError {
    /// The JWT format is invalid (must have 3 parts separated by dots)
    case invalidJwtFormat

    /// The API key has expired
    /// - Parameter expiration: Unix timestamp when the key expired
    case expiredKey(expiration: TimeInterval)

    /// The key_type claim is not "sdk" or "generator"
    /// - Parameter keyType: The invalid key type found in the JWT
    case invalidKeyType(String)

    /// Failed to generate an SDK key from the Account API
    /// - Parameter reason: Description of the failure
    case generationFailed(String)

    /// The key_type claim is missing from the JWT payload
    case missingKeyType

    /// The exp (expiration) claim is missing from the JWT payload
    case missingExpiration

    public var errorDescription: String? {
        switch self {
        case .invalidJwtFormat:
            return "Invalid JWT format"
        case .expiredKey(let expiration):
            let date = Date(timeIntervalSince1970: expiration)
            return "API Key expired at: \(date). Must be a valid key"
        case .invalidKeyType(let keyType):
            return "Invalid key_type: \(keyType). Must be 'sdk' or 'generator'"
        case .generationFailed(let reason):
            return "Failed to generate SDK key: \(reason)"
        case .missingKeyType:
            return "key_type not found in JWT"
        case .missingExpiration:
            return "exp not found in JWT"
        }
    }
}
