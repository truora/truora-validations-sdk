//
//  TruoraAPIClient.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 23/01/26.
//

import Foundation

public enum TruoraAPIError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case serverError(statusCode: Int, body: String?)
    case unauthorized(body: String?)
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
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
}

public class TruoraAPIClient {
    private let apiKey: String
    private let baseUrl = "https://api.validations.truora.com/v1"
    private let session: URLSession

    public init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    // MARK: - Validations

    func createValidation(request: NativeValidationRequest) async throws -> NativeValidationCreateResponse {
        guard let url = URL(string: "\(baseUrl)/validations") else {
            throw TruoraAPIError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue(apiKey, forHTTPHeaderField: "Truora-API-Key")
        urlRequest.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let parameters = encodeToFormData(request)
        urlRequest.httpBody = parameters.data(using: .utf8)

        let (data, response) = try await session.data(for: urlRequest)
        try validateResponse(response, data: data)

        do {
            return try JSONDecoder().decode(NativeValidationCreateResponse.self, from: data)
        } catch {
            throw TruoraAPIError.decodingError(error)
        }
    }

    func getValidation(validationId: String) async throws -> NativeValidationDetailResponse {
        guard let url = URL(string: "\(baseUrl)/validations/\(validationId)?show_details=true") else {
            throw TruoraAPIError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.addValue(apiKey, forHTTPHeaderField: "Truora-API-Key")

        let (data, response) = try await session.data(for: urlRequest)
        try validateResponse(response, data: data)

        do {
            return try JSONDecoder().decode(NativeValidationDetailResponse.self, from: data)
        } catch {
            throw TruoraAPIError.decodingError(error)
        }
    }

    // MARK: - Enrollments

    func createEnrollment(request: NativeEnrollmentRequest) async throws -> NativeEnrollmentResponse {
        guard let url = URL(string: "\(baseUrl)/enrollments") else {
            throw TruoraAPIError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue(apiKey, forHTTPHeaderField: "Truora-API-Key")
        urlRequest.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let parameters = encodeEnrollmentToFormData(request)
        urlRequest.httpBody = parameters.data(using: .utf8)

        let (data, response) = try await session.data(for: urlRequest)
        try validateResponse(response, data: data)

        do {
            return try JSONDecoder().decode(NativeEnrollmentResponse.self, from: data)
        } catch {
            throw TruoraAPIError.decodingError(error)
        }
    }

    // MARK: - File Upload

    func uploadFile(uploadUrl: String, fileData: Data, contentType: String) async throws {
        guard let url = URL(string: uploadUrl) else {
            throw TruoraAPIError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "PUT"
        urlRequest.addValue(contentType, forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = fileData

        let (data, response) = try await session.data(for: urlRequest)
        try validateResponse(response, data: data)
    }

    // MARK: - Image Evaluation

    func evaluateImage(request: NativeImageEvaluationRequest) async throws -> NativeImageEvaluationResponse {
        guard let url = URL(string: "\(baseUrl)/evaluate-image") else {
            throw TruoraAPIError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue(apiKey, forHTTPHeaderField: "Truora-API-Key")
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
        } catch {
            throw TruoraAPIError.decodingError(error)
        }

        let (data, response) = try await session.data(for: urlRequest)
        try validateResponse(response, data: data)

        do {
            return try JSONDecoder().decode(NativeImageEvaluationResponse.self, from: data)
        } catch {
            throw TruoraAPIError.decodingError(error)
        }
    }

    // MARK: - Private Helpers

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TruoraAPIError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let bodyString = String(data: data, encoding: .utf8)
            logErrorResponse(statusCode: httpResponse.statusCode, body: bodyString)

            if httpResponse.statusCode == 401 {
                throw TruoraAPIError.unauthorized(body: bodyString)
            }
            throw TruoraAPIError.serverError(statusCode: httpResponse.statusCode, body: bodyString)
        }
    }

    private func logErrorResponse(statusCode: Int, body: String?) {
        print("❌ TruoraAPIClient: HTTP \(statusCode)")
        if let body {
            print("❌ TruoraAPIClient: Response body: \(body)")
        }
    }

    private func encodeToFormData(_ request: NativeValidationRequest) -> String {
        var queryItems: [URLQueryItem] = []

        queryItems.append(URLQueryItem(name: "type", value: request.type))
        queryItems.append(URLQueryItem(name: "account_id", value: request.accountId))

        if let country = request.country {
            queryItems.append(URLQueryItem(name: "country", value: country))
        }

        if let docType = request.documentType {
            queryItems.append(URLQueryItem(name: "document_type", value: docType))
        }

        if let threshold = request.threshold {
            queryItems.append(URLQueryItem(name: "threshold", value: String(threshold)))
        }

        if let timeout = request.timeout {
            queryItems.append(URLQueryItem(name: "timeout", value: String(timeout)))
        }

        if let subs = request.subvalidations {
            for sub in subs {
                queryItems.append(URLQueryItem(name: "subvalidations", value: sub))
            }
        }

        var components = URLComponents()
        components.queryItems = queryItems
        return components.query ?? ""
    }

    private func encodeEnrollmentToFormData(_ request: NativeEnrollmentRequest) -> String {
        var queryItems: [URLQueryItem] = []

        queryItems.append(URLQueryItem(name: "type", value: request.type))
        queryItems.append(URLQueryItem(name: "user_authorized", value: String(request.userAuthorized)))

        if let accountId = request.accountId {
            queryItems.append(URLQueryItem(name: "account_id", value: accountId))
        }

        if let confirmation = request.confirmation {
            queryItems.append(URLQueryItem(name: "confirmation", value: confirmation))
        }

        var components = URLComponents()
        components.queryItems = queryItems
        return components.query ?? ""
    }
}
