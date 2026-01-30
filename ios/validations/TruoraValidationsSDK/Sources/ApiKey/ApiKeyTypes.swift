import Foundation

/// Constants for API key types used in the Truora Validations SDK.
///
/// API keys can be of two types:
/// - `sdk`: Can be used directly for API calls
/// - `generator`: Must be exchanged at the Account API for an SDK key
public enum ApiKeyTypes {
    /// API key type that can be used directly for API calls
    public static let sdk = "sdk"

    /// API key type that must be exchanged for an SDK key via the Account API
    public static let generator = "generator"
}

/// Constants for API key grants
enum ApiKeyGrants {
    /// Grant type for validations API access
    static let validations = "validations"
}
