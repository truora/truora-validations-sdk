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

    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width

            // Calculate responsive oval dimensions
            let proportionalWidth = screenWidth * ovalWidthRatio
            let ovalWidth = min(max(proportionalWidth, minOvalWidth), maxOvalWidth)
            let ovalHeight = ovalWidth * ovalAspectRatio

            // Calculate responsive thumbnail size (48px iPhone, max 90px iPad)
            let thumbnailSize = min(max(screenWidth * thumbnailWidthRatio, minThumbnailSize), maxThumbnailSize)

            ZStack {
                // Semi-transparent mask with oval cutout OR progress indicator
                if state == .recording, feedback == .recording {
                    AnimatedOvalProgressView(
                        ovalWidth: ovalWidth,
                        ovalHeight: ovalHeight,
                        onFinished: onAnimationFinished
                    )
                } else {
                    OvalCutoutView(
                        ovalWidth: ovalWidth,
                        ovalHeight: ovalHeight
                    )
                }

                // Countdown header at top of screen
                if state == .countdown {
                    VStack {
                        PassiveCaptureCountdownHeaderView()
                            .padding(.top, 16)
                        Spacer()
                    }
                }

                // Countdown number centered in oval
                if state == .countdown {
                    PassiveCaptureCountdownNumberView(countdown: countdown)
                }

                // Feedback display - positioned relative to oval bottom
                if state == .recording {
                    PassiveCaptureFeedbackView(feedback: feedback)
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
    }
}

#Preview("Feedback") {
    PassiveCaptureOverlayView(
        state: .recording,
        feedback: .showFace,
        countdown: 0,
        lastFrameData: nil,
        uploadState: .none
    ) {}
        .environmentObject(TruoraTheme())
}

#Preview("Recording") {
    PassiveCaptureOverlayView(
        state: .recording,
        feedback: .recording,
        countdown: 0,
        lastFrameData: nil,
        uploadState: .none
    ) {}
        .environmentObject(TruoraTheme())
}

#Preview("Uploading") {
    PassiveCaptureOverlayView(
        state: .recording,
        feedback: .none,
        countdown: 0,
        lastFrameData: UIImage(systemName: "person.fill")?.jpegData(compressionQuality: 0.8),
        uploadState: .uploading
    ) {}
        .environmentObject(TruoraTheme())
}

#Preview("Manual State") {
    PassiveCaptureOverlayView(
        state: .manual,
        feedback: .showFace,
        countdown: 0,
        lastFrameData: nil,
        uploadState: .none
    ) {}
        .environmentObject(TruoraTheme())
}

#Preview("Manual State - No Banner") {
    PassiveCaptureOverlayView(
        state: .manual,
        feedback: .none,
        countdown: 0,
        lastFrameData: nil,
        uploadState: .none
    ) {}
        .environmentObject(TruoraTheme())
}
