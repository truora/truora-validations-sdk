//
//  TruoraTheme.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 23/01/26.
//

import Combine
import SwiftUI

class TruoraTheme: ObservableObject {
    @Published var colors: TruoraColors
    @Published var typography: TruoraTypography
    @Published var logo: LogoConfig?

    struct LogoConfig {
        let logoData: Data?
        let width: CGFloat?
        let height: CGFloat?
    }

    init(config: UIConfig? = nil) {
        self.colors = TruoraColors(config: config)
        self.typography = TruoraTypography()

        if let config, let logoData = config.customLogoData {
            self.logo = LogoConfig(
                logoData: logoData,
                width: config.logoWidth,
                height: config.logoHeight
            )
        }
    }
}
