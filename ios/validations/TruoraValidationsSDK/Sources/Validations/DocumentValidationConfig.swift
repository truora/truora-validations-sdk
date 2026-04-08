//
//  DocumentValidationConfig.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 07/01/26.
//

import Foundation

// MARK: - Document Validation Configuration

/// Configuration for Document Capture validation.
/// Use the builder pattern to configure document validation parameters.
///
/// - Note: If `country` and `documentType` are not explicitly set, a document selection
///   view will be presented to collect these inputs from the user before proceeding.
///
/// Example:
/// ```swift
/// .withValidation { (document: Document) in
///     document
///         .setCountry("PE")
///         .setDocumentType("national-id")
/// }
/// ```
public class Document {
    private var _country: String = ""
    private var _documentType: String = ""
    private var _allowedCountries: String = ""
    private var _allowedDocumentTypes: String = ""
    private var _waitForResults: Bool = false
    private var _useAutocapture: Bool = true
    private var _didExplicitlyEnableAutocapture: Bool = false
    private var _timeout: Int?
    private var _finishViewConfig: FinishViewConfiguration?

    public required init() {}

    /// The country code for pre-selection (single value only).
    public var country: String {
        _country
    }

    /// The document type for pre-selection (single value only).
    public var documentType: String {
        _documentType
    }

    /// The allowed countries string (comma-separated for multiple values).
    public var allowedCountries: String {
        _allowedCountries
    }

    /// The allowed document types string (comma-separated for multiple values).
    public var allowedDocumentTypes: String {
        _allowedDocumentTypes
    }

