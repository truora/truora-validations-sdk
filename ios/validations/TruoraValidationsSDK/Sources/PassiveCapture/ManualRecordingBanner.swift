//
//  ManualRecordingBanner.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 26/01/26.
//

import SwiftUI

/// Banner that appears when auto-recording fails.
/// Shows message for 4 seconds then auto-hides with fade animation.
/// Matches KMP `ManualRecordingBanner` design.
struct ManualRecordingBanner: View {
    let displayDurationMillis: TimeInterval
    @State private var showBanner: Bool = true
    @EnvironmentObject var theme: TruoraTheme

    init(displayDurationMillis: TimeInterval = 4.0) {
        self.displayDurationMillis = displayDurationMillis
    }

    var body: some View {
        if showBanner {
            Text(cannotRecordMessage)
                .font(theme.typography.bodyMedium)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(theme.colors.layoutGray900.opacity(0.9))
                )
                .transition(.opacity.animation(.easeInOut(duration: 0.3)))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + displayDurationMillis) {
                        withAnimation {
                            showBanner = false
                        }
                    }
                }
        }
    }

    /// Format the "cannot record" message with the button text.
    private var cannotRecordMessage: String {
        let buttonText = TruoraValidationsSDKStrings.passiveCaptureRecordVideo
        return TruoraValidationsSDKStrings.passiveCaptureCannotRecord(buttonText)
    }
}

// MARK: - Previews

#Preview("Manual Recording Banner") {
    ZStack {
        Color.black
        ManualRecordingBanner()
            .environmentObject(TruoraTheme())
    }
}

#Preview("Banner with Button") {
    ZStack {
        Color.black
        VStack(spacing: 24) {
            ManualRecordingBanner()
            ManualRecordButton {}
        }
        .environmentObject(TruoraTheme())
    }
}
