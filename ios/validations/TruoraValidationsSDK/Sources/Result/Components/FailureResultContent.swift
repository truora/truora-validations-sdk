//
//  FailureResultContent.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 23/01/26.
//

import SwiftUI

struct FailureResultContent: View {
    let maxImageHeight: CGFloat
    @EnvironmentObject var theme: TruoraTheme

    private var validatedImageHeight: CGFloat {
        max(150, min(maxImageHeight, 500))
    }

    var body: some View {
        VStack(spacing: 32) {
            TruoraValidationsSDKAsset.resultFailure.swiftUIImage
                .resizable()
                .scaledToFit()
                .frame(minHeight: 150, maxHeight: validatedImageHeight)
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 12) {
                Text(TruoraValidationsSDKStrings.failureResultTitle)
                    .font(theme.typography.titleLarge)
                    .fontWeight(.bold)
                    .foregroundColor(theme.colors.onSurface)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(TruoraValidationsSDKStrings.failureResultDescription)
                    .font(theme.typography.bodyLarge)
                    .foregroundColor(theme.colors.onSurface.opacity(0.8))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Previews

#Preview {
    FailureResultContent(maxImageHeight: 300)
        .padding()
        .environmentObject(TruoraTheme(config: nil))
}
