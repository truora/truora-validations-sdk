//
//  OvalCutoutView.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 23/01/26.
//

import SwiftUI
import UIKit

/// Visual state of the capture guide oval, mapping to the cross-platform gray / yellow / green
/// progression. The multi-face warning is rendered separately (per-face ovals) and is
/// independent of this state.
enum OvalQualityState {
    /// No stable face detection yet.
    case idle
    /// Face detected, quality gate not yet satisfied.
    case scanning
    /// Quality gate passed; holding for capture.
    case ready
}

struct OvalCutoutView: View {
    let ovalWidth: CGFloat
    let ovalHeight: CGFloat
    var strokeColor: Color?
    var strokeWidth: CGFloat?
    var overlayColor: Color?

    /// Drives the guide oval stroke color (gray / yellow / green). Ignored when `strokeColor`
    /// is explicitly provided, or in multi-face mode where per-face ovals use their own color.
    var qualityState: OvalQualityState = .idle

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
        if let strokeWidth {
            return strokeWidth
        }
        // iPad: 8px, iPhone: 4px, per Figma
        return UIDevice.current.userInterfaceIdiom == .pad ? 8 : 4
    }

    @EnvironmentObject var theme: TruoraTheme

    /// Guide oval stroke color for the current `qualityState`, using the iOS design tokens that
    /// preserve the cross-platform gray (idle) / yellow (scanning) / green (ready) progression.
    private var qualityStateColor: Color {
        switch qualityState {
        case .idle: theme.colors.layoutTint20
        case .scanning: theme.colors.faceOverlayColor
        case .ready: theme.colors.layoutSuccess
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let guideStrokeColor = strokeColor ?? qualityStateColor
            let multiFaceStrokeColor = strokeColor ?? theme.colors.faceOverlayColor
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
                    // Dim the whole feed, then punch a cutout per detected face so the faces
                    // stay bright while their surroundings are dimmed (mirrors the single-face
                    // guide). Per-face yellow rings are stroked on top.
                    actualOverlayColor

                    ForEach(Array(detectedFaceBoxes.enumerated()), id: \.offset) { _, box in
                        detectedFaceCutout(box: box)
                    }

                    ForEach(Array(detectedFaceBoxes.enumerated()), id: \.offset) { index, box in
                        detectedFaceOval(box: box, index: index, strokeColor: multiFaceStrokeColor)
                    }
                }
                .compositingGroup()
                .modifier(MultiFaceOverlayIdentifier())
            }
        }
    }

    /// Forced vertical (taller-than-wide) ellipse size that fully encloses the detected face
    /// box. Vision face boxes are roughly square; rendering them as an Ellipse without
    /// correcting the aspect produces a circle. Shared by the cutout and the stroked ring so
    /// they always align.
    private func perFaceOvalSize(for box: CGRect) -> CGSize {
        let width = max(box.width, box.height / perFaceOvalAspectRatio)
        return CGSize(width: width, height: width * perFaceOvalAspectRatio)
    }

    /// Filled ellipse used with `.blendMode(.destinationOut)` to punch the face out of the
    /// dimming overlay so it stays bright.
    private func detectedFaceCutout(box: CGRect) -> some View {
        let size = perFaceOvalSize(for: box)
        return Ellipse()
            .frame(width: size.width, height: size.height)
            .position(x: box.midX, y: box.midY)
            .blendMode(.destinationOut)
    }

    @ViewBuilder
    private func detectedFaceOval(box: CGRect, index: Int, strokeColor: Color) -> some View {
        let size = perFaceOvalSize(for: box)

        let ellipse = Ellipse()
            .stroke(strokeColor, lineWidth: actualStrokeWidth)
            .frame(width: size.width, height: size.height)
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
