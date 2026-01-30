//
//  PassiveCaptureTipsDialog.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 23/01/26.
//

import SwiftUI

struct PassiveCaptureTipsDialog: View {
    let onDismiss: () -> Void
    let onManualRecording: () -> Void

    @EnvironmentObject var theme: TruoraTheme

    private var tips: [String] {
        [
            TruoraValidationsSDKStrings.passiveCaptureTip1,
            TruoraValidationsSDKStrings.passiveCaptureTip2,
            TruoraValidationsSDKStrings.passiveCaptureTip3,
            TruoraValidationsSDKStrings.passiveCaptureTip4
        ]
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .onTapGesture { onDismiss() }

            VStack(spacing: 0) {
                // Header with title and close button
                HStack {
                    Text(TruoraValidationsSDKStrings.passiveCaptureTipsTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(theme.colors.layoutGray900)

                    Spacer()

                    Button(action: onDismiss) {
                        SwiftUI.Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(theme.colors.layoutGray900)
                    }
                    .frame(width: 24, height: 24)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)

                // Divider
                Divider()
                    .background(theme.colors.layoutGray200)

                // Tips list with bullet points
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(tips, id: \.self) { tip in
                        TipBulletRow(text: tip, color: theme.colors.onSurface)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)

                // Divider
                Divider()
                    .background(theme.colors.layoutGray200)

                // Manual recording button
                TruoraPrimaryButton(
                    title: TruoraValidationsSDKStrings.passiveCaptureManualRecording,
                    isLoading: false,
                    action: onManualRecording
                )
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            .frame(width: 320)
            .background(theme.colors.surface)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(theme.colors.layoutGray200, lineWidth: 1)
            )
        }
    }
}

// MARK: - Tip Bullet Row

private struct TipBulletRow: View {
    let text: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.black)

            Text(text)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.black)
                .lineSpacing(7) // 150% line height = 21px, 14px font = 7px extra
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Previews

#Preview {
    PassiveCaptureTipsDialog(
        onDismiss: {},
        onManualRecording: {}
    )
    .environmentObject(TruoraTheme(config: nil))
}
