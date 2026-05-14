//
//  PassiveCaptureFeedbackView.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 23/01/26.
//

import SwiftUI

struct PassiveCaptureFeedbackView: View {
    let feedback: FeedbackType

    @EnvironmentObject var theme: TruoraTheme

    var feedbackText: String {
        switch feedback {
        case .none:
            ""
        case .showFace:
            TruoraLocalization.string(forKey: LocalizationKeys.passiveCaptureFeedbackShowFace)
        case .removeGlasses:
            TruoraLocalization.string(forKey: LocalizationKeys.passiveCaptureFeedbackRemoveGlasses)
        case .multiplePeople:
            TruoraLocalization.string(forKey: LocalizationKeys.passiveCaptureFeedbackMultiplePeople)
        case .hiddenFace:
            TruoraLocalization.string(forKey: LocalizationKeys.passiveCaptureFeedbackHiddenFace)
        case .centerFace:
            TruoraLocalization.string(forKey: LocalizationKeys.passiveCaptureFeedbackCenterFace)
        case .lookForward:
            TruoraLocalization.string(forKey: LocalizationKeys.passiveCaptureFeedbackLookForward)
        case .recording:
            TruoraLocalization.string(forKey: LocalizationKeys.passiveCaptureFeedbackRecording)
        }
    }

    /// Accessibility identifier for UI testing
    private var accessibilityIdentifier: String {
        switch feedback {
        case .none: "feedback_none"
        case .showFace: "feedback_show_face"
        case .removeGlasses: "feedback_remove_glasses"
        case .multiplePeople: "feedback_multiple_people"
        case .hiddenFace: "feedback_hidden_face"
        case .centerFace: "feedback_center_face"
        case .lookForward: "feedback_look_forward"
        case .recording: "feedback_recording"
        }
    }

    var body: some View {
        if !feedbackText.isEmpty {
            feedbackContent
        }
    }

    @ViewBuilder
    private var feedbackContent: some View {
        let baseView = Text(feedbackText)
            .font(theme.typography.titleSmall)
            .foregroundColor(theme.colors.tint)
            .tracking(0.25)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(feedback == .recording ? theme.colors.layoutSuccess : theme.colors.layoutWarning)
            .cornerRadius(8)

        if #available(iOS 14.0, *) {
            baseView.accessibilityIdentifier(accessibilityIdentifier)
        } else {
            baseView
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        PassiveCaptureFeedbackView(feedback: .showFace)
        PassiveCaptureFeedbackView(feedback: .recording)
        PassiveCaptureFeedbackView(feedback: .multiplePeople)
        PassiveCaptureFeedbackView(feedback: .lookForward)
    }
    .padding()
    .background(Color.black)
    .environmentObject(TruoraTheme())
}
