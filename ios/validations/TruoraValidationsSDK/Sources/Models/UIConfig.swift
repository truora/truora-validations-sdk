//
//  UIConfig.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 17/11/25.
//

import UIKit

/// Configuration for SDK UI customization.
/// Use the builder pattern to configure UI appearance.
public class UIConfig {
    private static let maxLogoSizeBytes: Int = 5 * 1024 * 1024 // 5MB (Android parity)

    private var _surface: UIColor?
    private var _onSurface: UIColor?
    private var _primary: UIColor?
    private var _onPrimary: UIColor?
    private var _secondary: UIColor?
    private var _error: UIColor?

    private var _logoUrl: String?
    private var _customLogoData: Data?
    private var _logoWidth: CGFloat?
    private var _logoHeight: CGFloat?
    private var _language: TruoraLanguage = .english

    public init() {}

    public var surface: UIColor? {
        _surface
    }

    public var onSurface: UIColor? {
        _onSurface
    }

    public var primary: UIColor? {
        _primary
    }

    public var onPrimary: UIColor? {
        _onPrimary
    }

    public var secondary: UIColor? {
        _secondary
    }

    public var error: UIColor? {
        _error
    }

    public var logoUrl: String? {
        _logoUrl
    }

    public var customLogoData: Data? {
        _customLogoData
    }

    public var logoWidth: CGFloat? {
        _logoWidth
    }

    public var logoHeight: CGFloat? {
        _logoHeight
    }

    public var language: TruoraLanguage {
        _language
    }

    /// Sets the surface color for UI elements.
    /// - Parameter color: UIColor for surface elements
    /// - Returns: This UIConfig for method chaining
    @discardableResult
    public func setSurfaceColor(_ color: UIColor) -> UIConfig {
        _surface = color
        return self
    }

    /// Sets the surface color for UI elements using a hex string.
    /// - Parameter colorHex: Hex color string (e.g., "#FF5722")
    /// - Returns: This UIConfig for method chaining
    @discardableResult
    public func setSurfaceColor(_ colorHex: String) -> UIConfig {
        if let color = UIColor(hex: colorHex) {
            _surface = color
        }
        return self
    }

    /// Sets the onSurface color for UI elements.
    /// - Parameter color: UIColor for onSurface elements
    /// - Returns: This UIConfig for method chaining
    @discardableResult
    public func setOnSurfaceColor(_ color: UIColor) -> UIConfig {
        _onSurface = color
        return self
    }

    /// Sets the onSurface color for UI elements using a hex string.
    /// - Parameter colorHex: Hex color string (e.g., "#FFFFFF")
    /// - Returns: This UIConfig for method chaining
    @discardableResult
    public func setOnSurfaceColor(_ colorHex: String) -> UIConfig {
        if let color = UIColor(hex: colorHex) {
            _onSurface = color
        }
        return self
    }

    /// Sets the primary color for UI elements.
    /// - Parameter color: UIColor for primary elements
    /// - Returns: This UIConfig for method chaining
    @discardableResult
    public func setPrimaryColor(_ color: UIColor) -> UIConfig {
        _primary = color
        return self
    }

    /// Sets the primary color for UI elements using a hex string.
    /// - Parameter colorHex: Hex color string (e.g., "#FFFFFF")
    /// - Returns: This UIConfig for method chaining
    @discardableResult
    public func setPrimaryColor(_ colorHex: String) -> UIConfig {
        if let color = UIColor(hex: colorHex) {
            _primary = color
        }
        return self
    }

    /// Sets the onPrimary color for UI elements.
    /// - Parameter color: UIColor for onPrimary elements
    /// - Returns: This UIConfig for method chaining
    @discardableResult
    public func setOnPrimaryColor(_ color: UIColor) -> UIConfig {
        _onPrimary = color
        return self
    }

    /// Sets the onPrimary color for UI elements using a hex string.
    /// - Parameter colorHex: Hex color string (e.g., "#FFFFFF")
    /// - Returns: This UIConfig for method chaining
    @discardableResult
    public func setOnPrimaryColor(_ colorHex: String) -> UIConfig {
        if let color = UIColor(hex: colorHex) {
            _onPrimary = color
        }
        return self
    }

    /// Sets the secondary color for UI elements.
    /// - Parameter color: UIColor for secondary elements
    /// - Returns: This UIConfig for method chaining
    @discardableResult
    public func setSecondaryColor(_ color: UIColor) -> UIConfig {
        _secondary = color
        return self
    }

