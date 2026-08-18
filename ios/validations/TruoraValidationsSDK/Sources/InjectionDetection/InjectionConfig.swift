import Foundation

/// Configuration for the injection attack detection module.
///
/// Detection is always enforced when enabled. If the trust score falls
/// below `blockingThreshold`, the SDK blocks the capture flow.
struct InjectionConfig: Equatable {
    /// Whether injection detection is enabled
    let enabled: Bool

    /// Trust score threshold (0-100). Operation blocked if score is below this value.
    let blockingThreshold: Int

    /// Whether hardware attestation (App Attest) is enabled.
    ///
    /// Defaults to `false` so that existing integrators are not unexpectedly impacted.
    /// Opt in by setting this to `true`. When `false`, the provider is replaced with
    /// `NoOpAttestationProvider(reason: .disabled)` and no App Attest calls are made.
    let attestationEnabled: Bool

    init(enabled: Bool = true, blockingThreshold: Int = 50, attestationEnabled: Bool = false) {
        self.enabled = enabled
        self.blockingThreshold = blockingThreshold
        self.attestationEnabled = attestationEnabled
    }
}
