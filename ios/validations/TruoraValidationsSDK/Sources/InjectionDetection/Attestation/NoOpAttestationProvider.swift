import Foundation

/// A no-op `AttestationProviding` implementation used when attestation is
/// disabled, unsupported, or not yet configured.
///
/// `start()` and `shutdown()` are no-ops at the detection layer (no token is
/// generated, no keychain is touched, nothing is scheduled). When a logger is
/// injected, both `start()` and `snapshot()` emit observability events so the
/// backend can see that attestation is intentionally absent for this session
/// — a critical signal for a security SDK.
///
/// This type is deliberately a `struct` (value type). All stored properties are
/// immutable and `Sendable`, so the struct itself is `Sendable` and may cross
/// actor boundaries safely.
struct NoOpAttestationProvider: AttestationProviding {
    /// Closed taxonomy of valid `reason` values for the unavailable snapshot.
    ///
    /// Using a typed enum prevents typos and stray values from leaking into the
    /// wire format (e.g. `attest_status = "unavailable_foo"` would break the
    /// contract with Android). The mapper prepends `"unavailable_"` to the
    /// enum's `wireValue`, producing strings like `"unavailable_disabled"` or
    /// `"unavailable_unsupported"`.
    ///
    /// `.other` exists strictly as a forward-extensibility escape hatch (e.g.
    /// future taxonomy additions discovered at runtime). Production code should
    /// prefer the named cases.
    enum NoOpReason: Equatable {
        /// Integrator explicitly opted out via config. Wire value: `"disabled"`.
        case disabled
        /// Device/OS does not support hardware attestation. Wire value: `"unsupported"`.
        case unsupported
        /// Forward-compatible escape hatch for taxonomy values not yet enumerated.
        /// Wire value: the associated string verbatim.
        case other(String)

        /// The literal suffix passed to `AttestationSnapshot.unavailable(reason:)`.
        var wireValue: String {
            switch self {
            case .disabled: "disabled"
            case .unsupported: "unsupported"
            case .other(let value): value
            }
        }
    }

    private let reason: String
    private let logger: TruoraLogger?

    /// Preferred initializer — enforces the taxonomy at compile time.
    ///
    /// - Parameters:
    ///   - reason: A typed `NoOpReason`. The wire format becomes
    ///     `attest_status = "unavailable_<reason.wireValue>"`.
    ///   - logger: Optional `TruoraLogger`. When supplied, `start()` and
    ///     `snapshot()` emit a `device` event so the backend can see the
    ///     attestation-unavailable lifecycle. Defaults to `nil` for tests and
    ///     legacy call sites.
    init(reason: NoOpReason, logger: TruoraLogger? = nil) {
        self.reason = reason.wireValue
        self.logger = logger
    }

    /// Legacy String-based initializer.
    ///
    /// Retained for source compatibility with existing call sites; new callers
    /// MUST use `init(reason: NoOpReason)` so the wire-format taxonomy stays in
    /// sync with Android. The String form allows invalid values (e.g.
    /// `"unavailable_foo"`) that the wire contract forbids.
    @available(*, deprecated, message: "Use init(reason: NoOpReason) for typed taxonomy values")
    init(reason: String, logger: TruoraLogger? = nil) {
        self.reason = reason
        self.logger = logger
    }

    func start() async {
        await logger?.logDevice(
            eventName: "injection_attestation_noop_started",
            level: .info,
            retention: .oneWeek,
            metadata: ["reason": reason]
        )
    }

    func snapshot() async -> AttestationSnapshot {
        await logger?.logDevice(
            eventName: "injection_attestation_noop_snapshot",
            level: .info,
            retention: .oneWeek,
            metadata: ["reason": reason]
        )
        return .unavailable(reason: reason)
    }

    func shutdown() async {}
}
