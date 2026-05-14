//
//  InvoiceValidationConfig.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 16/04/26.
//

import Foundation

// MARK: - Invoice Validation Configuration

/// Configuration for Invoice (proof of address) validation.
/// Use the builder pattern to configure invoice validation parameters.
///
/// Example:
/// ```swift
/// .withValidation { (invoice: Invoice) in
///     invoice
///         .setCountry("MX")
/// }
/// ```
public class Invoice {
    /// ISO 3166-1 alpha-2 country codes Invoice supports out of the box. Extend this set
    /// when a new market is launched.
    private static let supportedCountries: Set<String> = ["MX", "CO"]

    private var _country: String = ""
    private var _waitForResults: Bool = false
    private var _timeout: Int?
    private var _finishViewConfig: FinishViewConfiguration?

    public required init() {}

    public var country: String {
        _country
    }

    public var waitForResults: Bool {
        _waitForResults
    }

    public var timeout: Int? {
        _timeout
    }

    public var finishViewConfig: FinishViewConfiguration? {
        _finishViewConfig
    }

    /// Sets the country code for invoice validation.
    ///
    /// - Parameter country: ISO 3166-1 alpha-2 country code (e.g., "MX", "CO"). Unsupported
    ///   codes are accepted but logged as a warning so integration issues surface during
    ///   development; the SDK falls back to MX content at render time.
    /// - Returns: This Invoice for method chaining
    @discardableResult
    public func setCountry(_ country: String) -> Invoice {
        if !Self.supportedCountries.contains(country.uppercased()) {
            debugLog(
                "⚠️ Invoice.setCountry: unsupported country '\(country)'. "
                    + "Supported: \(Self.supportedCountries.sorted().joined(separator: ", "))"
            )
        }
        _country = country
        return self
    }

    /// Sets whether to wait and show the validation results to the user.
    ///
    /// - Precondition: Cannot be set to `false` when a `FinishViewConfiguration`
    ///   is already set, because finish view visibility requires waiting for results.
    /// - Parameter enabled: true to show results view, false to skip it (default: false)
    /// - Returns: This Invoice for method chaining
    @discardableResult
    public func waitForResults(_ enabled: Bool) -> Invoice {
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

    /// Sets the timeout in seconds for completing the validation.
    /// Negative values will be clamped to 0.
    ///
    /// - Parameter seconds: The timeout duration in seconds
    /// - Returns: This Invoice for method chaining
    @discardableResult
    public func setTimeout(_ seconds: Int) -> Invoice {
        _timeout = max(seconds, 0)
        return self
    }

    /// Configures the visibility of finish view screens after polling completes.
    ///
    /// - Important: Requires `waitForResults` to be `true` (or not explicitly disabled).
    /// - Parameter config: Configuration controlling success/failure screen visibility
    /// - Returns: This Invoice for method chaining
    @discardableResult
    public func setFinishViewConfiguration(_ config: FinishViewConfiguration) -> Invoice {
        _finishViewConfig = config
        _waitForResults = true
        return self
    }
}
