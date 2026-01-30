//
//  FadingEdgeModifier.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 23/01/26.
//

import SwiftUI

struct FadingEdgeModifier: ViewModifier {
    var brush: Gradient
    var height: CGFloat

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: brush,
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: height),
                alignment: .bottom
            )
    }
}

extension View {
    func fadingEdge(brush: Gradient, height: CGFloat = 100) -> some View {
        self.modifier(FadingEdgeModifier(brush: brush, height: height))
    }
}
