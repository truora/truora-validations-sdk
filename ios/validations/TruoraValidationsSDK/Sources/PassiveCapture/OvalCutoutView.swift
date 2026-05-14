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

    /// Per-face bounding boxes in view-space points. When non-empty the central
    /// guide oval and dimming overlay are hidden, and one stroked ellipse is drawn
    /// per box (PROC-6872 multi-face feedback).
    var detectedFaceBoxes: [CGRect] = []

    /// Vertical aspect ratio for per-face ovals — derived from the central
    /// guide oval's dimensions so per-face rings keep the same shape even when
    /// the view is sized for non-default oval proportions.
    private var perFaceOvalAspectRatio: CGFloat {
        ovalWidth > 0 ? ovalHeight / ovalWidth : 1
    }

    private var actualStrokeWidth: CGFloat {
        if let strokeWidth { return strokeWidth }
        // iPad: 12px, iPhone: 6px per Figma
        return UIDevice.current.userInterfaceIdiom == .pad ? 12 : 6
    }

    @EnvironmentObject var theme: TruoraTheme

    var body: some View {
        GeometryReader { geometry in
            let guideStrokeColor = strokeColor ?? theme.colors.layoutTint20
            let multiFaceStrokeColor = strokeColor ?? theme.colors.layoutWarning
            let actualOverlayColor = overlayColor ?? theme.colors.layoutOverlay

            if detectedFaceBoxes.isEmpty {
                let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                ZStack {
                    actualOverlayColor

                    Ellipse()
                        .frame(width: ovalWidth, height: ovalHeight)
                        .position(center)
                        .blendMode(.destinationOut)

                    Ellipse()
                        .stroke(guideStrokeColor, lineWidth: actualStrokeWidth)
                        .frame(width: ovalWidth, height: ovalHeight)
                        .position(center)
                }
                .compositingGroup()
            } else {
                ZStack {
                    ForEach(Array(detectedFaceBoxes.enumerated()), id: \.offset) { index, box in
                        detectedFaceOval(box: box, index: index, strokeColor: multiFaceStrokeColor)
                    }
                }
                .modifier(MultiFaceOverlayIdentifier())
            }
        }
    }

    @ViewBuilder
    private func detectedFaceOval(box: CGRect, index: Int, strokeColor: Color) -> some View {
        // Force a vertical (taller-than-wide) ellipse that fully encloses the
        // detected face box. Vision face boxes are roughly square; rendering
        // them as Ellipse without correcting aspect produces a circle.
        let width = max(box.width, box.height / perFaceOvalAspectRatio)
        let height = width * perFaceOvalAspectRatio

        let ellipse = Ellipse()
            .stroke(strokeColor, lineWidth: actualStrokeWidth)
            .frame(width: width, height: height)
            .position(x: box.midX, y: box.midY)

        if #available(iOS 14.0, *) {
            ellipse
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier("detected_face_oval_\(index)")
        } else {
            ellipse
        }
    }
}

private struct MultiFaceOverlayIdentifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 14.0, *) {
            content.accessibilityIdentifier("multi_face_overlay")
        } else {
            content
        }
    }
}

#Preview("Single face guide") {
    OvalCutoutView(ovalWidth: 290, ovalHeight: 359)
        .environmentObject(TruoraTheme())
}

#Preview("Multiple faces") {
    OvalCutoutView(
        ovalWidth: 290,
        ovalHeight: 359,
        detectedFaceBoxes: [
            CGRect(x: 146, y: 129, width: 212, height: 262),
            CGRect(x: 6, y: 224, width: 92, height: 114)
        ]
    )
    .environmentObject(TruoraTheme())
}
