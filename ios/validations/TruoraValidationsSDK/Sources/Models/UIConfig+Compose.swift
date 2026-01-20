//
//  UIConfig+Compose.swift
//  validations
//
//  Created by Sergio Guzman on 23/12/25.
//

import TruoraShared
import UIKit

public extension UIConfig {
    func toTruoraConfig() -> TruoraUIConfig {
        let colors: TruoraCustomColors? = TruoraCustomColors(
            surface: surface?.toComposeColor(),
            onSurface: onSurface?.toComposeColor(),
            primary: primary?.toComposeColor(),
            onPrimary: onPrimary?.toComposeColor(),
            secondary: secondary?.toComposeColor(),
            error: error?.toComposeColor(),

            // Default theme values
            tint00: nil,
            tint20: nil,
            warning: nil,
            success: nil,
            overlay: nil,
            secondaryBg: nil,
            infoBlue: nil,
            gray50: nil,
            gray200: nil,
            gray500: nil,
            gray700: nil,
            gray800: nil,
            gray900: nil,
            red700: nil
        )

        let customLogo: TruoraCustomLogo? = customLogoData.map { data in
            TruoraCustomLogo(
                logoData: data.toKotlinByteArray(),
                width: logoWidth.map { KotlinFloat(float: Float($0)) },
                height: logoHeight.map { KotlinFloat(float: Float($0)) }
            )
        }

        return TruoraUIConfig(
            colors: colors,
            logo: customLogo
        )
    }
}
