//
//  ValidationConfig.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 30/10/25.
//

import Combine
import Foundation
import TruoraShared

// MARK: - Validation Configuration

final class ValidationConfig: ObservableObject {
    static let shared = ValidationConfig()

    private(set) var apiClient: TruoraValidations?
    private(set) var delegate: ((TruoraValidationResult<ValidationResult>) -> Void)?
    private(set) var accountId: String?
    private(set) var enrollmentData: EnrollmentData?
    private(set) var uiConfig: UIConfig
    @Published private(set) var composeConfig: TruoraUIConfig
    private(set) var faceConfig: Face
    private(set) var documentConfig: Document
    private let logoDownloader: LogoDownloading
    private var logoDownloadTask: Task<Void, Never>?

    private init(logoDownloader: LogoDownloading = LogoDownloader()) {
        self.logoDownloader = logoDownloader
        self.uiConfig = UIConfig()
        self.composeConfig = uiConfig.toTruoraConfig()
        self.faceConfig = Face()
        self.documentConfig = Document()
    }

    deinit {
        logoDownloadTask?.cancel()
        logoDownloadTask = nil
    }

    static func makeForTesting(logoDownloader: LogoDownloading) -> ValidationConfig {
        ValidationConfig(logoDownloader: logoDownloader)
    }

    func configure(
        apiKey: String,
        accountId: String,
        delegate: ((TruoraValidationResult<ValidationResult>) -> Void)? = nil,
        baseUrl: String? = nil,
        uiConfig: UIConfig? = nil
    ) async throws {
        let dummyEnrollmentData = EnrollmentData(
            enrollmentId: "",
            accountId: accountId,
            uploadUrl: nil,
            createdAt: Date()
        )
        try await configure(
            apiKey: apiKey,
            enrollmentData: dummyEnrollmentData,
            delegate: delegate,
            baseUrl: baseUrl,
            uiConfig: uiConfig
        )
    }

    func configure(
        apiKey: String,
        enrollmentData: EnrollmentData,
        delegate: ((TruoraValidationResult<ValidationResult>) -> Void)? = nil,
        baseUrl: String? = nil,
        uiConfig: UIConfig? = nil
    ) async throws {
        // Input validation
        guard !apiKey.isEmpty else {
            throw ValidationError.invalidConfiguration("API key cannot be empty")
        }

        guard !enrollmentData.accountId.isEmpty else {
            throw ValidationError.invalidConfiguration("Account ID cannot be empty")
        }

        if let baseUrl {
            guard !baseUrl.isEmpty else {
                throw ValidationError.invalidConfiguration("Base URL cannot be empty")
            }
            guard URL(string: baseUrl) != nil else {
                throw ValidationError.invalidConfiguration("Base URL is not a valid URL")
            }
        }

        accountId = enrollmentData.accountId
        self.enrollmentData = enrollmentData
        self.delegate = delegate
        self.uiConfig = uiConfig ?? UIConfig()
        await downloadLogoIfNeeded()
        self.composeConfig = self.uiConfig.toTruoraConfig()

        // Use TruoraValidations constructor directly
        if let baseUrl {
            apiClient = TruoraValidations(apiKey: apiKey, baseUrl: baseUrl)
        } else {
            apiClient = TruoraValidations(apiKey: apiKey, baseUrl: "https://api.validations.truora.com/v1")
        }
    }

    func setValidation(_ type: ValidationType) {
        switch type {
        case .face(let face):
            self.faceConfig = face
        case .document(let document):
            self.documentConfig = document
        }
    }

    func updateEnrollmentData(_ enrollmentData: EnrollmentData) {
        self.enrollmentData = enrollmentData
    }

    func reset() {
        logoDownloadTask?.cancel()
        logoDownloadTask = nil
        apiClient?.close()
        apiClient = nil
        delegate = nil
        accountId = nil
        enrollmentData = nil
        // Note: Swift ARC automatically handles cleanup of old UIConfig/Face/Document instances
        // and their nested objects (e.g., ReferenceFace's temp file cleanup via deinit)
        uiConfig = UIConfig()
        composeConfig = uiConfig.toTruoraConfig()
        faceConfig = Face()
        documentConfig = Document()
    }

    private func downloadLogoIfNeeded() async {
        guard uiConfig.customLogoData == nil else { return }
        guard let logoUrlString = uiConfig.logoUrl, let url = URL(string: logoUrlString) else { return }

        let width = uiConfig.logoWidth
        let height = uiConfig.logoHeight

        logoDownloadTask = Task {
            let result = await withCheckedContinuation { continuation in
                logoDownloader.downloadLogo(from: url) { result in
                    continuation.resume(returning: result)
                }
            }

            guard !Task.isCancelled else { return }

            switch result {
            case .success(let data):
                _ = uiConfig.setCustomLogo(data, width: width, height: height)
            case .failure:
                // Optional: Silent fallback to default logo
                break
            }
        }

        await logoDownloadTask?.value
    }
}
