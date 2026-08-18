import Foundation

/// Contract for an attestation provider.
///
/// Conforming types run a hardware-rooted attestation flow in the background
/// and expose the result via a non-blocking `snapshot()` poll. The reporter
/// calls `snapshot()` each time it fires a layer report — the result may be
/// `.pending` on early layers and `.ready` once the warm-up finishes.
///
/// Lifecycle:
/// 1. The holder calls `start()` once, immediately after construction.
///    `start()` is fire-and-forget: it spawns a background Task and returns.
/// 2. The reporter calls `await snapshot()` on each layer report.
/// 3. The holder calls `shutdown()` when the session ends; this cancels any
///    in-flight warm-up Task.
///
/// `Sendable` is required so that the provider can be passed across actor
/// boundaries (e.g., from `ValidationConfig` to `DetectionReporter`).
protocol AttestationProviding: Sendable {
    /// Starts the attestation warm-up in the background.
    ///
    /// Safe to call from any context; implementation must not block the caller.
    /// Calling `start()` more than once has no effect once warm-up is started.
    func start() async

    /// Returns the current attestation state without blocking.
    ///
    /// Returns `.pending` while warm-up is still running.
    /// Returns the final state once warm-up is complete.
    func snapshot() async -> AttestationSnapshot

    /// Cancels any in-flight warm-up Task and releases resources.
    func shutdown() async
}
