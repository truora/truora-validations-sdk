//
//  PassiveCaptureUploadHeaderView.swift
//  TruoraValidationsSDK
//

import SwiftUI

/// Localized title shown at the top of the capture overlay during upload.
/// Returns nil when no header should be displayed (.none / .navigatedToResult).
func uploadHeaderTitle(for uploadState: UploadState) -> String? {
    switch uploadState {
    case .uploading:
        TruoraLocalization.string(forKey: LocalizationKeys.passiveCaptureUploadingTitle)
    case .success:
        TruoraLocalization.string(forKey: LocalizationKeys.passiveCaptureReadyTitle)
    case .none, .navigatedToResult:
        nil
    }
}

/// Guide-oval stroke color override during upload: white while uploading,
/// theme success green on success. Returns nil for non-upload states so the
/// overlay's normal `ovalQualityState` color is used.
func uploadOvalStrokeColor(for uploadState: UploadState, theme: TruoraTheme) -> Color? {
    switch uploadState {
    case .uploading:
        .white
    case .success:
        theme.colors.layoutSuccess
    case .none, .navigatedToResult:
        nil
    }
}

/// Header text shown during upload ("Cargando…") and on success ("¡Listo!").
/// Styled to match `PassiveCaptureCountdownHeaderView`.
struct PassiveCaptureUploadHeaderView: View {
    let uploadState: UploadState
    @EnvironmentObject var theme: TruoraTheme

    var body: some View {
        if let title = uploadHeaderTitle(for: uploadState) {
            Text(title)
                .font(theme.typography.titleMedium)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
    }
}

// MARK: - Previews

#Preview("Uploading") {
    ZStack {
        Color(red: 0.03, green: 0.13, blue: 0.33)
        PassiveCaptureUploadHeaderView(uploadState: .uploading)
            .environmentObject(TruoraTheme(config: nil))
    }
    .frame(height: 100)
}

#Preview("Ready") {
    ZStack {
        Color(red: 0.03, green: 0.13, blue: 0.33)
        PassiveCaptureUploadHeaderView(uploadState: .success)
            .environmentObject(TruoraTheme(config: nil))
    }
    .frame(height: 100)
}
