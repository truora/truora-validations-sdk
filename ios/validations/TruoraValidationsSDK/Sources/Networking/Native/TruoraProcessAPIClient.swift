//
//  TruoraProcessAPIClient.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 15/06/26.
//

import Foundation

/// Errors surfaced by ``TruoraProcessAPIClient``.
///
/// Splits cleanly into two groups:
/// - Input validation (``emptyProcessId``, ``emptyStepId``, ``emptyUploadUrl``,
///   ``emptyFileData``) — mirrors the KMP `IdentityErrorType` guard clauses so
///   the SDK fails fast before hitting the network.
/// - Transport / HTTP (``invalidURL`` … ``invalidResponse``) — maps URLSession
///   failures and non-2xx status codes to typed values, with `401` getting its
///   own ``unauthorized`` case like ``TruoraAPIError``.
public enum TruoraProcessAPIError: Error, LocalizedError, Equatable {
    // MARK: Input validation

    case emptyProcessId
    case emptyStepId
    case emptyUploadUrl
    case emptyFileData

    // MARK: Transport / HTTP

    case invalidURL
    case encodingError(Error)
    case decodingError(Error)
    case networkError(Error)
    case uploadFailed(Error)
    case serverError(statusCode: Int, body: String?)
    case unauthorized(body: String?)
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .emptyProcessId:
            return "Process ID is empty"
        case .emptyStepId:
            return "Step ID is empty"
        case .emptyUploadUrl:
            return "Upload URL is empty"
        case .emptyFileData:
            return "File data is empty"
        case .invalidURL:
            return "Invalid URL"
        case .encodingError(let error):
            return "Encoding error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .uploadFailed(let error):
            return "File upload failed: \(error.localizedDescription)"
        case .serverError(let statusCode, let body):
            if let body {
                return "Server error (\(statusCode)): \(body)"
            }
            return "Server error (\(statusCode))"
        case .unauthorized(let body):
            if let body {
                return "Unauthorized: \(body)"
            }
            return "Unauthorized"
        case .invalidResponse:
            return "Invalid response"
        }
    }

    /// `Equatable` so tests can assert specific cases; associated `Error`
    /// payloads are compared by case identity only.
    public static func == (lhs: TruoraProcessAPIError, rhs: TruoraProcessAPIError) -> Bool {
        switch (lhs, rhs) {
        case (.emptyProcessId, .emptyProcessId),
             (.emptyStepId, .emptyStepId),
             (.emptyUploadUrl, .emptyUploadUrl),
             (.emptyFileData, .emptyFileData),
             (.invalidURL, .invalidURL),
             (.encodingError, .encodingError),
             (.decodingError, .decodingError),
             (.networkError, .networkError),
             (.uploadFailed, .uploadFailed),
             (.invalidResponse, .invalidResponse):
            true
        case (.serverError(let lCode, let lBody), .serverError(let rCode, let rBody)):
            lCode == rCode && lBody == rBody
        case (.unauthorized(let lBody), .unauthorized(let rBody)):
            lBody == rBody
        default:
            false
        }
    }
}

/// Outcome of an idempotent create-or-read against the DI backend.
///
/// The backend is idempotent per token: creating a process for a token that already has
/// one returns the existing process instead of duplicating it. The HTTP status carries the
/// distinction (`201` created / `200` read).
struct CreateOrReadResult {
    let process: TruoraProcessResponse
    let created: Bool
}

/// Client for the Truora Digital Identity (DI) Processes API.
///
/// Counterpart to ``TruoraAPIClient`` (the Validations API), aligned with the
/// KMP `IdentityApi` used by Android. Differences from ``TruoraAPIClient``:
/// - Base URL points at the DI Processes API.
/// - Request bodies are JSON (via `Codable`), not form-urlencoded.
/// - Errors use ``TruoraProcessAPIError`` (adds input-validation cases) instead of
///   ``TruoraAPIError``.
///
/// The auth header (`Truora-API-Key`) and presigned-URL file upload follow the
/// existing ``TruoraAPIClient`` conventions.
///
/// **Retries are not this client's job.** Unlike ``TruoraAPIClient``, the default
/// `sessionConfig` is ``TruoraSessionConfiguration/noRetry``: the DI callers each
/// own a retry policy of their own — ``TruoraProcessRequestExecutor`` for the JSON endpoints
/// and ``MediaUploader`` for presigned uploads — and a retrying transport beneath
/// them would multiply the attempts rather than bound them. Pass a retrying
/// `sessionConfig` explicitly only if nothing above is already retrying.
public class TruoraProcessAPIClient {
    private let apiKey: String
    private let baseUrl: String
    private let sessionConfig: TruoraSessionConfiguration
    private let session: URLSession

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// Default DI Processes API base URL (matches KMP `TruoraIdentity`).
    public static let defaultBaseUrl = TruoraProcessEnvironment.production.processesBaseUrl

