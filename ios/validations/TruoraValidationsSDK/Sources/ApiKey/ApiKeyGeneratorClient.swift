import Foundation

/// Client for generating SDK keys from generator keys via the Truora Account API.
///
/// This client exchanges a generator-type API key for an SDK-type API key
/// that can be used for API calls.
public class ApiKeyGeneratorClient {
    /// Base URL for the Account API
    public static let baseURL = "https://api.account.truora.com/v1"

    private let session: URLSession

    /// Creates a new API key generator client.
    /// - Parameter session: URLSession to use for requests (defaults to shared session)
    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// Generates an SDK key from a generator key.
    ///
    /// - Parameter generatorKey: The generator-type API key to exchange
    /// - Returns: The generated SDK API key
    /// - Throws: `ApiKeyError.generationFailed` if the request fails
    public func generateSdkKey(from generatorKey: String) async throws -> String {
        guard let url = URL(string: "\(Self.baseURL)/api-keys") else {
            throw ApiKeyError.generationFailed("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(generatorKey, forHTTPHeaderField: "Truora-API-Key")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Form-encoded body
        let bodyParams = [
            "key_type": ApiKeyTypes.sdk,
            "grant": ApiKeyGrants.validations,
            "api_key_version": "1",
            "key_name": "sdk_usage"
        ]
        request.httpBody = bodyParams
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ApiKeyError.generationFailed("Invalid response type")
            }

            guard (200 ... 299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw ApiKeyError.generationFailed("HTTP \(httpResponse.statusCode): \(errorMessage)")
            }

            let apiKeyResponse = try JSONDecoder().decode(ApiKeyResponse.self, from: data)
            return apiKeyResponse.apiKey
        } catch let error as ApiKeyError {
            throw error
        } catch {
            throw ApiKeyError.generationFailed(error.localizedDescription)
        }
    }
}
