//
//  TruoraHeaderView.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 23/01/26.
//

import SwiftUI
import UIKit

struct TruoraHeaderView: View {
    let onCancel: (() -> Void)?
    @EnvironmentObject var theme: TruoraTheme

    var body: some View {
        HStack {
            // Custom logo or default Truora logo
            if let logoConfig = theme.logo,
               let logoData = logoConfig.logoData,
               let uiImage = UIImage(data: logoData) {
                SwiftUI.Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width: logoConfig.width ?? 103,
                        height: logoConfig.height ?? 28
                    )
            } else {
                TruoraValidationsSDKAsset.logoTruora.swiftUIImage
                    .resizable()
                    .scaledToFit()
                    .frame(width: 103, height: 28)
            }

            Spacer()

            if let onCancel {
                Button(action: onCancel) {
                    SwiftUI.Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(theme.colors.layoutGray900)
                }
                .frame(width: 48, height: 48)
            }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Previews

#Preview("With Cancel Button") {
    TruoraHeaderView {}
        .environmentObject(TruoraTheme(config: nil))
}

#Preview("Without Cancel Button") {
    TruoraHeaderView(onCancel: nil)
        .environmentObject(TruoraTheme(config: nil))
}