    /// - Parameter sessionConfig: defaults to ``TruoraSessionConfiguration/noRetry``
    ///   so the transport attempts each request exactly once; see the type doc.
    public init(
        apiKey: String,
        baseUrl: String = TruoraProcessAPIClient.defaultBaseUrl,
        sessionConfig: TruoraSessionConfiguration = .noRetry
    ) {
        self.apiKey = apiKey
        self.baseUrl = baseUrl
        self.sessionConfig = sessionConfig
        self.session = sessionConfig.createSession()
    }

    /// Creates a client with a custom `URLSession` (for testing).
    init(
        apiKey: String,
        baseUrl: String = TruoraProcessAPIClient.defaultBaseUrl,
        sessionConfig: TruoraSessionConfiguration = .noRetry,
        session: URLSession
    ) {
        self.apiKey = apiKey
        self.baseUrl = baseUrl
        self.sessionConfig = sessionConfig
        self.session = session
    }

    /// Creates a client pointed at `environment`'s Processes host.
    ///
    /// The internal seam behind the public initializers: `environment` has no default
    /// and is unreachable from the public builder, so production stays the only host
    /// an integrator can get. `nil` `session` builds one from `sessionConfig`.
    convenience init(
        apiKey: String,
        environment: TruoraProcessEnvironment,
        sessionConfig: TruoraSessionConfiguration = .noRetry,
        session: URLSession? = nil
    ) {
        if let session {
            self.init(
                apiKey: apiKey,
                baseUrl: environment.processesBaseUrl,
                sessionConfig: sessionConfig,
                session: session
            )
        } else {
            self.init(
                apiKey: apiKey,
                baseUrl: environment.processesBaseUrl,
                sessionConfig: sessionConfig
            )
        }
    }

    // MARK: - Process Lifecycle

    /// Creates a new identity process. `POST /v1/processes`.
    /// Mirrors KMP `IdentityApi.createIdentity`.
    func createProcess(request: TruoraCreateProcessRequest) async throws -> TruoraProcessResponse {
        let urlRequest = try jsonRequest(path: "", method: "POST", body: request)
        return try await send(TruoraProcessResponse.self, urlRequest)
    }

    /// Reads an identity process. `GET /v1/processes/{processId}`.
    /// Mirrors KMP `IdentityApi.readIdentity`.
    func readProcess(processId: String) async throws -> TruoraProcessResponse {
        guard !processId.isEmpty else {
            throw TruoraProcessAPIError.emptyProcessId
        }

        let urlRequest = try getRequest(path: "/\(processId)")
        return try await send(TruoraProcessResponse.self, urlRequest)
    }

    /// Cancels an identity process. `POST /v1/processes/{processId}/status`.
    /// Mirrors KMP `IdentityApi.cancelIdentity` (JSON body instead of form data).
    func cancelProcess(
        processId: String,
        request: TruoraCancelProcessRequest
    ) async throws -> TruoraProcessResponse {
        guard !processId.isEmpty else {
            throw TruoraProcessAPIError.emptyProcessId
        }

        let urlRequest = try jsonRequest(path: "/\(processId)/status", method: "POST", body: request)
        return try await send(TruoraProcessResponse.self, urlRequest)
    }

    // MARK: - Blocks

    /// Adds a dynamic block to a process.
    /// `POST /v1/processes/{processId}/verifications`.
    /// Mirrors KMP `IdentityApi.addDynamicBlock`.
    func addBlock(
        processId: String,
        request: TruoraAddBlockRequest
    ) async throws -> TruoraAddBlockResponse {
        guard !processId.isEmpty else {
            throw TruoraProcessAPIError.emptyProcessId
        }

        let urlRequest = try jsonRequest(path: "/\(processId)/verifications", method: "POST", body: request)
        return try await send(TruoraAddBlockResponse.self, urlRequest)
    }

    // MARK: - Steps

    /// Verifies a step. `POST /v1/processes/steps/{stepId}`.
    /// Mirrors KMP `IdentityApi.verifyStep`.
    func verifyStep(stepId: String, request: TruoraVerifyStepRequest) async throws -> TruoraStep {
        guard !stepId.isEmpty else {
            throw TruoraProcessAPIError.emptyStepId
        }

        let urlRequest = try jsonRequest(path: "/steps/\(stepId)", method: "POST", body: request)
        return try await send(TruoraStep.self, urlRequest)
    }

    /// Goes back a step. `POST /v1/processes/steps/{stepId}/back`.
    /// Mirrors KMP `IdentityApi.identityBackStep` (JSON body instead of form data).
    func backStep(stepId: String, request: TruoraBackStepRequest) async throws -> TruoraStep {
        guard !stepId.isEmpty else {
            throw TruoraProcessAPIError.emptyStepId
        }

        let urlRequest = try jsonRequest(path: "/steps/\(stepId)/back", method: "POST", body: request)
        return try await send(TruoraStep.self, urlRequest)
    }

    // MARK: - File Upload

