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
        try await ValidationConfig.shared.configure(
            apiKey: apiKey,
            accountId: accountId,
            delegate: completion,
            baseUrl: baseUrl
        )

        let navController = try ValidationRouter.createDocumentSelectionNavigationController()

        navController.modalPresentationStyle = .fullScreen
        try ValidationRouter.presentFlow(navController: navController, from: viewController)
    }

    /// Cleans up SDK resources
    public func reset() {
        ValidationConfig.shared.reset()
    }

    // MARK: - TruoraValidation

    public class TruoraValidation<T> {
        public let apiKeyGenerator: TruoraAPIKeyGetter
        public let userId: String
        public let uiConfig: UIConfig
        let type: ValidationType

        init(
            apiKeyGenerator: TruoraAPIKeyGetter,
            userId: String,
            uiConfig: UIConfig,
            type: ValidationType
        ) {
            self.apiKeyGenerator = apiKeyGenerator
            self.userId = userId
            self.uiConfig = uiConfig
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
                let apiKey = try await resolveApiKey()

                try await ValidationConfig.shared.configure(
                    apiKey: apiKey,
                    accountId: userId,
                    delegate: completion,
                    baseUrl: nil,
                    uiConfig: uiConfig
                )

                ValidationConfig.shared.setValidation(self.type)

                let navController = try ValidationRouter.createRootNavigationController(of: type)

                navController.modalPresentationStyle = .fullScreen
                viewController.present(navController, animated: true)
            } catch {
                completion?(
                    .failure(.sdk(SDKError(type: .internalError, details: error.localizedDescription)))
                )
            }
        }

        /// Resolves the API key from the provider.
        ///
        /// This method:
        /// 1. Gets the API key from the secure location provider
        /// 2. Validates it's not empty
        /// 3. Decodes the JWT and checks expiration
        /// 4. Returns SDK keys directly
        /// 5. Exchanges generator keys for SDK keys via the Account API
        ///
        /// - Returns: The resolved SDK API key ready to use
        /// - Throws: ValidationError if the API key is invalid or resolution fails
        private func resolveApiKey() async throws -> String {
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

            // Use ApiKeyManager to resolve the key (handles sdk vs generator types)
            do {
                let apiKeyManager = ApiKeyManager()
                return try await apiKeyManager.resolveApiKey(clientApiKey)
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
                validationConfig: validation,
                validationType: .document(validation)
            )
        }
    }

    // MARK: - Typed Builder

    public class TypedBuilder<T> {
        private let apiKeyGenerator: TruoraAPIKeyGetter
        private let userId: String
        private let uiConfig: UIConfig?
        private let validationConfig: T
        private let validationType: ValidationType

        init(
            apiKeyGenerator: TruoraAPIKeyGetter,
            userId: String,
            uiConfig: UIConfig?,
            validationConfig: T,
            validationType: ValidationType
        ) {
            self.apiKeyGenerator = apiKeyGenerator
            self.userId = userId
            self.uiConfig = uiConfig
            self.validationConfig = validationConfig
            self.validationType = validationType
        }

        public func build() -> TruoraValidation<T> {
            TruoraValidation<T>(
                apiKeyGenerator: apiKeyGenerator,
                userId: userId,
                uiConfig: uiConfig ?? UIConfig(),
                type: validationType
            )
        }
    }
}
