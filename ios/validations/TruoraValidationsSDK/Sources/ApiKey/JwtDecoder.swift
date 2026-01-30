import Foundation

/// Decodes JWT tokens to extract API key metadata.
///
/// This decoder extracts the `exp` (expiration) and `key_type` claims from JWT tokens
/// used as Truora API keys.
public struct JwtDecoder {
    public init() {}

    /// Extracts the expiration timestamp and key type from a JWT.
    ///
    /// - Parameter jwt: The JWT string (format: header.payload.signature)
    /// - Returns: A tuple containing the expiration timestamp and key type
    /// - Throws: `ApiKeyError` if the JWT is malformed or missing required claims
    public func extractJwtData(_ jwt: String) throws -> (expiration: TimeInterval, keyType: String) {
        let payload = try decodePayload(jwt)
        let expiration = try extractExpiration(from: payload)

        guard let keyType = extractKeyType(from: payload) else {
            throw ApiKeyError.missingKeyType
        }

        return (expiration, keyType)
    }

    /// Checks if a JWT is expired.
    ///
    /// - Parameters:
    ///   - expiration: The expiration timestamp from the JWT
    ///   - currentTime: The current time to compare against (defaults to now)
    /// - Returns: `true` if the JWT is expired, `false` otherwise
    public func isExpired(
        _ expiration: TimeInterval,
        currentTime: TimeInterval = Date().timeIntervalSince1970
    ) -> Bool {
        currentTime >= expiration
    }

    // MARK: - Private

    private func extractExpiration(from payload: [String: Any]) throws -> TimeInterval {
        if let expiration = payload["exp"] as? TimeInterval {
            return expiration
        }
        if let expInt = payload["exp"] as? Int {
            return TimeInterval(expInt)
        }
        if let expString = payload["exp"] as? String, let exp = TimeInterval(expString) {
            return exp
        }
        throw ApiKeyError.missingExpiration
    }

    private func extractKeyType(from payload: [String: Any]) -> String? {
        payload["key_type"] as? String
    }

    private func decodePayload(_ jwt: String) throws -> [String: Any] {
        let parts = jwt.components(separatedBy: ".")

        guard parts.count == 3 else {
            throw ApiKeyError.invalidJwtFormat
        }

        let payloadPart = parts[1]

        // Base64URL decode (replace - with + and _ with /)
        var base64 = payloadPart
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Pad to multiple of 4
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }

        guard let data = Data(base64Encoded: base64) else {
            throw ApiKeyError.invalidJwtFormat
        }

        guard let json = try? JSONSerialization.jsonObject(with: data, options: []),
              let payload = json as? [String: Any] else {
            throw ApiKeyError.invalidJwtFormat
        }

        return payload
    }
}
