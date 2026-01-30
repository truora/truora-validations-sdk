//
//  PassiveCaptureEvent.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 23/01/26.
//

import Foundation

enum PassiveCaptureEvent {
    case countdownStarted
    case countdownFinished
    case recordingStarted
    case recordingCompleted
    case helpDismissed
    case manualRecordingRequested
    case recordVideoRequested
    case helpRequested
    case openSettingsRequested
    case settingsPromptDismissed
    case feedbackChanged(FeedbackType)
}
