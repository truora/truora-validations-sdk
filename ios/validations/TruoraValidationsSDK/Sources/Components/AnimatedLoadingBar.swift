//
//  AnimatedLoadingBar.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 28/01/26.
//

import SwiftUI

/// Animated loading bar with a traveling gradient segment effect.
/// Matches the KMP `AnimatedLoadingBar` implementation.
struct AnimatedLoadingBar: View {
    let backgroundColor: Color
    let progressColor: Color
    let height: CGFloat
    let animationDuration: Double

    @State private var offset: CGFloat = 0

    init(
        backgroundColor: Color = Color.white.opacity(0.2),
        progressColor: Color = .white,
        height: CGFloat = 4,
        animationDuration: Double = 1.2
    ) {
        self.backgroundColor = backgroundColor
        self.progressColor = progressColor
        self.height = height
        self.animationDuration = animationDuration
    }

    var body: some View {
        GeometryReader { geometry in
            let containerWidth = geometry.size.width
            let segmentWidth = containerWidth * 0.3

            ZStack(alignment: .leading) {
                // Background track
                Rectangle()
                    .fill(backgroundColor)

                // Animated gradient segment
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                progressColor.opacity(0),
                                progressColor,
                                progressColor.opacity(0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: segmentWidth)
                    .offset(x: offset)
            }
            .onAppear {
                offset = -segmentWidth
                withAnimation(
                    .linear(duration: animationDuration)
                        .repeatForever(autoreverses: false)
                ) {
                    offset = containerWidth
                }
            }
        }
        .frame(height: height)
        .clipped()
    }
}

// MARK: - Previews

#Preview("Default") {
    VStack(spacing: 20) {
        AnimatedLoadingBar()
            .padding(.horizontal, 20)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(red: 0.03, green: 0.13, blue: 0.33))
}

#Preview("Custom Colors") {
    VStack(spacing: 20) {
        AnimatedLoadingBar(
            backgroundColor: Color.gray.opacity(0.3),
            progressColor: .blue,
            height: 6
        )
        .padding(.horizontal, 20)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.white)
}
