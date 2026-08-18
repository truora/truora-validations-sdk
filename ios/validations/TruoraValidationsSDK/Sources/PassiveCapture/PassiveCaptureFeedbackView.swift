//
//  PassiveCaptureFeedbackView.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 23/01/26.
//

import SwiftUI

struct PassiveCaptureFeedbackView: View {
    let feedback: FeedbackType
    /// When true, the pill renders the "Don't move! Recording..." copy with the success color
    /// regardless of `feedback`. The recording text is a UI affordance of the capture overlay,
    /// not a FeedbackType, so it is selected here by an external state signal.
    var isActivelyRecording: Bool = false

    @EnvironmentObject var theme: TruoraTheme

    var feedbackText: String {
        if isActivelyRecording {
            return TruoraLocalization.string(forKey: LocalizationKeys.passiveCaptureFeedbackRecording)
        }
        switch feedback {
        case .none:
            return ""
        case .showFace:
            return TruoraLocalization.string(forKey: LocalizationKeys.passiveCaptureFeedbackShowFace)
        case .removeGlasses:
            return TruoraLocalization.string(forKey: LocalizationKeys.passiveCaptureFeedbackRemoveGlasses)
        case .multiplePeople:
            return TruoraLocalization.string(forKey: LocalizationKeys.passiveCaptureFeedbackMultiplePeople)
        case .hiddenFace:
            return TruoraLocalization.string(forKey: LocalizationKeys.passiveCaptureFeedbackHiddenFace)
        case .centerFace:
            return TruoraLocalization.string(forKey: LocalizationKeys.passiveCaptureFeedbackCenterFace)
        case .lookForward:
            return TruoraLocalization.string(forKey: LocalizationKeys.passiveCaptureFeedbackLookForward)
        case .moveCloser:
            return TruoraLocalization.string(forKey: LocalizationKeys.passiveCaptureFeedbackMoveCloser)
        case .moveBack:
            return TruoraLocalization.string(forKey: LocalizationKeys.passiveCaptureFeedbackMoveBack)
        }
    }

    /// Accessibility identifier for UI testing
    private var accessibilityIdentifier: String {
        if isActivelyRecording {
            return "feedback_recording"
        }
        switch feedback {
        case .none: return "feedback_none"
        case .showFace: return "feedback_show_face"
        case .removeGlasses: return "feedback_remove_glasses"
        case .multiplePeople: return "feedback_multiple_people"
        case .hiddenFace: return "feedback_hidden_face"
        case .centerFace: return "feedback_center_face"
        case .lookForward: return "feedback_look_forward"
        case .moveCloser: return "feedback_move_closer"
        case .moveBack: return "feedback_move_back"
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
            .background(isActivelyRecording ? theme.colors.layoutSuccess : theme.colors.layoutWarning)
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
        PassiveCaptureFeedbackView(feedback: .none, isActivelyRecording: true)
        PassiveCaptureFeedbackView(feedback: .multiplePeople)
        PassiveCaptureFeedbackView(feedback: .lookForward)
    }
    .padding()
    .background(Color.black)
    .environmentObject(TruoraTheme())
}
