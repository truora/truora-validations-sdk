//
//  PassiveIntroContentView.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 23/01/26.
//

import SwiftUI

struct PassiveIntroContentView: View {
    @EnvironmentObject var theme: TruoraTheme

    var body: some View {
        GeometryReader { geometry in
            let isPhone = geometry.size.width < 600
            // iPad: max 850px per Figma spec, iPhone: 50% of available height
            let maxImageHeight: CGFloat = isPhone
                ? geometry.size.height * 0.5
                : min(850, geometry.size.height * 0.65)

            VStack(spacing: 0) {
                // Illustration with bottom fade
                TruoraValidationsSDKAsset.passiveIntro.swiftUIImage
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxHeight: maxImageHeight, alignment: .top)
                    .frame(maxWidth: isPhone ? .infinity : 1024)
                    .clipped()
                    .fadingEdge(
                        brush: Gradient(colors: [.clear, theme.colors.surface]),
                        height: 100
                    )

                // Title & Subtitle
                VStack(alignment: .leading, spacing: 12) {
                    Text(TruoraValidationsSDKStrings.passiveInstructionsTitle)
                        .font(theme.typography.titleLarge)
                        .foregroundColor(theme.colors.onSurface)
                        .multilineTextAlignment(.leading)

                    Text(TruoraValidationsSDKStrings.passiveInstructionsText)
                        .font(theme.typography.bodyLarge)
                        .foregroundColor(theme.colors.onSurface)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
            }
        }
    }
}

// MARK: - Previews

#Preview {
    PassiveIntroContentView()
        .environmentObject(TruoraTheme(config: nil))
}
