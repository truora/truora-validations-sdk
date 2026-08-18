//
//  TruoraColors.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 23/01/26.
//

import SwiftUI
import UIKit

extension Color {
    /// Converts a SwiftUI Color to UIColor.
    /// iOS 14+: uses native UIColor(Color) initializer.
    /// iOS 13: parses the hex description that SwiftUI produces for RGB colors.
    /// Falls back to white if parsing fails (e.g. for named or system colors).
    var uiColor: UIColor {
        if #available(iOS 14.0, *) {
            return UIColor(self)
        }
        let desc = String(describing: self)
        guard desc.hasPrefix("#"), desc.count >= 7 else {
            assertionFailure("Color.uiColor: unable to parse color description '\(desc)' on iOS 13")
            return .white
        }
        let hex = String(desc.dropFirst().prefix(6))
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        guard scanner.scanHexInt64(&rgb) else { return .white }
        return UIColor(
            red: CGFloat((rgb >> 16) & 0xFF) / 255.0,
            green: CGFloat((rgb >> 8) & 0xFF) / 255.0,
            blue: CGFloat(rgb & 0xFF) / 255.0,
            alpha: 1.0
        )
    }
}

struct TruoraColors {
    var surface: Color
    var onSurface: Color
    var primary: Color
    var onPrimary: Color
    var secondary: Color
    var onSecondary: Color
    var surfaceVariant: Color
    var onSurfaceVariant: Color
    var error: Color

    // Additional layout colors
    var layoutGray200: Color
    var layoutGray500: Color
    var layoutGray700: Color
    var layoutGray900: Color
    var layoutTint20: Color
    var layoutTint50: Color
    var layoutWarning: Color
    var layoutSuccess: Color
    var layoutRed700: Color
    var layoutOverlay: Color
    var faceOverlayColor: Color
    var gray800: Color
    var gray600: Color
    var primary900: Color
    var tint: Color
    var tint00: Color

    init(config: UIConfig? = nil) {
        // Defaults matching KMP Theme.kt (TruoraExtendedColors)
        let defaultSurface = Color.white
        let defaultOnSurface = Color(red: 0.16, green: 0.16, blue: 0.16) // #282828
        let defaultPrimary = Color(red: 0.22, green: 0.0, blue: 0.78) // #3800C7 Truora Purple
        let defaultOnPrimary = Color.white
        let defaultSecondary = Color(red: 0.12, green: 0.16, blue: 0.22) // #1F2A37 - help text on capture screens
        let defaultOnSecondary = Color.white
        let defaultSurfaceVariant = Color(red: 0.03, green: 0.13, blue: 0.33) // #082054 - capture/loading background
        let defaultOnSurfaceVariant = Color.white
        let defaultError = Color(red: 1.0, green: 0.33, blue: 0.33) // #FF5454

        // Layout grays (hardcoded to match design system)
        self.layoutGray200 = Color(red: 0.88, green: 0.88, blue: 0.88)
        self.layoutGray500 = Color(red: 0.62, green: 0.62, blue: 0.62)
        self.layoutGray700 = Color(red: 0.38, green: 0.38, blue: 0.38)
        self.layoutGray900 = Color(red: 0.13, green: 0.13, blue: 0.13)
        self.layoutTint20 = Color(red: 0.50, green: 0.51, blue: 0.57) // #808191
        self.layoutTint50 = Color(red: 0.318, green: 0.361, blue: 0.388) // #515C63
        self.layoutWarning = Color(red: 0.929, green: 0.835, blue: 0.608) // #EDD59B feedback pill background
        self.layoutSuccess = Color(red: 0.19, green: 0.77, blue: 0.55) // #31C48D
        self.layoutRed700 = Color(red: 0.73, green: 0.16, blue: 0.16) // #B82828 error red
        self.layoutOverlay = Color(red: 0.12, green: 0.16, blue: 0.18).opacity(0.8) // #1F282D with CC alpha
        self.faceOverlayColor = Color(red: 0.847, green: 0.608, blue: 0.216) // #D89B37 guide oval
        self.gray800 = Color(red: 0.12, green: 0.16, blue: 0.22) // #1F2A37
        self.gray600 = Color(red: 0.29, green: 0.33, blue: 0.39) // #4B5563
        self.primary900 = Color(red: 0.03, green: 0.13, blue: 0.33) // #082054
        self.tint = Color(red: 0.16, green: 0.16, blue: 0.16) // #282828
        self.tint00 = Color(red: 0.76, green: 0.76, blue: 0.80) // #C2C2CB

        // Apply config overrides if present
        if let config {
            self.surface = config.surface.map { Color($0) } ?? defaultSurface
            self.onSurface = config.onSurface.map { Color($0) } ?? defaultOnSurface
            self.primary = config.primary.map { Color($0) } ?? defaultPrimary
            self.onPrimary = config.onPrimary.map { Color($0) } ?? defaultOnPrimary
            self.secondary = config.secondary.map { Color($0) } ?? defaultSecondary
            self.onSecondary = config.onSecondary.map { Color($0) } ?? defaultOnSecondary
            self.surfaceVariant = config.surfaceVariant.map { Color($0) } ?? defaultSurfaceVariant
            self.onSurfaceVariant = config.onSurfaceVariant.map { Color($0) } ?? defaultOnSurfaceVariant
            self.error = config.error.map { Color($0) } ?? defaultError
        } else {
            self.surface = defaultSurface
            self.onSurface = defaultOnSurface
            self.primary = defaultPrimary
            self.onPrimary = defaultOnPrimary
            self.secondary = defaultSecondary
            self.onSecondary = defaultOnSecondary
            self.surfaceVariant = defaultSurfaceVariant
            self.onSurfaceVariant = defaultOnSurfaceVariant
            self.error = defaultError
        }
    }
}
