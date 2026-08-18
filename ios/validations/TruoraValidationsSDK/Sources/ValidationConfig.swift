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
    private(set) var validationId: String?
    private(set) var enrollmentData: EnrollmentData?
    private(set) var uiConfig: UIConfig
    /// SDK UI language. Set via Builder.withLanguage(). When nil, SDK uses device locale internally.
    private(set) var lang: TruoraLanguage?
    private(set) var faceConfig: Face
    private(set) var documentConfig: Document
    private(set) var invoiceConfig: Invoice
    private(set) var detectionReporter: DetectionReporter?
    private var attestationProvider: (any AttestationProviding)?
    private var attestationTask: Task<Void, Never>?
    private let logoDownloader: LogoDownloading
    private var logoDownloadTask: Task<Void, Never>?
    /// Serialises `initializeDetectionReporter(flowType:)` so concurrent callers
    /// from different threads cannot both pass the `attestationProvider == nil`
    /// idempotency guard and leak a second provider. Lightweight — only held for
    /// the duration of the guard + assignment, no async/Keychain work inside.
    private let initializationLock = NSLock()

    private init(logoDownloader: LogoDownloading = LogoDownloader()) {
        self.logoDownloader = logoDownloader
        self.uiConfig = UIConfig()
        self.faceConfig = Face()
        self.documentConfig = Document()
        self.invoiceConfig = Invoice()
    }

    deinit {
        logoDownloadTask?.cancel()
        logoDownloadTask = nil
        attestationTask?.cancel()
        attestationTask = nil
        // B3-6: In SwiftUI lifecycle changes ValidationConfig may dealloc without reset() being
        // called. Capture the provider locally before niling it, then shut it down in a Task
        // so the async call completes even though we are already in deinit.
        let providerToShutdown = attestationProvider
        attestationProvider = nil
        if let provider = providerToShutdown {
            Task { await provider.shutdown() }
        }
    }

    /// Creates a ValidationConfig instance for testing with a custom logo downloader.
    /// - Parameter logoDownloader: A mock or fake LogoDownloading implementation
    /// - Returns: A new ValidationConfig instance (not the shared singleton)
    static func makeForTesting(logoDownloader: LogoDownloading) -> ValidationConfig {
        ValidationConfig(logoDownloader: logoDownloader)
    }

    /// Injects a pre-built DetectionReporter for testing purposes.
    /// Use this to supply a reporter backed by a mock bridge to verify
    /// the ValidationConfig → DetectionReporter forwarding chain.
    func setDetectionReporterForTesting(_ reporter: DetectionReporter) {
        detectionReporter = reporter
    }

    /// Configures the SDK.
    /// - Parameters:
    ///   - apiKey: API key for authentication.
    ///   - accountId: Optional account ID.
    ///   - enrollmentData: Optional enrollment data.
    ///   - delegate: Optional delegate for callbacks.
    ///   - baseUrl: Optional base URL.
    ///   - uiConfig: Optional UI configuration.
    ///   - lang: Optional language; when provided (e.g. from Builder.withLanguage()), forces UI language.
    func configure(
        apiKey: String,
        accountId: String? = nil,
        enrollmentData: EnrollmentData? = nil,
        delegate: ((TruoraValidationResult<ValidationResult>) -> Void)? = nil,
        baseUrl: String? = nil,
        uiConfig: UIConfig? = nil,
        lang: TruoraLanguage? = nil
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
        self.lang = lang
        await downloadLogoIfNeeded()

        apiClient = TruoraAPIClient(apiKey: apiKey)
    }

    func setValidation(_ type: ValidationType) throws {
        switch type {
        case .face(let face):
            try validateFinishViewConfig(
                finishViewConfig: face.finishViewConfig,
                waitForResults: face.waitForResults
            )
            self.faceConfig = face
        case .document(let document):
            try validateFinishViewConfig(
                finishViewConfig: document.finishViewConfig,
                waitForResults: document.waitForResults
            )
            try validateAutocaptureConfig(document)
            self.documentConfig = document
        case .invoice(let invoice):
            try validateFinishViewConfig(
                finishViewConfig: invoice.finishViewConfig,
                waitForResults: invoice.waitForResults
            )
            self.invoiceConfig = invoice
        }
    }

    private func validateFinishViewConfig(
        finishViewConfig: FinishViewConfiguration?,
        waitForResults: Bool
    ) throws {
        if finishViewConfig != nil, !waitForResults {
            let details = "finishViewConfiguration requires waitForResults to be enabled. "
                + "Either remove setFinishViewConfiguration() or call "
                + "waitForResults(true)."
            debugLog("❌ ValidationConfig: \(details)")
            throw TruoraException.sdk(SDKError(
                type: .invalidConfiguration,
                details: details
            ))
        }
    }

    private func validateAutocaptureConfig(_ document: Document) throws {
        let isPassport = document.documentType == NativeDocumentType.passport.rawValue
        if document.didExplicitlyEnableAutocapture, isPassport {
            let details = "Autocapture is not supported for passport document type. "
                + "Remove useAutocapture(true) or use a different document type."
            debugLog("❌ ValidationConfig: \(details)")
            throw TruoraException.sdk(SDKError(
                type: .invalidConfiguration,
                details: details
            ))
        }
    }

    func updateEnrollmentData(_ enrollmentData: EnrollmentData) {
        self.enrollmentData = enrollmentData
    }

    func updateValidationId(_ validationId: String) {
        self.validationId = validationId
        Task { [detectionReporter] in
            await detectionReporter?.updateValidationId(validationId)
        }
    }

    /// Creates and stores a DetectionReporter for injection detection reporting.
    /// Called once per validation flow at the entry point.
    ///
    /// Idempotent and thread-safe: if a provider is already initialised (e.g. called twice
    /// in quick succession from different threads), the existing provider is kept and this
    /// call is a no-op. The check-and-set is serialised with `initializationLock` so two
    /// concurrent callers cannot both pass the guard and leak a second provider (B-cycle2).
    ///
    /// Constructs an `AppAttestProvider` when running on iOS 14+ with a supported
    /// device (App Attest). Falls back to `NoOpAttestationProvider(reason: .unsupported)`
    /// on older OS versions or when the factory returns nil. The provider warm-up
    /// runs in the background and does not block SDK initialisation.
    ///
    /// - Parameter flowType: The flow type for this session ("face" or "document").
    func initializeDetectionReporter(flowType: String) {
        // Serialise the check-and-set so concurrent callers cannot both pass the guard.
        // Held only across the in-memory mutation; no async/Keychain work runs under the lock.
        initializationLock.lock()
        guard attestationProvider == nil else {
            initializationLock.unlock()
            return
        }

        guard let logger = try? TruoraLoggerImplementation.shared else {
            initializationLock.unlock()
            return
        }

        // Build the attestation provider. The factory is gated by #available(iOS 14.0,*)
        // inside AppAttestProvider.create(); on iOS 13 it returns nil.
        // B3-7: Log provider selection so production issues are debuggable.
        let attestation: any AttestationProviding
        let providerName: String
        let providerReason: String
        if #available(iOS 14.0, *), let provider = AppAttestProvider.create(logger: logger) {
            attestation = provider
            providerName = "AppAttestProvider"
            providerReason = "ios14_supported"
        } else {
            attestation = NoOpAttestationProvider(reason: .unsupported)
            providerName = "NoOpAttestationProvider"
            providerReason = "ios14_unavailable_or_unsupported"
        }

        // Fire-and-forget warm-up; does not block SDK initialisation.
        attestationTask = Task { await attestation.start() }
        attestationProvider = attestation

        let detector = InjectionDetector()
        let bridge = NativeDetectionBridge.create()
        detectionReporter = detector.createReporter(
            logger: logger,
            flowType: flowType,
            bridge: bridge,
            attestation: attestation
        )
        initializationLock.unlock()

        // Log provider selection AFTER releasing the lock so the async hop does
        // not pin the lock during a Task launch.
        Task { [logger, providerName, providerReason] in
            await logger.logDevice(
                eventName: "injection_attestation_provider_selected",
                level: .info,
                retention: .oneWeek,
                metadata: [
                    "provider": providerName,
                    "reason": providerReason
                ]
            )
        }
    }

    func reset() {
        logoDownloadTask?.cancel()
        logoDownloadTask = nil
        attestationTask?.cancel()
        attestationTask = nil
        let providerToShutdown = attestationProvider
        attestationProvider = nil
        Task { await providerToShutdown?.shutdown() }
        apiClient = nil
        delegate = nil
        accountId = nil
        validationId = nil
        enrollmentData = nil
        detectionReporter = nil
        // Note: Swift ARC automatically handles cleanup of old UIConfig/Face/Document instances
        // and their nested objects (e.g., ReferenceFace's temp file cleanup via deinit)
        uiConfig = UIConfig()
        lang = nil
        faceConfig = Face()
        documentConfig = Document()
        invoiceConfig = Invoice()
    }

    private func downloadLogoIfNeeded() async {
        #if DEBUG
        if TruoraValidationsSDK.isOfflineMode {
            debugLog("⚠️ ValidationConfig: Skipping logo download in offline mode")
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
                debugLog("⚠️ ValidationConfig: Logo download failed: \(error.localizedDescription)")
            }
        }

        await logoDownloadTask?.value
    }
}
