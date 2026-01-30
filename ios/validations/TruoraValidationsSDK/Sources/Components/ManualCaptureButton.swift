//
//  ManualCaptureButton.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 27/01/26.
//

import SwiftUI

/// The capture mode determines the icon color
enum CaptureMode {
    /// Black icon - for document/photo capture
    case picture
    /// Red icon - for face/video recording
    case recording
}

/// A reusable manual capture button matching the KMP GenericManualCaptureButton.
/// Features a white pill-shaped background with a custom concentric circles icon.
///
/// Usage:
/// ```swift
/// ManualCaptureButton(
///     title: "Take photo",
///     mode: .picture,
///     action: { /* capture action */ }
/// )
/// ```
struct ManualCaptureButton: View {
    let title: String
    let mode: CaptureMode
    let action: () -> Void

    @EnvironmentObject var theme: TruoraTheme

    /// Icon color based on capture mode
    private var iconColor: Color {
        switch mode {
        case .picture:
            .black
        case .recording:
            theme.colors.layoutRed700
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                // Custom icon: two concentric circles (camera shutter style)
                CaptureIcon(color: iconColor)
                    .frame(width: 24, height: 24)

                // Button text
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(theme.colors.layoutGray900)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white)
            .clipShape(Capsule())
        }
    }
}

// MARK: - Capture Icon

/// Custom icon with two concentric circles (camera shutter style)
/// Compatible with iOS 13+
private struct CaptureIcon: View {
    let color: Color

    var body: some View {
        ZStack {
            // Outer circle (stroke only) - 90% of container (45% radius = 90% diameter)
            Circle()
                .stroke(color, lineWidth: 2)

            // Inner circle (filled) - 50% of container (25% radius = 50% diameter)
            Circle()
                .fill(color)
                .scaleEffect(0.55) // 50% / 90% ≈ 0.55 relative to outer
        }
    }
}

// MARK: - Previews

#Preview("Picture Mode") {
    ZStack {
        Color(red: 0.03, green: 0.13, blue: 0.33) // primary900
        ManualCaptureButton(
            title: "Take photo",
            mode: CaptureMode.picture
        ) {}
    }
    .environmentObject(TruoraTheme(config: nil))
}

#Preview("Recording Mode") {
    ZStack {
        Color(red: 0.03, green: 0.13, blue: 0.33) // primary900
        ManualCaptureButton(
            title: "Record video",
            mode: CaptureMode.recording
        ) {}
    }
    .environmentObject(TruoraTheme(config: nil))
}