    /// Sets the secondary color for UI elements using a hex string.
    /// - Parameter colorHex: Hex color string (e.g., "#FFFFFF")
    /// - Returns: This UIConfig for method chaining
    @discardableResult
    public func setSecondaryColor(_ colorHex: String) -> UIConfig {
        if let color = UIColor(hex: colorHex) {
            _secondary = color
        }
        return self
    }

    /// Sets the error color for UI elements.
    /// - Parameter color: UIColor for error elements
    /// - Returns: This UIConfig for method chaining
    @discardableResult
    public func setErrorColor(_ color: UIColor) -> UIConfig {
        _error = color
        return self
    }

    /// Sets the error color for UI elements using a hex string.
    /// - Parameter colorHex: Hex color string (e.g., "#FFFFFF")
    /// - Returns: This UIConfig for method chaining
    @discardableResult
    public func setErrorColor(_ colorHex: String) -> UIConfig {
        if let color = UIColor(hex: colorHex) {
            _error = color
        }
        return self
    }

    /// Sets the logo URL to display in the SDK UI.
    /// - Parameter logoUrl: URL pointing to the logo image
    /// - Returns: This UIConfig for method chaining
    @discardableResult
    public func setLogo(_ logoUrl: String) -> UIConfig {
        setLogo(logoUrl, width: nil, height: nil)
    }

    /// Sets the logo URL to display in the SDK UI, with optional dimensions.
    /// Only supports `https` scheme for security (Android parity).
    /// - Parameters:
    ///   - logoUrl: URL pointing to the logo image
    ///   - width: Optional logo width in points (must be positive and finite if provided)
    ///   - height: Optional logo height in points (must be positive and finite if provided)
    /// - Returns: This UIConfig for method chaining
    @discardableResult
    public func setLogo(_ logoUrl: String, width: CGFloat?, height: CGFloat?) -> UIConfig {
        guard let url = URL(string: logoUrl), url.scheme?.lowercased() == "https" else { return self }
        guard Self.isValidDimension(width), Self.isValidDimension(height) else { return self }

        _customLogoData = nil
        _logoUrl = logoUrl
        _logoWidth = width
        _logoHeight = height
        return self
    }

    /// Sets a custom logo directly using raw image bytes (PNG/JPEG recommended).
    /// - Parameters:
    ///   - logoData: Image bytes (must be non-empty and <= 5MB)
    ///   - width: Optional logo width in points (must be positive and finite if provided)
    ///   - height: Optional logo height in points (must be positive and finite if provided)
    /// - Returns: This UIConfig for method chaining
    @discardableResult
    public func setCustomLogo(_ logoData: Data, width: CGFloat? = nil, height: CGFloat? = nil) -> UIConfig {
        guard !logoData.isEmpty, logoData.count <= Self.maxLogoSizeBytes else { return self }
        guard Self.isValidDimension(width), Self.isValidDimension(height) else { return self }

        _logoUrl = nil
        _customLogoData = logoData
        _logoWidth = width
        _logoHeight = height
        return self
    }

    /// Sets the language for SDK UI.
    /// - Parameter language: The language to use
    /// - Returns: This UIConfig for method chaining
    @discardableResult
    public func setLanguage(_ language: TruoraLanguage) -> UIConfig {
        _language = language
        return self
    }

    private static func isValidDimension(_ value: CGFloat?) -> Bool {
        guard let value else { return true }
        return value.isFinite && value > 0
    }
}

// MARK: - UIColor Hex Extension

extension UIColor {
    /// Initializes a UIColor from a hex string.
    /// - Parameter hex: Hex color string (e.g., "#FF5722" or "FF5722")
    convenience init?(hex: String) {
        let hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove the # prefix if present
        let hexWithoutPrefix =
            hexString.hasPrefix("#")
            ? String(hexString.dropFirst())
            : hexString

        // Validate length - must be exactly 6 characters
        guard hexWithoutPrefix.count == 6 else {
            return nil
        }

        let scanner = Scanner(string: hexWithoutPrefix)

        var color: UInt64 = 0
        guard scanner.scanHexInt64(&color) else { return nil }

        let mask = 0x0000_00FF
        let redComponent = Int(color >> 16) & mask
        let greenComponent = Int(color >> 8) & mask
        let blueComponent = Int(color) & mask

        let red = CGFloat(redComponent) / 255.0
        let green = CGFloat(greenComponent) / 255.0
        let blue = CGFloat(blueComponent) / 255.0

        self.init(red: red, green: green, blue: blue, alpha: 1.0)
    }
}
