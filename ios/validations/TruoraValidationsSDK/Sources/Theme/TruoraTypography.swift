//
//  TruoraTypography.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 23/01/26.
//

import SwiftUI
import UIKit

struct TruoraTypography {
    let displayLarge: Font
    let titleLarge: Font
    let titleMedium: Font
    let titleSmall: Font
    let bodyLarge: Font
    let bodyMedium: Font
    let bodySmall: Font
    let labelLarge: Font
    let labelMedium: Font
    let labelSmall: Font

    init() {
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad

        // Design specs: iPhone uses compact sizes; iPad uses larger for readability.
        if isIPad {
            self.displayLarge = .system(size: 120, weight: .semibold)
            self.titleLarge = .system(size: 48, weight: .semibold)
            self.titleMedium = .system(size: 36, weight: .semibold)
            self.titleSmall = .system(size: 28, weight: .medium)
            self.bodyLarge = .system(size: 30, weight: .regular)
            self.bodyMedium = .system(size: 28, weight: .regular)
            self.bodySmall = .system(size: 18, weight: .regular)
            self.labelLarge = .system(size: 24, weight: .medium)
            self.labelMedium = .system(size: 22, weight: .medium)
            self.labelSmall = .system(size: 18, weight: .medium)
        } else {
            self.displayLarge = .system(size: 96, weight: .semibold)
            self.titleLarge = .system(size: 24, weight: .semibold)
            self.titleMedium = .system(size: 18, weight: .semibold)
            self.titleSmall = .system(size: 16, weight: .medium)
            self.bodyLarge = .system(size: 16, weight: .regular)
            self.bodyMedium = .system(size: 16, weight: .regular)
            self.bodySmall = .system(size: 12, weight: .regular)
            self.labelLarge = .system(size: 16, weight: .medium)
            self.labelMedium = .system(size: 16, weight: .medium)
            self.labelSmall = .system(size: 14, weight: .medium)
        }
    }
}
