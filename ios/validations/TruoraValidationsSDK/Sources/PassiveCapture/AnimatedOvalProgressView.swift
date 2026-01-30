//
//  AnimatedOvalProgressView.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 25/01/26.
//

import SwiftUI
import UIKit

struct AnimatedOvalProgressView: View {
    let ovalWidth: CGFloat
    let ovalHeight: CGFloat
    let duration: TimeInterval = 4.0
    let onFinished: () -> Void

    // iPad: 12px, iPhone: 6px per Figma
    private var strokeWidth: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 12 : 6
    }

    @State private var progress: CGFloat = 0
    @EnvironmentObject var theme: TruoraTheme

    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)

            ZStack {
                // Background overlay with cutout
                OvalCutoutView(
                    ovalWidth: ovalWidth,
                    ovalHeight: ovalHeight,
                    strokeColor: theme.colors.layoutTint20,
                    strokeWidth: strokeWidth
                )

                // Progress Arc
                OvalProgressShape(progress: progress)
                    .stroke(
                        theme.colors.layoutSuccess,
                        style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                    )
                    .frame(width: ovalWidth, height: ovalHeight)
                    .position(center)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: duration)) {
                progress = 1.0
            }
            // Trigger callback after animation finishes
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                onFinished()
            }
        }
    }
}

/// A shape that draws an oval arc based on progress
struct OvalProgressShape: Shape {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Start from top (-90 degrees)
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY),
            radius: rect.width / 2, // This is for circles, but we need oval
            startAngle: .degrees(-90),
            endAngle: .degrees(-90 + Double(360 * progress)),
            clockwise: false
        )

        // To draw an oval arc, we apply a scale transform to the circular arc
        let scaleY = rect.height / rect.width
        let transform = CGAffineTransform(translationX: rect.midX, y: rect.midY)
            .scaledBy(x: 1.0, y: scaleY)
            .translatedBy(x: -rect.midX, y: -rect.midY)

        return path.applying(transform)
    }
}

#Preview {
    AnimatedOvalProgressView(
        ovalWidth: 290,
        ovalHeight: 359
    ) {}
        .environmentObject(TruoraTheme())
        .background(Color.black)
}