    /// Returns the list of allowed country codes parsed from the allowedCountries string.
    var allowedCountriesList: [String] {
        guard !_allowedCountries.isEmpty else { return [] }
        return _allowedCountries.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    /// Returns the list of allowed document types parsed from the allowedDocumentTypes string.
    var allowedDocumentTypesList: [String] {
        guard !_allowedDocumentTypes.isEmpty else { return [] }
        return _allowedDocumentTypes.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    /// Returns true if exactly one country is configured in allowedCountries.
    var hasSingleAllowedCountry: Bool {
        allowedCountriesList.count == 1
    }

    /// Returns true if exactly one document type is configured in allowedDocumentTypes.
    var hasSingleAllowedDocumentType: Bool {
        allowedDocumentTypesList.count == 1
    }

    /// Returns true if a country is configured for pre-selection (legacy field).
    var hasSingleCountry: Bool {
        !_country.isEmpty
    }

    /// Returns true if a document type is configured for pre-selection (legacy field).
    var hasSingleDocumentType: Bool {
        !_documentType.isEmpty
    }

    /// Returns the effective country for pre-selection, prioritizing allowedCountries over country.
    var effectivePreselectedCountry: String? {
        if hasSingleAllowedCountry {
            return allowedCountriesList.first
        }
        if hasSingleCountry {
            return _country
        }
        return nil
    }

    /// Returns the effective document type for pre-selection, prioritizing allowedDocumentTypes over documentType.
    var effectivePreselectedDocumentType: String? {
        if hasSingleAllowedDocumentType {
            return allowedDocumentTypesList.first
        }
        if hasSingleDocumentType {
            return _documentType
        }
        return nil
    }

    public var waitForResults: Bool {
        _waitForResults
    }

    public var useAutocapture: Bool {
        _useAutocapture
    }

    /// Whether the developer explicitly called ``useAutocapture(true)``.
    /// Used by ``ValidationConfig`` defense-in-depth validation to distinguish
    /// explicit opt-in from the default `true` value.
    var didExplicitlyEnableAutocapture: Bool {
        _didExplicitlyEnableAutocapture
    }

    public var timeout: Int? {
        _timeout
    }

    public var finishViewConfig: FinishViewConfiguration? {
        _finishViewConfig
    }

    /// Sets the country code for pre-selection and locking.
    ///
    /// When set, the country is pre-selected and the user cannot change it.
    /// Use ``setAllowedCountries(_:)`` to filter available countries without locking.
    ///
    /// - Note: If not set, a document selection view will show countries based on
    ///   ``setAllowedCountries(_:)`` or all supported countries if that is also not set.
    /// - Parameter country: ISO 3166-1 alpha-2 country code (e.g., "PE", "CO").
    /// - Returns: This Document for method chaining
    @discardableResult
    public func setCountry(_ country: String) -> Document {
        _country = country
        return self
    }

    /// Sets the document type for pre-selection and locking.
    ///
    /// When set, the document type is pre-selected and the user cannot change it.
    /// Use ``setAllowedDocumentTypes(_:)`` to filter available types without locking.
    ///
    /// When `"passport"` is set, autocapture is silently disabled because the ML model
    /// does not work reliably on passports. If the developer also called
    /// ``useAutocapture(true)``, ``ValidationConfig/setValidation(_:)`` will throw
    /// a catchable ``TruoraException`` at start time.
    ///
    /// - Note: If not set, a document selection view will show types based on
    ///   ``setAllowedDocumentTypes(_:)`` or all supported types for the country if that is also not set.
    /// - Parameter documentType: The document type identifier (e.g., "national-id", "passport").
    /// - Returns: This Document for method chaining
    @discardableResult
    public func setDocumentType(_ documentType: String) -> Document {
        _documentType = documentType
        if documentType == NativeDocumentType.passport.rawValue {
            _useAutocapture = false
        }
        return self
    }

    /// Sets the allowed country codes for the document selection picker.
    ///
    /// When set, only these countries will be shown in the picker.
    /// The user can select any of the allowed countries.
    /// Use ``setCountry(_:)`` to pre-select and lock a specific country.
    ///
    /// - Parameter countries: Comma-separated ISO 3166-1 alpha-2 country codes (e.g., "PE,CO,MX").
    /// - Returns: This Document for method chaining
    @discardableResult
    public func setAllowedCountries(_ countries: String) -> Document {
        _allowedCountries = countries
        return self
    }

    /// Sets the allowed document types for the document selection picker.
    ///
    /// When set, only these document types will be shown in the picker.
    /// The user can select any of the allowed types.
    /// Use ``setDocumentType(_:)`` to pre-select and lock a specific type.
    ///
    /// - Parameter documentTypes: Comma-separated document type identifiers
    ///   (e.g., "national-id,passport,foreign-id").
    /// - Returns: This Document for method chaining
    @discardableResult
    public func setAllowedDocumentTypes(_ documentTypes: String) -> Document {
        _allowedDocumentTypes = documentTypes
        return self
    }

    /// Sets whether to wait and show the validation results to the user.
    ///
    /// - Precondition: Cannot be set to `false` when a `FinishViewConfiguration`
    ///   is already set, because finish view visibility requires waiting for results.
    ///   Remove `setFinishViewConfiguration()` first or keep `waitForResults` enabled.
    /// - Parameter enabled: true to show results view, false to skip it (default: false)
    /// - Returns: This Document for method chaining
    @discardableResult
    public func waitForResults(_ enabled: Bool) -> Document {
        if !enabled, _finishViewConfig != nil {
            preconditionFailure(
                "waitForResults(false) cannot be called when "
                    + "finishViewConfiguration is set. Remove "
                    + "setFinishViewConfiguration() first."
            )
        }
        _waitForResults = enabled
        return self
    }

    /// Sets whether to enable auto-detect and auto-capture of the document.
    ///
    /// When `true` is passed but the document type is already `"passport"`, autocapture
    /// stays disabled (passports are not supported). The explicit intent is still recorded
    /// so that ``ValidationConfig/setValidation(_:)`` can throw a catchable
    /// ``TruoraException`` at start time, letting the developer fix their configuration.
    ///
    /// - Parameter enabled: true to enable auto-capture, false for manual capture (default: true)
    /// - Returns: This Document for method chaining
    @discardableResult
    public func useAutocapture(_ enabled: Bool) -> Document {
        let isPassport = _documentType == NativeDocumentType.passport.rawValue
        _useAutocapture = enabled && !isPassport
        _didExplicitlyEnableAutocapture = enabled
        return self
    }

    /// Internal: sets the document type from a runtime user selection
    /// (e.g. the document selection screen).
    ///
    /// Unlike ``setDocumentType(_:)``, this method also resets
    /// ``didExplicitlyEnableAutocapture`` so that a prior ``useAutocapture(true)``
    /// call from the Builder does not cause ``ValidationConfig/setValidation(_:)``
    /// to throw when the user picks passport at runtime.
    @discardableResult
    func applyRuntimeDocumentType(_ documentType: String) -> Document {
        _documentType = documentType
        if documentType == NativeDocumentType.passport.rawValue {
            _useAutocapture = false
            _didExplicitlyEnableAutocapture = false
        }
        return self
    }

    /// Sets the timeout in seconds for completing the validation.
    /// Negative values will be clamped to 0.
    ///
    /// - Parameter seconds: The timeout duration in seconds (default: 60)
    /// - Returns: This Document for method chaining
    @discardableResult
    public func setTimeout(_ seconds: Int) -> Document {
        _timeout = max(seconds, 0)
        return self
    }

    /// Configures the visibility of finish view screens after polling completes.
    ///
    /// - Important: Requires `waitForResults` to be `true` (or not explicitly disabled).
    ///   The SDK will throw an `invalidConfiguration` error at start time if both
    ///   `finishViewConfiguration` is set and `waitForResults` is `false`.
    /// - Parameter config: Configuration controlling success/failure screen visibility
    /// - Returns: This Document for method chaining
    @discardableResult
    public func setFinishViewConfiguration(_ config: FinishViewConfiguration) -> Document {
        _finishViewConfig = config
        _waitForResults = true
        return self
    }
}
