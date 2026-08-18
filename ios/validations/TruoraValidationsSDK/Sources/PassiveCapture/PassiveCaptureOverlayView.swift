//
//  PassiveCaptureOverlayView.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 23/01/26.
//

import SwiftUI
import UIKit

struct PassiveCaptureOverlayView: View {
    let state: PassiveCaptureState
    let feedback: FeedbackType
    let countdown: Int
    let lastFrameData: Data?
    let uploadState: UploadState
    let detectedFaceBoxes: [CGRect]
    var isActivelyRecording: Bool = false
    let onAnimationFinished: () -> Void

    @EnvironmentObject var theme: TruoraTheme

    // Constants for responsive sizing
    private let ovalWidthRatio: CGFloat = 0.8056 // 290/360 from Figma
    private let ovalAspectRatio: CGFloat = 1.238 // 359/290 from Figma (867/700 for iPad)
    private let minOvalWidth: CGFloat = 200 // ML Kit minimum
    private let maxOvalWidth: CGFloat = 700 // iPad maximum per Figma (700x867)
    private let thumbnailWidthRatio: CGFloat = 0.1333 // 48/360 from Figma
    private let minThumbnailSize: CGFloat = 44 // WCAG accessibility minimum
    private let maxThumbnailSize: CGFloat = 90 // iPad maximum per Figma
    private let feedbackOffsetFromOvalBottom: CGFloat = -40 // Overlap into oval bottom

    // Countdown header top padding: keep text below Dynamic Island, more room on small phones
    private let countdownHeaderBaseTopPadding: CGFloat = 16
    private let countdownHeaderMinTopPaddingSmallPhone: CGFloat = 58
    private let countdownHeaderMinTopPaddingRegular: CGFloat = 70
    private let countdownSmallPhoneHeightThreshold: CGFloat = 700

    /// Maps the current state + feedback to the guide oval's gray/yellow/green state.
    /// Multi-face is rendered as per-face ovals, so it does not affect the guide here.
    private var ovalQualityState: OvalQualityState {
        if isActivelyRecording {
            return .ready
        }
        switch feedback {
        case .none:
            // No hint: green only while actively holding for capture (recording state),
            // gray otherwise (countdown / manual idle).
            return state == .recording ? .ready : .idle
        case .showFace:
            return .idle
        case .centerFace, .moveCloser, .moveBack, .lookForward,
             .hiddenFace, .removeGlasses, .multiplePeople:
            return .scanning
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width

            // Calculate responsive oval dimensions
            let proportionalWidth = screenWidth * ovalWidthRatio
            let ovalWidth = min(max(proportionalWidth, minOvalWidth), maxOvalWidth)
            let ovalHeight = ovalWidth * ovalAspectRatio

            // Calculate responsive thumbnail size (48px iPhone, max 90px iPad)
            let thumbnailSize = min(max(screenWidth * thumbnailWidthRatio, minThumbnailSize), maxThumbnailSize)

            // Shared top padding for the countdown and upload headers - keeps text
            // below the Dynamic Island. max() because safeAreaInsets.top can be 0
            // when the overlay ignores the safe area.
            let screenHeight = geometry.size.height
            let minHeaderTopPadding: CGFloat = screenHeight < countdownSmallPhoneHeightThreshold
                ? countdownHeaderMinTopPaddingSmallPhone
                : countdownHeaderMinTopPaddingRegular
            let headerTopPadding = max(countdownHeaderBaseTopPadding + geometry.safeAreaInsets.top, minHeaderTopPadding)

            ZStack {
                // Semi-transparent mask with oval cutout OR progress indicator
                if state == .recording, isActivelyRecording {
                    AnimatedOvalProgressView(
                        ovalWidth: ovalWidth,
                        ovalHeight: ovalHeight,
                        onFinished: onAnimationFinished
                    )
                } else {
                    OvalCutoutView(
                        ovalWidth: ovalWidth,
                        ovalHeight: ovalHeight,
                        strokeColor: uploadOvalStrokeColor(for: uploadState, theme: theme),
                        qualityState: ovalQualityState,
                        detectedFaceBoxes: detectedFaceBoxes
                    )
                }

                // Countdown header at top
                if state == .countdown {
                    VStack {
                        PassiveCaptureCountdownHeaderView()
                            .padding(.top, headerTopPadding)
                        Spacer()
                    }
                }

                // Upload status header ("Cargando…" / "¡Listo!")
                if uploadState == .uploading || uploadState == .success {
                    VStack {
                        PassiveCaptureUploadHeaderView(uploadState: uploadState)
                            .padding(.top, headerTopPadding)
                        Spacer()
                    }
                }

                // Countdown number centered in oval
                if state == .countdown {
                    PassiveCaptureCountdownNumberView(countdown: countdown)
                }

                // Feedback display - positioned relative to oval bottom
                if state == .recording {
                    PassiveCaptureFeedbackView(feedback: feedback, isActivelyRecording: isActivelyRecording)
                        .offset(y: (ovalHeight / 2) + feedbackOffsetFromOvalBottom)
                }

                // Manual recording banner - shown briefly when entering manual state
                if state == .manual, feedback != .none {
                    ManualRecordingBanner()
                        .offset(y: (ovalHeight / 2) + feedbackOffsetFromOvalBottom)
                }

                // Frame thumbnail for captured data or upload states
                if let frameData = lastFrameData,
                   let image = UIImage(data: frameData) {
                    VStack {
                        Spacer()
                        HStack {
                            PhotoThumbnailView(
                                image: image,
                                uploadState: uploadState,
                                size: thumbnailSize
                            )
                            .padding(.leading, max(16, screenWidth * 0.0444)) // 16/360
                            .padding(.bottom, 16)
                            Spacer()
                        }
                    }
                }
            }
        }
        .extendingIntoSafeArea()
    }
}

