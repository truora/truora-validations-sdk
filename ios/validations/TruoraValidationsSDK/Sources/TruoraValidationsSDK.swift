//
//  TruoraValidationsSDK.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 30/10/25.
//

import Foundation
import UIKit

// MARK: - Main SDK Entry Point

public class TruoraValidationsSDK {
    public static let shared = TruoraValidationsSDK()

    #if DEBUG
    /// Helper flag to disable network requests for UI testing
    /// When true, API calls are mocked with successful responses
    /// Only available in DEBUG builds to prevent accidental production use
    public static var isOfflineMode = false
    #endif

    private init() {}

    /// Starts the document validation flow.
    ///
    /// The flow starts with DocumentSelection, requests camera permission up-front, and then
    /// continues to DocumentIntro once the user selects the country and document type.
    /// - Parameters:
    ///   - viewController: The view controller to present the flow from
    ///   - accountId: The account ID for the validation
    ///   - apiKey: Your Truora API key
    ///   - baseUrl: Optional custom base URL for the API
    ///   - completion: Closure to handle the validation callbacks
    @MainActor
    public func startDocumentIntro(
        from viewController: UIViewController,
        accountId: String,
        apiKey: String,
        baseUrl: String? = nil,
        completion: ((TruoraValidationResult<ValidationResult>) -> Void)? = nil
    ) async throws {
        // Initialize logger before starting validation
        try await initializeLogger(apiKey: apiKey)

        try await ValidationConfig.shared.configure(
            apiKey: apiKey,
            accountId: accountId,
            delegate: completion,
            baseUrl: baseUrl
        )

        // Layer 1: Initialize injection detection and report init
        ValidationConfig.shared.initializeDetectionReporter(flowType: "document")
        if let reporter = ValidationConfig.shared.detectionReporter {
            let shouldBlock = await reporter.reportLayer("init")
            if shouldBlock {
                completion?(.error(TruoraException.sdk(
                    SDKError(type: .validationInterrupted)
                )))
                return
            }
        }

        let navController = try ValidationRouter.createDocumentSelectionNavigationController()

        navController.modalPresentationStyle = .fullScreen
        try ValidationRouter.presentFlow(navController: navController, from: viewController)
    }

    /// Initializes the logger singleton.
    /// Called automatically when starting a validation flow.
    private func initializeLogger(apiKey: String) async throws {
        guard !TruoraLoggerImplementation.isInitialized else {
            return // Already initialized
        }

        let sdkVersion = TruoraSDKVersion.current

        let config = LoggerConfiguration.production(apiKey: apiKey, sdkVersion: sdkVersion)
        try await TruoraLoggerImplementation.initialize(with: config)
    }

    /// Cleans up SDK resources
    public func reset() async {
        ValidationConfig.shared.reset()
        await TruoraLoggerImplementation.reset()
    }

    // MARK: - TruoraValidation

    public class TruoraValidation<T> {
        public let apiKeyGenerator: TruoraAPIKeyGetter
        public let userId: String
        public let uiConfig: UIConfig
        /// Language set by the client, or nil when using device locale.
        public let lang: TruoraLanguage?
        let type: ValidationType

        init(
            apiKeyGenerator: TruoraAPIKeyGetter,
            userId: String,
            uiConfig: UIConfig,
            lang: TruoraLanguage?,
            type: ValidationType
        ) {
            self.apiKeyGenerator = apiKeyGenerator
            self.userId = userId
            self.uiConfig = uiConfig
            self.lang = lang
            self.type = type
        }

        /// Starts the validation flow using the configured settings
        /// - Parameters:
        ///   - viewController: The view controller to present the validation flow from
        ///   - completion: Closure to handle the validation callbacks
        /// - Important: Use `[weak self]` in your completion closure to avoid memory leaks.
        ///   Example: `completion: { [weak self] result in self?.handleResult(result) }`
        @MainActor
        public func start(
            from viewController: UIViewController,
            completion: ((TruoraValidationResult<ValidationResult>) -> Void)? = nil
        ) async {
            do {
                let apiKey = try await validateApiKey()

                // Initialize logger before starting validation
                try await TruoraValidationsSDK.shared.initializeLogger(apiKey: apiKey)

                try await ValidationConfig.shared.configure(
                    apiKey: apiKey,
                    accountId: userId,
                    delegate: completion,
                    baseUrl: nil,
                    uiConfig: uiConfig,
                    lang: lang
                )

                try ValidationConfig.shared.setValidation(self.type)

                // Layer 1: Initialize injection detection and report init
                let flowTypeString = switch self.type {
                case .face: "face"
                case .document: "document"
                case .invoice: "invoice"
                }
                ValidationConfig.shared.initializeDetectionReporter(flowType: flowTypeString)
                if let reporter = ValidationConfig.shared.detectionReporter {
                    let shouldBlock = await reporter.reportLayer("init")
                    if shouldBlock {
                        completion?(.error(TruoraException.sdk(
                            SDKError(type: .validationInterrupted)
                        )))
                        return
                    }
                }

                let navController = try ValidationRouter.createRootNavigationController(of: type)

                navController.modalPresentationStyle = .fullScreen
                viewController.present(navController, animated: true)
            } catch {
                completion?(
                    .error(.sdk(SDKError(type: .internalError, details: error.localizedDescription)))
                )
            }
        }

