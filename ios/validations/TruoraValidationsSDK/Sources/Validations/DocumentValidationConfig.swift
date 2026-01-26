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
    private var _shouldWaitForResults: Bool = true
    private var _useAutocapture: Bool = true
    private var _timeoutSeconds: Int = 60

    public required init() {}

    public var country: String {
        _country
    }

    public var documentType: String {
        _documentType
    }

    public var shouldWaitForResults: Bool {
        _shouldWaitForResults
    }

    public var useAutocapture: Bool {
        _useAutocapture
    }

    public var timeoutSeconds: Int {
        _timeoutSeconds
    }

    /// Sets the country code for document validation.
    ///
    /// - Note: If not set, a document selection view will be shown to collect this from the user.
    /// - Parameter country: ISO 3166-1 alpha-2 country code (e.g., "PE", "CO", "MX").
    /// - Returns: This Document for method chaining
    @discardableResult
    public func setCountry(_ country: String) -> Document {
        _country = country
        return self
    }

    /// Sets the document type for validation.
    ///
    /// - Note: If not set, a document selection view will be shown to collect this from the user.
    /// - Parameter documentType: The document type identifier (e.g., "national-id", "passport",
    ///   "driver-license").
    /// - Returns: This Document for method chaining
    @discardableResult
    public func setDocumentType(_ documentType: String) -> Document {
        _documentType = documentType
        return self
    }

    /// Sets whether to wait and show the validation results to the user.
    ///
    /// - Parameter enabled: true to show results view, false to skip it (default: true)
    /// - Returns: This Document for method chaining
    @discardableResult
    public func enableWaitForResults(_ enabled: Bool) -> Document {
        _shouldWaitForResults = enabled
        return self
    }

    /// Sets whether to enable auto-detect and auto-capture of the document.
    ///
    /// - Parameter enabled: true to enable auto-capture, false for manual capture (default: true)
    /// - Returns: This Document for method chaining
    @discardableResult
    public func enableAutocapture(_ enabled: Bool) -> Document {
        _useAutocapture = enabled
        return self
    }

    /// Sets the timeout in seconds for completing the validation.
    /// Negative values will be clamped to 0.
    ///
    /// - Parameter seconds: The timeout duration in seconds (default: 60)
    /// - Returns: This Document for method chaining
    @discardableResult
    public func setTimeout(_ seconds: Int) -> Document {
        _timeoutSeconds = max(seconds, 0)
        return self
    }
}
