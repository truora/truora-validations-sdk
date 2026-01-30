//
//  TruoraTypography.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 23/01/26.
//

import SwiftUI
import UIKit

struct TruoraTypography {
    let titleLarge: Font
    let titleSmall: Font
    let bodyLarge: Font
    let bodyMedium: Font
    let bodySmall: Font

    init() {
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad

        // Typography from Figma specs:
        // iPhone: Title 24pt bold, Body 16pt medium
        // iPad: Title 40pt semibold, Body 30pt regular, Lock 18pt, Button 24pt
        if isIPad {
            self.titleLarge = .system(size: 40, weight: .semibold)
            self.titleSmall = .system(size: 24, weight: .medium)
            self.bodyLarge = .system(size: 30, weight: .regular)
            self.bodyMedium = .system(size: 18, weight: .regular)
            self.bodySmall = .system(size: 18, weight: .regular)
        } else {
            self.titleLarge = .system(size: 24, weight: .bold)
            self.titleSmall = .system(size: 20, weight: .semibold)
            self.bodyLarge = .system(size: 16, weight: .medium)
            self.bodyMedium = .system(size: 14, weight: .regular)
            self.bodySmall = .system(size: 12, weight: .regular)
        }
    }
}
