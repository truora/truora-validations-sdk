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
            // Camera preview - extends to full screen (including safe area)
            CameraViewWrapper(viewModel: viewModel)
                .extendingIntoSafeArea()

            PassiveCaptureOverlayView(
                state: viewModel.state,
                feedback: viewModel.feedback,
                countdown: viewModel.countdown,
                lastFrameData: viewModel.lastFrameData,
                uploadState: viewModel.uploadState,
                detectedFaceBoxes: viewModel.detectedFaceBoxes,
                isActivelyRecording: viewModel.isActivelyRecording
            ) { viewModel.handleEvent(.recordingCompleted) }
                .modifier(AccessibilityIdentifierModifier(identifier: accessibilityIdentifierForState))

            // Help button is hidden while the camera is actively recording video and during
            // upload, to prevent stopping the recording and sending incomplete video to the backend.
            VStack(spacing: 0) {
                Spacer()
                PassiveCaptureBottomBar(
                    showHelpButton: !viewModel.isActivelyRecording && viewModel.uploadState == .none
                ) { viewModel.handleEvent(.helpRequested) }
            }

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

                    ManualRecordButton(
                        isEnabled: !viewModel.isRecordingInProgress && viewModel.uploadState == .none
                    ) { viewModel.handleEvent(.recordVideoRequested) }
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2 + buttonOffset)
                }
            }

            // Help dialog
            if viewModel.showHelpDialog {
                PassiveCaptureTipsDialog(
                    onDismiss: { viewModel.handleEvent(.helpDismissed) },
                    onManualRecording: { viewModel.handleEvent(.manualRecordingRequested) }
                )
            }

            // Settings prompt
            if viewModel.showSettingsPrompt {
                CameraSettingsPromptView(
                    onOpenSettings: { viewModel.handleEvent(.openSettingsRequested) },
                    onDismiss: { viewModel.handleEvent(.settingsPromptDismissed) }
                )
            }

            #if DEBUG
            if let advisor = viewModel.performanceAdvisor {
                PerformanceDebugOverlay(advisor: advisor)
            }
            #endif
        }
        .environmentObject(theme)
        .navigationBarHidden(true)
        .alert(isPresented: $viewModel.showError) {
            Alert(
                title: Text(TruoraLocalization.string(forKey: LocalizationKeys.commonError)),
                message: Text(viewModel.errorMessage ?? ""),
                dismissButton: .default(
                    Text(TruoraLocalization.string(forKey: LocalizationKeys.commonOk))
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
            viewModel.onAppWillResignActive()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
        ) { _ in
            viewModel.onAppDidBecomeActive()
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
