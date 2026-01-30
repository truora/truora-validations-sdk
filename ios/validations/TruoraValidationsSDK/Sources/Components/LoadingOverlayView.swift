//
//  LoadingOverlayView.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 23/01/26.
//

import SwiftUI

struct LoadingOverlayView: View {
    let message: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)

            VStack(spacing: 20) {
                ActivityIndicator(
                    isAnimating: .constant(true),
                    style: .large,
                    color: .white
                )

                Text(message)
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .medium))
            }
        }
    }
}

// MARK: - Previews

#Preview {
    LoadingOverlayView(message: "Loading...")
}
