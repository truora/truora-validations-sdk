import Foundation
@testable import TruoraValidationsSDK

/// Test double for `AppAttestServicing`.
///
/// All async methods return a configurable `Result`. Tests set `isSupportedValue`
/// and the per-method stub properties before exercising the provider under test.
@available(iOS 14.0, *)
final class MockAppAttestService: AppAttestServicing, @unchecked Sendable {
    // MARK: - isSupported

    var isSupportedValue: Bool = true
    var isSupported: Bool {
        isSupportedValue
    }

    // MARK: - generateKey

    var generateKeyResult: Result<String, Error> = .success("mock-key-id")
    /// Number of consecutive `serverUnavailable` errors already returned from `generateKey`.
    /// Used by tests to simulate the quota-heuristic path.
    var generateKeyCallCount: Int = 0

    func generateKey() async throws -> String {
        generateKeyCallCount += 1
        return try generateKeyResult.get()
    }

    // MARK: - attestKey

    var attestKeyResult: Result<Data, Error> = .success(Data("mock-attest-object".utf8))

    func attestKey(keyID: String, clientDataHash: Data) async throws -> Data {
        try attestKeyResult.get()
    }

    // MARK: - generateAssertion

    var generateAssertionResult: Result<Data, Error> = .success(Data("mock-assertion".utf8))
    var generateAssertionCallCount: Int = 0

    func generateAssertion(keyID: String, clientDataHash: Data) async throws -> Data {
        generateAssertionCallCount += 1
        return try generateAssertionResult.get()
    }
}
