import Foundation

/// Represents the current state of the hardware attestation process.
///
/// The provider starts in `.pending` while the warm-up task is in-flight.
/// Once the App Attest flow completes the state transitions to `.ready` or
/// one of the error/unavailable variants. Normally this is a one-way ratchet
/// from `.pending` to a terminal state. The exception is `DCError.invalidKey`
/// from `generateAssertion`, which purges the cached key and resets the state
/// to `.pending` so the next `start()` regenerates with a fresh key.
enum AttestationSnapshot {
    /// Warm-up is still in progress; no token is available yet.
    case pending

    /// A valid assertion token was acquired.
    /// - token: Base64-encoded App Attest assertion data.
    /// - type: Always `"app_attest"` on iOS.
    case ready(token: String, type: String)

    /// Attestation is not available on this device or configuration.
    /// - reason: `"unsupported"` (A11 or below, iOS < 14, simulator) |
    ///           `"disabled"` (explicitly opted-out via config).
    case unavailable(reason: String)

    /// Attestation failed with a recoverable or permanent error.
    /// - reason: `"timeout"` | `"quota"` | `"keychain"` | `"other"`.
    case error(reason: String)
}
