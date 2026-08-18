//
//  ConsentTermsAPIClient.swift
//  TruoraValidationsSDK
//

import Foundation

/// Client for the Truora Account API consent-terms endpoint
/// (`GET {ACCOUNT_URL}/v1/consent-terms/{terms_id}`).
///
/// Lives alongside ``TruoraProcessAPIClient`` but points at a **different host**
/// (``defaultBaseUrl``, the Account API): consent copy is served by the Account
/// API, the same source `handle-process-consents` reads at finalization to
/// register the legally-binding consent record — fetching (rather than bundling
/// strings) guarantees the copy the user sees matches the copy that gets filed.
///
/// Follows ``TruoraProcessAPIClient`` conventions: the process token goes in the
/// `Truora-API-Key` header and errors surface as ``TruoraProcessAPIError``. The
/// transport is ``defaultSessionConfig`` rather than the shared default because
/// this client backs a visible loading state — see that property.
public class ConsentTermsAPIClient {
    private let apiKey: String
    private let baseUrl: String
    private let sessionConfig: TruoraSessionConfiguration
    private let session: URLSession

    private let decoder = JSONDecoder()

    /// Default Account API base URL (the web process-runner's `ACCOUNT_URL`).
    /// Staging is `https://api.account.truorastaging.com/v1`, passed by the
    /// caller — mirroring ``TruoraProcessAPIClient/defaultBaseUrl``.
    public static let defaultBaseUrl = "https://api.account.truora.com/v1"

    /// Transport bound for consent fetches.
    ///
    /// `maxRetries: 0` because ``AuthorizationConsentLoader`` owns the retry
    /// schedule — a retrying transport beneath it would multiply attempts rather
    /// than bound them.
    ///
    /// The timeouts are deliberately much tighter than
    /// ``TruoraSessionConfiguration/default``, whose 300s resource timeout plus
    /// `waitsForConnectivity` lets a single attempt outlive the screen it is
    /// loading. Three attempts at 10s plus the loader's 1s/2s backoff put the
    /// worst case at ~33s, which ``AuthorizationConsentLoader/loadDeadline`` then
    /// cuts short.
    public static let defaultSessionConfig = TruoraSessionConfiguration(
        timeoutIntervalForRequest: 10,
        timeoutIntervalForResource: 10,
        waitsForConnectivity: false,
        maxRetries: 0
    )

    /// - Parameters:
    ///   - apiKey: The DI process token, sent raw (no `Bearer` prefix).
    ///   - sessionConfig: defaults to ``defaultSessionConfig``; see that property.
    public init(
        apiKey: String,
        baseUrl: String = ConsentTermsAPIClient.defaultBaseUrl,
        sessionConfig: TruoraSessionConfiguration = ConsentTermsAPIClient.defaultSessionConfig
    ) {
        self.apiKey = apiKey
        self.baseUrl = baseUrl
        self.sessionConfig = sessionConfig
        self.session = sessionConfig.createSession()
    }

    /// Creates a client with a custom `URLSession` (for testing).
    init(
        apiKey: String,
        baseUrl: String = ConsentTermsAPIClient.defaultBaseUrl,
        sessionConfig: TruoraSessionConfiguration = ConsentTermsAPIClient.defaultSessionConfig,
        session: URLSession
    ) {
        self.apiKey = apiKey
        self.baseUrl = baseUrl
        self.sessionConfig = sessionConfig
        self.session = session
    }

    // MARK: - Consent Terms

    /// Fetches the consent terms for `termsId`. `GET /v1/consent-terms/{termsId}`.
    ///
    /// `termsId` is either a concrete id (`DPCT…`) or a default alias
    /// (`default-basic` / `default-items`), which the service resolves itself.
    /// `queryItems` carry the `{COUNTRY}.name` / `{COUNTRY}.nit` company
    /// parameters and are appended in the order given (callers pass a
    /// deterministic order); the client always appends `terms=true` last, which
    /// selects the variant → language response shape.
    func fetchTerms(termsId: String, queryItems: [URLQueryItem] = []) async throws -> ConsentTermsResponse {
        guard !termsId.isEmpty else {
            throw TruoraProcessAPIError.invalidURL
        }

        guard var components = URLComponents(string: "\(baseUrl)/consent-terms/\(termsId)") else {
            throw TruoraProcessAPIError.invalidURL
        }
        components.queryItems = queryItems + [URLQueryItem(name: "terms", value: "true")]

        guard let url = components.url else {
            throw TruoraProcessAPIError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.addValue(apiKey, forHTTPHeaderField: "Truora-API-Key")
        urlRequest.addValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await sessionConfig.perform(urlRequest, using: session)
        } catch let urlError as URLError where urlError.code == .cancelled {
            // Keep cancellation cancellation: wrapping it as `.networkError` would
            // make `TruoraProcessRequestExecutor` report a torn-down prefetch as a failed one.
            throw CancellationError()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw TruoraProcessAPIError.networkError(error)
        }

        try validateResponse(response, data: data)

        do {
            return try decoder.decode(ConsentTermsResponse.self, from: data)
        } catch {
            throw TruoraProcessAPIError.decodingError(error)
        }
    }

    // MARK: - Private Helpers

    /// Maps HTTP status codes to typed ``TruoraProcessAPIError`` values, mirroring
    /// ``TruoraProcessAPIClient``.
    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TruoraProcessAPIError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let bodyString = String(data: data, encoding: .utf8)
            logErrorResponse(statusCode: httpResponse.statusCode, body: bodyString)

            if httpResponse.statusCode == 401 {
                throw TruoraProcessAPIError.unauthorized(body: bodyString)
            }
            throw TruoraProcessAPIError.serverError(statusCode: httpResponse.statusCode, body: bodyString)
        }
    }

    private func logErrorResponse(statusCode: Int, body: String?) {
        debugLog("❌ ConsentTermsAPIClient: HTTP \(statusCode)")
        if let body {
            debugLog("❌ ConsentTermsAPIClient: Response body: \(body)")
        }
    }
}