        /// Validates the API key from the provider.
        ///
        /// This method:
        /// 1. Gets the API key from the secure location provider
        /// 2. Validates it's not empty
        /// 3. Validates the JWT: key_type must be "sdk", expiration, and application_id must match bundle ID
        ///
        /// - Returns: The validated SDK API key ready to use
        /// - Throws: ValidationError if the API key is invalid or validation fails
        private func validateApiKey() async throws -> String {
            let clientApiKey = try await apiKeyGenerator.getApiKeyFromSecureLocation()

            guard !clientApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw TruoraException.sdk(
                    SDKError(type: .invalidConfiguration, details: "API key cannot be null or empty")
                )
            }

            #if DEBUG
            // Skip network validation in offline mode (DEBUG only)
            if TruoraValidationsSDK.isOfflineMode {
                return clientApiKey
            }
            #endif

            // Use ApiKeyManager to validate the key (SDK type only, application_id must match bundle ID)
            do {
                let apiKeyManager = ApiKeyManager()
                return try await apiKeyManager.validateApiKey(clientApiKey)
            } catch let error as ApiKeyError {
                throw error.toTruoraException()
            }
        }
    }

    // MARK: - Builder Pattern

    public class Builder {
        private let apiKeyGenerator: TruoraAPIKeyGetter
        private let userId: String
        private var uiConfig: UIConfig?
        private var lang: TruoraLanguage?

        public init(apiKeyGenerator: TruoraAPIKeyGetter, userId: String) {
            self.apiKeyGenerator = apiKeyGenerator
            self.userId = userId
        }

        /// Configures validation UI with provided options.
        /// - Parameter configurator: A closure that receives an UIConfig object and returns
        ///   the configuration with the options applied
        /// - Returns: An UIConfig object
        @discardableResult
        public func withConfig(_ configurator: (UIConfig) -> UIConfig) -> Builder {
            uiConfig = configurator(UIConfig())
            return self
        }

        /// Sets the language for the SDK UI. When not called, the SDK uses the device locale.
        /// - Parameter lang: The language to use
        /// - Returns: This Builder for method chaining
        @discardableResult
        public func withLanguage(_ lang: TruoraLanguage) -> Builder {
            self.lang = lang
            return self
        }

        /// Configures Face validation with the provided configuration options.
        /// - Parameter validationConfigurator: A closure that receives a Face configuration object
        ///   and returns the configured Face
        /// - Returns: A TypedBuilder for Face validation
        @discardableResult
        public func withValidation<T: Face>(
            _ validationConfigurator: (T) -> T
        ) -> TypedBuilder<T> {
            let validation = validationConfigurator(T())
            return TypedBuilder<T>(
                apiKeyGenerator: apiKeyGenerator,
                userId: userId,
                uiConfig: uiConfig,
                lang: lang,
                validationConfig: validation,
                validationType: .face(validation)
            )
        }

        /// Configures Document validation with the provided configuration options.
        /// - Parameter validationConfigurator: A closure that receives a Document configuration object
        ///   and returns the configured Document
        /// - Returns: A TypedBuilder for Document validation
        @discardableResult
        public func withValidation<T: Document>(
            _ validationConfigurator: (T) -> T
        ) -> TypedBuilder<T> {
            let validation = validationConfigurator(T())
            return TypedBuilder<T>(
                apiKeyGenerator: apiKeyGenerator,
                userId: userId,
                uiConfig: uiConfig,
                lang: lang,
                validationConfig: validation,
                validationType: .document(validation)
            )
        }

        /// Configures Invoice validation with the provided configuration options.
        /// - Parameter validationConfigurator: A closure that receives an Invoice configuration object
        ///   and returns the configured Invoice
        /// - Returns: A TypedBuilder for Invoice validation
        @discardableResult
        public func withValidation<T: Invoice>(
            _ validationConfigurator: (T) -> T
        ) -> TypedBuilder<T> {
            let validation = validationConfigurator(T())
            return TypedBuilder<T>(
                apiKeyGenerator: apiKeyGenerator,
                userId: userId,
                uiConfig: uiConfig,
                lang: lang,
                validationConfig: validation,
                validationType: .invoice(validation)
            )
        }
    }

    // MARK: - Typed Builder

    public class TypedBuilder<T> {
        private let apiKeyGenerator: TruoraAPIKeyGetter
        private let userId: String
        private let uiConfig: UIConfig?
        private let lang: TruoraLanguage?
        private let validationConfig: T
        private let validationType: ValidationType

        init(
            apiKeyGenerator: TruoraAPIKeyGetter,
            userId: String,
            uiConfig: UIConfig?,
            lang: TruoraLanguage?,
            validationConfig: T,
            validationType: ValidationType
        ) {
            self.apiKeyGenerator = apiKeyGenerator
            self.userId = userId
            self.uiConfig = uiConfig
            self.lang = lang
            self.validationConfig = validationConfig
            self.validationType = validationType
        }

        public func build() -> TruoraValidation<T> {
            let finalUIConfig = uiConfig ?? UIConfig()
            return TruoraValidation<T>(
                apiKeyGenerator: apiKeyGenerator,
                userId: userId,
                uiConfig: finalUIConfig,
                lang: lang,
                type: validationType
            )
        }
    }
}
