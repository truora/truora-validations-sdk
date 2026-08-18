//
//  FeedbackType.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 23/01/26.
//

import Foundation

enum FeedbackType: Hashable {
    case none
    case showFace
    case removeGlasses
    case multiplePeople
    case hiddenFace
    case centerFace
    case lookForward
    case moveCloser
    case moveBack

    /// Telemetry key for this hint. `none` maps to "SHOW_FACE" since it carries no guidance.
    var telemetryKey: String {
        switch self {
        case .none: "SHOW_FACE"
        case .showFace: "SHOW_FACE"
        case .centerFace: "CENTER_FACE"
        case .moveCloser: "MOVE_CLOSER"
        case .moveBack: "MOVE_BACK"
        case .lookForward: "LOOK_FORWARD"
        case .multiplePeople: "MULTIPLE_PEOPLE"
        case .hiddenFace: "HIDDEN_FACE"
        case .removeGlasses: "REMOVE_GLASSES"
        }
    }
}
