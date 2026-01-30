//
//  PassiveCaptureView.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 30/10/25.
//

import SwiftUI
import TruoraCamera
import UIKit

struct PassiveCaptureView: View {
    @ObservedObject var viewModel: PassiveCaptureViewModel
    @ObservedObject private var theme: TruoraTheme

    init(viewModel: PassiveCaptureViewModel, config: UIConfig?) {
        self.viewModel = viewModel
        self.theme = TruoraTheme(config: config)
    }

    var body: some View {
        ZStack {
            // Camera preview
            CameraViewWrapper(viewModel: viewModel)

            // Capture overlay (native) - matches KMP layout structure
            VStack(spacing: 0) {
                // Overlay with status bar padding
                PassiveCaptureOverlayView(
                    state: viewModel.state,
                    feedback: viewModel.feedback,
                    countdown: viewModel.countdown,
                    lastFrameData: viewModel.lastFrameData,
                    uploadState: viewModel.uploadState
                ) { viewModel.handleEvent(.recordingCompleted) }
                    .modifier(AccessibilityIdentifierModifier(identifier: accessibilityIdentifierForState))

                // Bottom bar - always present, help button hidden only during upload
                PassiveCaptureBottomBar(
                    showHelpButton: viewModel.uploadState == .none
                ) { viewModel.handleEvent(.helpRequested) }
            }
            .environmentObject(theme)

            // Manual recording button - positioned below oval center
            // Matches KMP offset: (PASSIVE_CAPTURE_OVAL_HEIGHT / 2) + height offset based on screen size
            // Using approximate values based on iOS oval sizing
            if viewModel.state == .manual {
                GeometryReader { geometry in
                    let ovalWidthRatio: CGFloat = 0.8056
                    let ovalAspectRatio: CGFloat = 1.238
                    let isSmallScreen = geometry.size.height < 700
                    let proportionalWidth = geometry.size.width * ovalWidthRatio
                    let ovalWidth = min(max(proportionalWidth, 200), 700)
                    let ovalHeight = ovalWidth * ovalAspectRatio

                    let buttonHeightOffset = isSmallScreen ? 24.0 : 48.0
                    let buttonOffset = (ovalHeight / 2) + buttonHeightOffset

                    ManualRecordButton { viewModel.handleEvent(.recordVideoRequested) }
                        .environmentObject(theme)
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2 + buttonOffset)
                }
            }

            // Help dialog
            if viewModel.showHelpDialog {
                PassiveCaptureTipsDialog(
                    onDismiss: { viewModel.handleEvent(.helpDismissed) },
                    onManualRecording: { viewModel.handleEvent(.manualRecordingRequested) }
                )
                .environmentObject(theme)
            }

            // Settings prompt
            if viewModel.showSettingsPrompt {
                CameraSettingsPromptView(
                    onOpenSettings: { viewModel.handleEvent(.openSettingsRequested) },
                    onDismiss: { viewModel.handleEvent(.settingsPromptDismissed) }
                )
                .environmentObject(theme)
            }
        }
        .environmentObject(theme)
        .navigationBarHidden(true)
        .alert(isPresented: $viewModel.showError) {
            Alert(
                title: Text(NSLocalizedString("common_error", bundle: .module, comment: "")),
                message: Text(viewModel.errorMessage ?? ""),
                dismissButton: .default(
                    Text(NSLocalizedString("common_ok", bundle: .module, comment: ""))
                )
            )
        }
        .onAppear {
            viewModel.onAppear()
            viewModel.onWillAppear()
        }
        .onDisappear {
            viewModel.onWillDisappear()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
        ) { _ in
            viewModel.onWillDisappear()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
        ) { _ in
            viewModel.onWillAppear()
        }
    }

    /// Provides accessibility identifier based on current capture state for UI testing
    private var accessibilityIdentifierForState: String {
        switch viewModel.state {
        case .countdown:
            "face_countdown_overlay"
        case .recording:
            "face_recording_overlay"
        case .manual:
            "face_manual_overlay"
        }
    }
}

// MARK: - Accessibility Identifier Modifier

/// A view modifier that applies an accessibility identifier if provided
private struct AccessibilityIdentifierModifier: ViewModifier {
    let identifier: String?

    func body(content: Content) -> some View {
        if #available(iOS 14.0, *), let identifier {
            content.accessibilityIdentifier(identifier)
        } else {
            content
        }
    }
}

#Preview {
    PassiveCaptureView(
        viewModel: PassiveCaptureViewModel(),
        config: nil
    )
}
