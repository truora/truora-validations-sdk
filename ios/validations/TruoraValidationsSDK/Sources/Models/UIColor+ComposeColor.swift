//
//  UIColor+ComposeColor.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 21/12/25.
//

import TruoraShared
import UIKit

// MARK: - UIColor Compose Multiplatform Extension

extension UIColor {
    /// Converts UIColor to Compose Color using KMP helper
    /// Used for bridging iOS UIColor to KMP Compose Color
    func toComposeColor() -> UInt64 {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        return TruoraUIExportsKt.createColorFromRGBA(
            red: Float(red),
            green: Float(green),
            blue: Float(blue),
            alpha: Float(alpha)
        )
    }
}
