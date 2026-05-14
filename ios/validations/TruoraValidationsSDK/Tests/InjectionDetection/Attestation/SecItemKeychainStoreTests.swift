import Security
import XCTest
@testable import TruoraValidationsSDK

/// Integration tests for `SecItemKeychainStore` using the real Keychain APIs.
///
/// These tests touch the test host's actual Keychain. `tearDown` removes the
/// per-test key so no state leaks between test cases. Each test gets a unique
/// `testKey` via `setUp()` so parallel runs (XCTest can parallelize on demand)
/// cannot collide on the same keychain account.
///
/// **Entitlement requirement**: `SecItem*` APIs require the test host app to
/// have a valid code-signing identity and keychain entitlement when running in
/// the simulator. On CI (unsigned or no-entitlement build) the first operation
/// returns `errSecMissingEntitlement` and the test is skipped rather than
/// failed, because the failure is an environment constraint, not a code
/// defect. The same tests pass on a physical device or in a properly-signed
/// simulator run.
final class SecItemKeychainStoreTests: XCTestCase {
    private let store = SecItemKeychainStore()
    /// Unique per-test key assigned in `setUp()`; prevents collisions when
    /// XCTest parallelizes or when `tearDown` is interrupted.
    private var testKey: String!

    override func setUp() async throws {
        try await super.setUp()
        testKey = "com.truora.validations.attestation.test_key.\(UUID().uuidString)"
    }

    override func tearDown() async throws {
        try? await store.delete(key: testKey)
        try await super.tearDown()
    }

    // MARK: - Environment guard

    /// Attempts a probe write. Throws `XCTSkip` when the environment lacks the
    /// required entitlements (`errSecMissingEntitlement`).
    private func requireKeychainAccess() async throws {
        let probe = Data("probe".utf8)
        let probeKey = testKey + ".probe"
        do {
            try await store.write(key: probeKey, value: probe)
            try? await store.delete(key: probeKey)
        } catch KeychainError.writeFailed(let status)
            where status == OSStatus(errSecMissingEntitlement) {
            throw XCTSkip(
                "Keychain unavailable in this environment (errSecMissingEntitlement). " +
                    "Tests skipped on unsigned simulator."
            )
        }
    }

    // MARK: - (a) write then read returns same data

    func testWriteThenRead_returnsSameData() async throws {
        try await requireKeychainAccess()
        let value = Data("hello-world".utf8)
        try await store.write(key: testKey, value: value)
        let result = try await store.read(key: testKey)
        XCTAssertEqual(result, value)
    }

    // MARK: - (b) read on missing key returns nil

    func testRead_missingKey_returnsNil() async throws {
        try await requireKeychainAccess()
        let result = try await store.read(key: testKey)
        XCTAssertNil(result)
    }

    // MARK: - (c) double write (overwrite) succeeds

    func testDoubleWrite_overwrite_succeeds() async throws {
        try await requireKeychainAccess()
        let first = Data("first".utf8)
        let second = Data("second".utf8)
        try await store.write(key: testKey, value: first)
        try await store.write(key: testKey, value: second) // must not throw
        let result = try await store.read(key: testKey)
        XCTAssertEqual(result, second, "Second write must overwrite the first")
    }

    // MARK: - (d) delete removes item

    func testDelete_removesItem() async throws {
        try await requireKeychainAccess()
        try await store.write(key: testKey, value: Data("to-delete".utf8))
        try await store.delete(key: testKey)
        let result = try await store.read(key: testKey)
        XCTAssertNil(result, "Item must be absent after delete")
    }

    // MARK: - (e) read after delete returns nil

    func testRead_afterDelete_returnsNil() async throws {
        try await requireKeychainAccess()
        try await store.write(key: testKey, value: Data("item".utf8))
        try await store.delete(key: testKey)
        let result = try await store.read(key: testKey)
        XCTAssertNil(result)
    }

    // MARK: - delete non-existent key does not throw

    func testDelete_nonExistentKey_doesNotThrow() async throws {
        try await requireKeychainAccess()
        try await store.delete(key: testKey)
    }

    // MARK: - (B3-3) Accessibility must be ThisDeviceOnly to prevent cross-device backup migration

    /// Regression test: verifies that items written by `SecItemKeychainStore` use
    /// `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
    ///
    /// The attestation key is hardware-bound; migrating it to another device via
    /// encrypted backup produces an invalid key. `ThisDeviceOnly` prevents that.
    func testWrite_usesAfterFirstUnlockThisDeviceOnly_accessibility() async throws {
        try await requireKeychainAccess()
        let value = Data("accessibility-check".utf8)
        try await store.write(key: testKey, value: value)

        // Query the item back including its attributes to read kSecAttrAccessible.
        // Reuse SecItemKeychainStore.serviceIdentifier so this test never drifts
        // from the production constant.
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: SecItemKeychainStore.serviceIdentifier,
            kSecAttrAccount: testKey,
            kSecReturnAttributes: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        XCTAssertEqual(status, errSecSuccess, "SecItemCopyMatching must succeed")

        let attributes = result as? [CFString: Any]
        let accessible = attributes?[kSecAttrAccessible] as? String
        XCTAssertEqual(
            accessible,
            kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String,
            "Accessibility must be kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly — " +
                "not the plain AfterFirstUnlock variant which allows backup migration"
        )
    }
}
