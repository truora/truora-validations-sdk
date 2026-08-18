//
//  ProcessEvent.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 07/07/26.
//

import Foundation

// MARK: - Process Event

/// An observable event emitted by ``TruoraProcessManager`` over its
/// ``TruoraProcessManager/events`` stream.
///
/// The runner owns the process lifecycle and communicates *exclusively* through
/// this stream. Each case's shape mirrors a KMP process runner event leaf
/// (PROC-6965) 1:1 so the two implementations stay in lockstep.
enum ProcessEvent {
    /// A single block reached a terminal state.
    case blockCompleted(TruoraBlock)

    /// The step just submitted failed, but the user may try again. The screen
    /// re-renders the same step with ``StepRetry/declinedReason``.
    case stepRetry(StepRetry)

    /// The whole process finished; carries the aggregated ``ProcessResult``.
    case processCompleted(ProcessResult)

    /// The process was canceled by the caller.
    case processCanceled

    /// The process failed with a classified ``ProcessError``.
    case processError(ProcessError)
}

// MARK: - Step Retry

/// A recoverable step failure: the backend declined the submission but left the
/// user attempts to spend.
struct StepRetry: Equatable {
    let stepType: TruoraStepType
    /// Why the backend declined the submission, when it said.
    let declinedReason: String?
    /// Attempts the user has left on this step, always `> 0`.
    let remainingRetries: Int
}

// MARK: - Process Error

/// Errors surfaced by ``TruoraProcessManager`` via
/// ``ProcessEvent/processError(_:)``.
///
/// A runner-level classification distinct from the transport ``TruoraProcessAPIError`` and
/// the API-level ``TruoraProcessApiError``; ``TruoraProcessManager`` maps the latter into these
/// cases. Its shape mirrors the KMP process runner's `ProcessError` (PROC-6965) 1:1.
///
/// `Sendable`: the cases carry only `String` descriptions (not a raw `Error`) so
/// the type is safe to flow through the `nonisolated` ``TruoraProcessManager/events``
/// stream under Swift concurrency checking.
enum ProcessError: Error, Equatable {
    /// The backend reported a step/block type the SDK cannot render.
    case unsupportedFlow(stepType: String)

    /// The session token has expired (HTTP 401).
    case tokenExpired

    /// The identity process has expired (HTTP 410).
    case processExpired

    /// A transport-level failure; carries a human-readable description when available.
    case network(message: String?)

    /// Captured media could not be delivered to its presigned URL.
    case mediaUploadFailed(reason: String?)

    /// The step never resolved within `MAX_POLLING_TIME` (300s).
    case stepTimedOut(stepType: String)

    /// Any other, unclassified failure; carries the classified error's message.
    case unknown(message: String?)
}

// MARK: - Error Mapping

extension ProcessError {
    /// Maps a classified ``TruoraProcessApiError`` to the runner-level ``ProcessError``.
    static func from(_ apiError: TruoraProcessApiError) -> ProcessError {
        // 401 is surfaced by `TruoraProcessErrorMapper` as an `.unknown` with `httpCode == 401`;
        // treat it as an expired session token.
        if apiError.httpCode == 401 {
            return .tokenExpired
        }

        switch apiError.kind {
        case .processExpired:
            return .processExpired
        case .unsupportedStep:
            // Prefer the backend's specific message (which may name the step type)
            // over the generic static "Invalid step type".
            return .unsupportedFlow(stepType: apiError.apiErrorResponse?.message ?? apiError.message)
        case .network:
            return .network(message: apiError.underlyingError?.localizedDescription ?? apiError.message)
        default:
            // Keeps the backend's message, so a 400 "images were not uploaded" from
            // `verifyStep` survives into the emitted error.
            return .unknown(message: apiError.apiErrorResponse?.message ?? apiError.message)
        }
    }

    /// Maps a media upload failure onto the runner-level surface.
    static func from(_ uploadError: MediaUploadError) -> ProcessError {
        switch uploadError {
        case .signedUrlRejected(let code):
            .mediaUploadFailed(reason: "Upload URL rejected by storage (\(code))")
        case .untrustedHost(let url):
            .mediaUploadFailed(reason: "Upload URL is not a Truora file host: \(url)")
        case .missingMedia(let name):
            .mediaUploadFailed(reason: "No captured media for \(name)")
        case .uploadFailed(let apiError):
            .mediaUploadFailed(reason: apiError.errorDescription)
        }
    }
}