    /// Uploads a captured asset to a presigned URL via `PUT`.
    /// Mirrors KMP `IdentityApi.uploadFile`. Reuses the same presigned-upload
    /// pattern as ``TruoraAPIClient/uploadFile(uploadUrl:fileData:contentType:)``.
    ///
    /// Deliberately **not** wrapped in ``TruoraProcessRequestExecutor``: an upload's retryable
    /// set differs from a JSON call's (a spent presigned URL is terminal however
    /// many times you ask), and each attempt re-sends the whole capture.
    /// ``MediaUploader`` owns the retry policy for this endpoint. Note that
    /// ``TruoraProcessErrorMapper`` maps a thrown ``TruoraProcessAPIError/uploadFailed(_:)`` to a
    /// *retriable* `.network` error, so wrapping it would silently grant it the
    /// executor's budget on top of the uploader's.
    func uploadFile(uploadUrl: String, fileData: Data, contentType: String = "video/mp4") async throws {
        guard !uploadUrl.isEmpty else {
            throw TruoraProcessAPIError.emptyUploadUrl
        }

        guard !fileData.isEmpty else {
            throw TruoraProcessAPIError.emptyFileData
        }

        guard let url = URL(string: uploadUrl) else {
            throw TruoraProcessAPIError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "PUT"
        urlRequest.addValue(contentType, forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = fileData

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await sessionConfig.perform(urlRequest, using: session)
        } catch {
            throw TruoraProcessAPIError.uploadFailed(error)
        }

        try validateResponse(response, data: data)
    }

    // MARK: - Private Helpers

    /// Builds the full URL for a path relative to ``baseUrl``.
    private func makeURL(_ path: String) throws -> URL {
        guard let url = URL(string: "\(baseUrl)\(path)") else {
            throw TruoraProcessAPIError.invalidURL
        }
        return url
    }

    /// Builds a GET request with the standard auth/accept headers.
    private func getRequest(path: String) throws -> URLRequest {
        var urlRequest = try URLRequest(url: makeURL(path))
        urlRequest.httpMethod = "GET"
        urlRequest.addValue(apiKey, forHTTPHeaderField: "Truora-API-Key")
        urlRequest.addValue("application/json", forHTTPHeaderField: "Accept")
        return urlRequest
    }

    /// Builds a request with a JSON-encoded body and the standard headers.
    private func jsonRequest(path: String, method: String, body: some Encodable) throws -> URLRequest {
        var urlRequest = try URLRequest(url: makeURL(path))
        urlRequest.httpMethod = method
        urlRequest.addValue(apiKey, forHTTPHeaderField: "Truora-API-Key")
        urlRequest.addValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            urlRequest.httpBody = try encoder.encode(body)
        } catch {
            throw TruoraProcessAPIError.encodingError(error)
        }

        return urlRequest
    }

    /// Performs a request, validates the response, and decodes the body.
    private func send<T: Decodable>(_ type: T.Type, _ urlRequest: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await sessionConfig.perform(urlRequest, using: session)
        } catch {
            throw TruoraProcessAPIError.networkError(error)
        }

        try validateResponse(response, data: data)

        return try decode(data)
    }

    /// Performs a JSON POST and returns the raw response body plus the validated
    /// `HTTPURLResponse`, so callers can inspect the status code themselves.
    func postRaw(_ path: String, body: some Encodable) async throws -> (Data, HTTPURLResponse) {
        let urlRequest = try jsonRequest(path: path, method: "POST", body: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await sessionConfig.perform(urlRequest, using: session)
        } catch {
            throw TruoraProcessAPIError.networkError(error)
        }

        try validateResponse(response, data: data)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TruoraProcessAPIError.invalidResponse
        }
        return (data, httpResponse)
    }

    func decode<T: Decodable>(_ data: Data) throws -> T {
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw TruoraProcessAPIError.decodingError(error)
        }
    }

    /// Maps HTTP status codes to typed ``TruoraProcessAPIError`` values.
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
        debugLog("❌ TruoraProcessAPIClient: HTTP \(statusCode)")
        if let body {
            debugLog("❌ TruoraProcessAPIClient: Response body: \(body)")
        }
    }
}

// MARK: - Create-or-read

extension TruoraProcessAPIClient {
    /// Creates the flow's identity process, or reads the existing one for this token.
    ///
    /// Flow-based creation: the flow, account and context are all derived server-side from
    /// the token (the authorizer / JTI), and the backend auto-prepends the
    /// `enter_authorization` block — so the request body is empty (`{}`). This is
    /// deliberately distinct from *dynamic*-process creation (`process_type = dynamic` plus a
    /// client-supplied `verification`), which the SDK no longer uses.
    ///
    /// - Returns: the process plus `created` — `true` on HTTP 201 (a new process was
    ///   created), `false` on HTTP 200 (an existing process for this token was read).
    func createOrRead() async throws -> CreateOrReadResult {
        let (data, http) = try await postRaw("", body: [String: String]())
        return try CreateOrReadResult(process: decode(data), created: http.statusCode == 201)
    }
}
