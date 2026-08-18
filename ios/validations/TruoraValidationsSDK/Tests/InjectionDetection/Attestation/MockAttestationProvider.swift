import Foundation
@testable import TruoraValidationsSDK

/// Test double for `AttestationProviding`.
///
/// Records calls to `start()` and `shutdown()` and returns a configurable
/// snapshot from `snapshot()`.
actor MockAttestationProvider: AttestationProviding {
    var snapshotToReturn: AttestationSnapshot = .pending
    private(set) var startCallCount: Int = 0
    private(set) var shutdownCallCount: Int = 0

    func start() async {
        startCallCount += 1
    }

    func snapshot() async -> AttestationSnapshot {
        snapshotToReturn
    }

    func shutdown() async {
        shutdownCallCount += 1
    }

    /// Convenience setter callable from async test contexts.
    func setSnapshot(_ snapshot: AttestationSnapshot) {
        snapshotToReturn = snapshot
    }
}
