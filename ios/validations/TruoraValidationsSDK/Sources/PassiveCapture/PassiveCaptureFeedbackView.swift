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
            TruoraValidationsSDKStrings.passiveCaptureFeedbackShowFace
        case .removeGlasses:
            TruoraValidationsSDKStrings.passiveCaptureFeedbackRemoveGlasses
        case .multiplePeople:
            TruoraValidationsSDKStrings.passiveCaptureFeedbackMultiplePeople
        case .hiddenFace:
            TruoraValidationsSDKStrings.passiveCaptureFeedbackHiddenFace
        case .recording:
            TruoraValidationsSDKStrings.passiveCaptureFeedbackRecording
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
            .font(.system(size: 16, weight: .semibold))
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
    }
    .padding()
    .background(Color.black)
    .environmentObject(TruoraTheme())
}
