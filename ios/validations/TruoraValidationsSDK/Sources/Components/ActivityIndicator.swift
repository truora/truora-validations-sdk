//
//  ActivityIndicator.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 23/01/26.
//

import SwiftUI
import UIKit

struct ActivityIndicator: UIViewRepresentable {
    @Binding var isAnimating: Bool
    let style: UIActivityIndicatorView.Style
    let color: UIColor?

    init(isAnimating: Binding<Bool>, style: UIActivityIndicatorView.Style, color: UIColor? = nil) {
        self._isAnimating = isAnimating
        self.style = style
        self.color = color
    }

    func makeUIView(context: Context) -> UIActivityIndicatorView {
        let indicator = UIActivityIndicatorView(style: style)
        if let color {
            indicator.color = color
        }
        return indicator
    }

    func updateUIView(_ uiView: UIActivityIndicatorView, context: Context) {
        if isAnimating {
            uiView.startAnimating()
        } else {
            uiView.stopAnimating()
        }

        if let color {
            uiView.color = color
        }
    }
}
