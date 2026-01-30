import Foundation

/// Response from the Account API when generating an SDK key.
struct ApiKeyResponse: Codable, Equatable {
    /// The generated SDK API key
    let apiKey: String

    /// Status message from the server
    let message: String

    private enum CodingKeys: String, CodingKey {
        case apiKey = "api_key"
        case message
    }
}
