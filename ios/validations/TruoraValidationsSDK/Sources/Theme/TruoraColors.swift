//
//  TruoraColors.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 23/01/26.
//

import SwiftUI
import UIKit

struct TruoraColors {
    var surface: Color
    var onSurface: Color
    var primary: Color
    var onPrimary: Color
    var secondary: Color
    var error: Color

    // Additional layout colors
    var layoutGray200: Color
    var layoutGray500: Color
    var layoutGray700: Color
    var layoutGray900: Color
    var layoutTint20: Color
    var layoutWarning: Color
    var layoutSuccess: Color
    var layoutRed700: Color
    var layoutOverlay: Color
    var gray800: Color
    var gray600: Color
    var primary900: Color
    var tint: Color
    var tint00: Color

    init(config: UIConfig? = nil) {
        // Defaults matching KMP theme
        let defaultSurface = Color.white
        let defaultOnSurface = Color.black
        let defaultPrimary = Color(red: 0.22, green: 0.0, blue: 0.78) // #3800C7 Truora Purple
        let defaultOnPrimary = Color.white
        let defaultSecondary = Color(red: 0.0, green: 0.8, blue: 0.6) // Truora Green
        let defaultError = Color.red

        // Layout grays (hardcoded to match design system)
        self.layoutGray200 = Color(red: 0.88, green: 0.88, blue: 0.88)
        self.layoutGray500 = Color(red: 0.62, green: 0.62, blue: 0.62)
        self.layoutGray700 = Color(red: 0.38, green: 0.38, blue: 0.38)
        self.layoutGray900 = Color(red: 0.13, green: 0.13, blue: 0.13)
        self.layoutTint20 = Color(red: 0.50, green: 0.51, blue: 0.57) // #808191
        self.layoutWarning = Color(red: 1.00, green: 0.73, blue: 0.00) // #FFBB00
        self.layoutSuccess = Color(red: 0.19, green: 0.77, blue: 0.55) // #31C48D
        self.layoutRed700 = Color(red: 0.73, green: 0.16, blue: 0.16) // #B82828 error red
        self.layoutOverlay = Color(red: 0.12, green: 0.16, blue: 0.18).opacity(0.8) // #1F282D with CC alpha
        self.gray800 = Color(red: 0.12, green: 0.16, blue: 0.22) // #1F2A37
        self.gray600 = Color(red: 0.29, green: 0.33, blue: 0.39) // #4B5563
        self.primary900 = Color(red: 0.03, green: 0.13, blue: 0.33) // #082054
        self.tint = Color(red: 0.16, green: 0.16, blue: 0.16) // #282828
        self.tint00 = Color(red: 0.76, green: 0.76, blue: 0.80) // #C2C2CB Truora/Tint 00

        // Apply config overrides if present
        if let config {
            self.surface = config.surface.map { Color($0) } ?? defaultSurface
            self.onSurface = config.onSurface.map { Color($0) } ?? defaultOnSurface
            self.primary = config.primary.map { Color($0) } ?? defaultPrimary
            self.onPrimary = config.onPrimary.map { Color($0) } ?? defaultOnPrimary
            self.secondary = config.secondary.map { Color($0) } ?? defaultSecondary
            self.error = config.error.map { Color($0) } ?? defaultError
        } else {
            self.surface = defaultSurface
            self.onSurface = defaultOnSurface
            self.primary = defaultPrimary
            self.onPrimary = defaultOnPrimary
            self.secondary = defaultSecondary
            self.error = defaultError
        }
    }
}
