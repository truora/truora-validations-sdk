import Foundation

/// Manages API key resolution, handling both SDK and generator key types.
///
/// The manager:
/// 1. Decodes the JWT to extract expiration and key type
/// 2. Validates the key hasn't expired
/// 3. Returns SDK keys directly
/// 4. Exchanges generator keys for SDK keys via the Account API
public class ApiKeyManager {
    private let jwtDecoder: JwtDecoder
    private let generatorClient: ApiKeyGeneratorClient
    private let currentTimeProvider: () -> TimeInterval

    /// Creates a new API key manager.
    ///
    /// - Parameters:
    ///   - jwtDecoder: Decoder for JWT tokens (defaults to new instance)
    ///   - generatorClient: Client for exchanging generator keys (defaults to new instance)
    ///   - currentTimeProvider: Provider for current time (defaults to Date())
    public init(
        jwtDecoder: JwtDecoder = JwtDecoder(),
        generatorClient: ApiKeyGeneratorClient = ApiKeyGeneratorClient(),
        currentTimeProvider: @escaping () -> TimeInterval = { Date().timeIntervalSince1970 }
    ) {
        self.jwtDecoder = jwtDecoder
        self.generatorClient = generatorClient
        self.currentTimeProvider = currentTimeProvider
    }

    /// Resolves an API key for use with the Validations API.
    ///
    /// - SDK keys are returned directly after validation
    /// - Generator keys are exchanged for SDK keys via the Account API
    ///
    /// - Parameter apiKey: The API key to resolve (can be SDK or generator type)
    /// - Returns: A valid SDK API key
    /// - Throws: `ApiKeyError` if resolution fails
    public func resolveApiKey(_ apiKey: String) async throws -> String {
        // Extract JWT data
        let (expiration, keyType) = try jwtDecoder.extractJwtData(apiKey)

        // Check expiration
        if jwtDecoder.isExpired(expiration, currentTime: currentTimeProvider()) {
            throw ApiKeyError.expiredKey(expiration: expiration)
        }

        // Handle key type
        switch keyType {
        case ApiKeyTypes.sdk:
            // SDK keys can be used directly
            return apiKey

        case ApiKeyTypes.generator:
            // Generator keys need to be exchanged for SDK keys
            return try await generatorClient.generateSdkKey(from: apiKey)

        default:
            throw ApiKeyError.invalidKeyType(keyType)
        }
    }
}
