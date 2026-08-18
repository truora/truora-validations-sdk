import CryptoKit
@preconcurrency import DeviceCheck
import Foundation

/// Test-seam wrapping `DCAppAttestService`.
///
/// Every completion-handler API in `DCAppAttestService` is projected here as
/// `async throws`, making the actor implementation trivially testable without
/// subclassing a system type.
///
/// `Sendable` is required so the protocol can be stored inside `AppAttestProvider`
/// (an `actor`) without compiler warnings.
@available(iOS 14.0, *)
protocol AppAttestServicing: Sendable {
    /// Whether App Attest is supported on this device/configuration.
    ///
    /// Returns `false` on simulators, iOS < 14, and devices with A11 or older.
    var isSupported: Bool { get }

    /// Generates a new cryptographic key in the Secure Enclave and returns its ID.
    ///
    /// - Throws: `DCError` on failure.
    func generateKey() async throws -> String

    /// Attests a key with Apple's servers using the supplied client data hash.
    ///
    /// - Parameters:
    ///   - keyID: The key ID returned by `generateKey()`.
    ///   - clientDataHash: SHA-256 hash of the challenge data.
    /// - Returns: Raw attestation object bytes.
    /// - Throws: `DCError` on failure.
    func attestKey(keyID: String, clientDataHash: Data) async throws -> Data

    /// Generates a one-time assertion for the supplied key and client data.
    ///
    /// - Parameters:
    ///   - keyID: The persisted key ID.
    ///   - clientDataHash: SHA-256 hash of the request data to sign.
    /// - Returns: Raw assertion bytes.
    /// - Throws: `DCError` on failure.
    func generateAssertion(keyID: String, clientDataHash: Data) async throws -> Data
}

// MARK: - Production implementation

/// Concrete `AppAttestServicing` that delegates to `DCAppAttestService.shared`.
///
/// Each async method wraps the corresponding completion-handler API using
/// `withCheckedThrowingContinuation` so the actor implementation can `await`
/// them directly without callback nesting.
@available(iOS 14.0, *)
struct SystemAppAttestService: AppAttestServicing {
    private let service = DCAppAttestService.shared

    var isSupported: Bool {
        service.isSupported
    }

    func generateKey() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            service.generateKey { keyID, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let keyID {
                    continuation.resume(returning: keyID)
                } else {
                    continuation.resume(throwing: DCError(.unknownSystemFailure))
                }
            }
        }
    }

    func attestKey(keyID: String, clientDataHash: Data) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            service.attestKey(keyID, clientDataHash: clientDataHash) { attestationObject, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let attestationObject {
                    continuation.resume(returning: attestationObject)
                } else {
                    continuation.resume(throwing: DCError(.unknownSystemFailure))
                }
            }
        }
    }

    func generateAssertion(keyID: String, clientDataHash: Data) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            service.generateAssertion(keyID, clientDataHash: clientDataHash) { assertionObject, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let assertionObject {
                    continuation.resume(returning: assertionObject)
                } else {
                    continuation.resume(throwing: DCError(.unknownSystemFailure))
                }
            }
        }
    }
}
