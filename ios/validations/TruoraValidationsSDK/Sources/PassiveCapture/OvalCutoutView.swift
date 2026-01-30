//
//  OvalCutoutView.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 23/01/26.
//

import SwiftUI
import UIKit

struct OvalCutoutView: View {
    let ovalWidth: CGFloat
    let ovalHeight: CGFloat
    var strokeColor: Color?
    var strokeWidth: CGFloat?
    var overlayColor: Color?

    private var actualStrokeWidth: CGFloat {
        if let strokeWidth { return strokeWidth }
        // iPad: 12px, iPhone: 6px per Figma
        return UIDevice.current.userInterfaceIdiom == .pad ? 12 : 6
    }

    @EnvironmentObject var theme: TruoraTheme

    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let actualStrokeColor = strokeColor ?? theme.colors.layoutTint20
            let actualOverlayColor = overlayColor ?? theme.colors.layoutOverlay

            ZStack {
                // Semi-transparent background
                actualOverlayColor

                // Oval cutout (clear)
                Ellipse()
                    .frame(width: ovalWidth, height: ovalHeight)
                    .position(center)
                    .blendMode(.destinationOut)

                // Oval border
                Ellipse()
                    .stroke(actualStrokeColor, lineWidth: actualStrokeWidth)
                    .frame(width: ovalWidth, height: ovalHeight)
                    .position(center)
            }
            .compositingGroup()
        }
    }
}

#Preview {
    OvalCutoutView(ovalWidth: 290, ovalHeight: 359)
        .environmentObject(TruoraTheme())
}
