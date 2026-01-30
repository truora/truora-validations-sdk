//
//  ValidationConfig.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 30/10/25.
//

import Combine
import Foundation

// MARK: - Validation Configuration

final class ValidationConfig: ObservableObject {
    static let shared = ValidationConfig()

    private(set) var apiClient: TruoraAPIClient?
    private(set) var delegate: ((TruoraValidationResult<ValidationResult>) -> Void)?
    private(set) var accountId: String?
    private(set) var enrollmentData: EnrollmentData?
    private(set) var uiConfig: UIConfig
    private(set) var faceConfig: Face
    private(set) var documentConfig: Document
    private let logoDownloader: LogoDownloading
    private var logoDownloadTask: Task<Void, Never>?

    private init(logoDownloader: LogoDownloading = LogoDownloader()) {
        self.logoDownloader = logoDownloader
        self.uiConfig = UIConfig()
        self.faceConfig = Face()
        self.documentConfig = Document()
    }

    deinit {
        logoDownloadTask?.cancel()
        logoDownloadTask = nil
    }

    /// Creates a ValidationConfig instance for testing with a custom logo downloader.
    /// - Parameter logoDownloader: A mock or fake LogoDownloading implementation
    /// - Returns: A new ValidationConfig instance (not the shared singleton)
    static func makeForTesting(logoDownloader: LogoDownloading) -> ValidationConfig {
        ValidationConfig(logoDownloader: logoDownloader)
    }

    /// Configures the SDK.
    /// - Parameters:
    ///   - apiKey: API key for authentication.
    ///   - accountId: Optional account ID.
    ///   - enrollmentData: Optional enrollment data.
    ///   - delegate: Optional delegate for callbacks.
    ///   - baseUrl: Optional base URL.
    ///   - uiConfig: Optional UI configuration.
    func configure(
        apiKey: String,
        accountId: String? = nil,
        enrollmentData: EnrollmentData? = nil,
        delegate: ((TruoraValidationResult<ValidationResult>) -> Void)? = nil,
        baseUrl: String? = nil,
        uiConfig: UIConfig? = nil
    ) async throws {
        // Input validation
        guard !apiKey.isEmpty else {
            throw TruoraException.sdk(SDKError(type: .invalidConfiguration, details: "API key cannot be empty"))
        }

        let finalAccountId: String
        let finalData: EnrollmentData

        if let data = enrollmentData {
            finalData = data
            finalAccountId = data.accountId
        } else if let accId = accountId {
            finalAccountId = accId
            finalData = EnrollmentData(
                enrollmentId: "",
                accountId: accId,
                uploadUrl: nil,
                createdAt: Date()
            )
        } else {
            throw TruoraException.sdk(
                SDKError(
                    type: .invalidConfiguration,
                    details: "Either accountId or enrollmentData must be provided"
                )
            )
        }

        guard !finalAccountId.isEmpty else {
            throw TruoraException.sdk(SDKError(type: .invalidConfiguration, details: "Account ID cannot be empty"))
        }

        self.accountId = finalAccountId
        self.enrollmentData = finalData
        self.delegate = delegate
        self.uiConfig = uiConfig ?? UIConfig()
        await downloadLogoIfNeeded()

        apiClient = TruoraAPIClient(apiKey: apiKey)
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
        apiClient = nil
        delegate = nil
        accountId = nil
        enrollmentData = nil
        // Note: Swift ARC automatically handles cleanup of old UIConfig/Face/Document instances
        // and their nested objects (e.g., ReferenceFace's temp file cleanup via deinit)
        uiConfig = UIConfig()
        faceConfig = Face()
        documentConfig = Document()
    }

    private func downloadLogoIfNeeded() async {
        #if DEBUG
        if TruoraValidationsSDK.isOfflineMode {
            print("⚠️ ValidationConfig: Skipping logo download in offline mode")
            return
        }
        #endif
        guard uiConfig.customLogoData == nil else { return }
        guard let logoUrlString = uiConfig.logoUrl, let url = URL(string: logoUrlString) else { return }

        let width = uiConfig.logoWidth
        let height = uiConfig.logoHeight

        logoDownloadTask = Task {
            do {
                let data = try await logoDownloader.downloadLogo(from: url)
                guard !Task.isCancelled else { return }
                _ = uiConfig.setCustomLogo(data, width: width, height: height)
            } catch {
                // Silent fallback to default logo
                print("⚠️ ValidationConfig: Logo download failed: \(error.localizedDescription)")
            }
        }

        await logoDownloadTask?.value
    }
}
