//
//  SuccessResultContent.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 23/01/26.
//

import SwiftUI

struct SuccessResultContent: View {
    let date: String
    let maxImageHeight: CGFloat
    @EnvironmentObject var theme: TruoraTheme

    private var validatedImageHeight: CGFloat {
        max(150, min(maxImageHeight, 500))
    }

    var body: some View {
        VStack(spacing: 32) {
            TruoraValidationsSDKAsset.resultSuccess.swiftUIImage
                .resizable()
                .scaledToFit()
                .frame(minHeight: 150, maxHeight: validatedImageHeight)
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 12) {
                Text(TruoraValidationsSDKStrings.successResultTitle)
                    .font(theme.typography.titleLarge)
                    .fontWeight(.bold)
                    .foregroundColor(theme.colors.onSurface)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(TruoraValidationsSDKStrings.successResultDescription(date))
                    .font(theme.typography.bodyLarge)
                    .foregroundColor(theme.colors.onSurface)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Previews

#Preview {
    SuccessResultContent(date: "January 25, 2026", maxImageHeight: 300)
        .padding()
        .environmentObject(TruoraTheme(config: nil))
}
