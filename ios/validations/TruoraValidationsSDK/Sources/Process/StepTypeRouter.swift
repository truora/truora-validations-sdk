//
//  StepTypeRouter.swift
//  TruoraValidationsSDK
//

import Foundation

/// Stable identifier of the SDK screen/fragment that renders a given DI step.
enum ScreenId {
    case authorization
    case documentType
    case documentPhoto
    case faceLiveness
    case invoice
    case unsupported

    /// Stable, cross-platform identifier for telemetry — matches KMP `ScreenId.name`
    /// so the same step yields the same `s_screen` value on both platforms.
    var stableName: String {
        switch self {
        case .authorization: "AUTHORIZATION"
        case .documentType: "DOCUMENT_TYPE"
        case .documentPhoto: "DOCUMENT_PHOTO"
        case .faceLiveness: "FACE_LIVENESS"
        case .invoice: "INVOICE"
        case .unsupported: "UNSUPPORTED"
        }
    }
}

/// Result of routing a DI ``TruoraStep``: which ``ScreenId`` to show plus the step payload.
struct RoutedStep {
    let screen: ScreenId
    let step: TruoraStep
}

/// Maps a DI ``TruoraStepType`` (from the process response) to the SDK ``ScreenId`` that renders
/// it, for the v1 step set.
///
/// Any other step type — including `.unknown` or a type outside the v1 set (non-liveness
/// face, custom question) — maps to `.unsupported` so the caller can drive the graceful
/// UnsupportedFlow path.
struct StepTypeRouter {
    /// Route `step` to the screen that renders it, forwarding the step payload unchanged.
    func route(_ step: TruoraStep) -> RoutedStep {
        RoutedStep(screen: screen(for: step.type), step: step)
    }

    private func screen(for stepType: TruoraStepType) -> ScreenId {
        switch stepType {
        case .enterAuthorization:
            .authorization
        case .enterDocumentType:
            .documentType
        case .takeDocumentPhoto:
            .documentPhoto
        case .recordFacePhotoLiveness, .recordFaceVideoLiveness, .enterFaceVerificationLiveness:
            .faceLiveness
        case .enterInvoiceCountry, .takeInvoicePhoto:
            .invoice
        default:
            .unsupported
        }
    }
}
