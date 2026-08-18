//
//  CircularSpinnerView.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 09/06/26.
//

import SwiftUI

/// A lightweight indeterminate spinner: a 270° arc that rotates continuously.
/// Matches the design-system "Spinner Interactive" used on the loading states,
/// instead of the platform `UIActivityIndicatorView` spokes.
struct CircularSpinnerView: View {
    var size: CGFloat = 24
    var lineWidth: CGFloat = 2.5
    var color: Color = .white

    @State private var isSpinning = false

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.75)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .frame(width: size, height: size)
            .rotationEffect(.degrees(isSpinning ? 360 : 0))
            .animation(.linear(duration: 0.9).repeatForever(autoreverses: false), value: isSpinning)
            .onAppear { isSpinning = true }
    }
}

#Preview {
    ZStack {
        Color(red: 0.03, green: 0.13, blue: 0.33)
        CircularSpinnerView()
    }
    .frame(width: 100, height: 100)
}