#Preview("Feedback") {
    PassiveCaptureOverlayView(
        state: .recording,
        feedback: .showFace,
        countdown: 0,
        lastFrameData: nil,
        uploadState: .none,
        detectedFaceBoxes: []
    ) {}
        .environmentObject(TruoraTheme())
}

#Preview("Recording") {
    PassiveCaptureOverlayView(
        state: .recording,
        feedback: .none,
        countdown: 0,
        lastFrameData: nil,
        uploadState: .none,
        detectedFaceBoxes: [],
        isActivelyRecording: true
    ) {}
        .environmentObject(TruoraTheme())
}

#Preview("Uploading") {
    PassiveCaptureOverlayView(
        state: .recording,
        feedback: .none,
        countdown: 0,
        lastFrameData: UIImage(systemName: "person.fill")?.jpegData(compressionQuality: 0.8),
        uploadState: .uploading,
        detectedFaceBoxes: []
    ) {}
        .environmentObject(TruoraTheme())
}

#Preview("Ready") {
    PassiveCaptureOverlayView(
        state: .recording,
        feedback: .none,
        countdown: 0,
        lastFrameData: UIImage(systemName: "person.fill")?.jpegData(compressionQuality: 0.8),
        uploadState: .success,
        detectedFaceBoxes: []
    ) {}
        .environmentObject(TruoraTheme())
}

#Preview("Manual State") {
    PassiveCaptureOverlayView(
        state: .manual,
        feedback: .showFace,
        countdown: 0,
        lastFrameData: nil,
        uploadState: .none,
        detectedFaceBoxes: []
    ) {}
        .environmentObject(TruoraTheme())
}

#Preview("Manual State - No Banner") {
    PassiveCaptureOverlayView(
        state: .manual,
        feedback: .none,
        countdown: 0,
        lastFrameData: nil,
        uploadState: .none,
        detectedFaceBoxes: []
    ) {}
        .environmentObject(TruoraTheme())
}
