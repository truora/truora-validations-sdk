//
//  ManualRecordButton.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 23/01/26.
//

import SwiftUI

/// Pill-shaped manual record button with red recording icon.
/// Matches KMP `ManualRecordButton` / `RecordButton` design.
struct ManualRecordButton: View {
    let action: () -> Void
    @EnvironmentObject var theme: TruoraTheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                RecordIcon()

                Text(TruoraValidationsSDKStrings.passiveCaptureRecordVideo)
                    .font(theme.typography.titleSmall)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.white)
            .foregroundColor(theme.colors.layoutGray900)
            .clipShape(Capsule())
        }
    }
}

/// Recording circle icon with outer border and filled inner circle.
/// Matches KMP `RecordIcon` design.
private struct RecordIcon: View {
    @EnvironmentObject var theme: TruoraTheme

    var body: some View {
        ZStack {
            Circle()
                .stroke(theme.colors.layoutRed700, lineWidth: 1)
                .frame(width: 24, height: 24)

            Circle()
                .fill(theme.colors.layoutRed700)
                .frame(width: 16.73, height: 16.73)
        }
    }
}

// MARK: - Previews

#Preview("Manual Record Button") {
    ZStack {
        Color.black
        ManualRecordButton {}
            .environmentObject(TruoraTheme())
    }
}

#Preview("Record Icon") {
    RecordIcon()
        .environmentObject(TruoraTheme())
        .padding()
        .background(Color.white)
}
