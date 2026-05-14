import Foundation

/// Errors thrown by `KeychainStoring` implementations.
enum KeychainError: Error, Equatable {
    /// A write (`SecItemAdd` or `SecItemUpdate`) returned a non-success OSStatus.
    case writeFailed(OSStatus)
    /// A read (`SecItemCopyMatching`) returned a non-success status other than `errSecItemNotFound`.
    case readFailed(OSStatus)
    /// The stored data could not be cast to the expected type.
    case unexpectedFormat
}

/// Test-seam wrapping `SecItem*` Keychain APIs.
///
/// The protocol is deliberately minimal: only the three operations needed by
/// `AppAttestProvider` (read, write, delete) are included.
///
/// All methods are `async` so that production implementations can dispatch the
/// synchronous `SecItem*` IPC to a detached task, freeing the calling actor's
/// serial executor from being pinned during the blocking IPC call.
///
/// `Sendable` is required so implementations can be stored inside the
/// `AppAttestProvider` actor without data-race warnings.
protocol KeychainStoring: Sendable {
    /// Reads the value associated with `key`, or returns `nil` when no item exists.
    ///
    /// - Parameter key: The account name used to look up the item.
    /// - Returns: The stored `Data`, or `nil` when the item is absent.
    /// - Throws: `KeychainError.readFailed` on unexpected system errors.
    func read(key: String) async throws -> Data?

    /// Writes (or overwrites) `value` for `key`.
    ///
    /// - Parameters:
    ///   - key: The account name to store.
    ///   - value: The data to persist.
    /// - Throws: `KeychainError.writeFailed` if the operation fails.
    func write(key: String, value: Data) async throws

    /// Deletes the item associated with `key`.
    ///
    /// Does not throw when the item is absent.
    ///
    /// - Parameter key: The account name to remove.
    /// - Throws: `KeychainError.writeFailed` on unexpected system errors.
    func delete(key: String) async throws
}

// MARK: - Production implementation

/// Concrete `KeychainStoring` backed by `SecItem*` APIs.
///
/// All items are stored as `kSecClassGenericPassword` under the service
/// `"com.truora.validations.attestation"`. No access group is set, so the
/// `keychain-access-groups` entitlement is NOT required.
///
/// Accessibility: `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` — items survive
/// app restarts after the first unlock but are NOT migrated to other devices via
/// encrypted backup. The attestation key is hardware-bound to this specific device;
/// cross-device migration would produce an invalid key on the new device.
struct SecItemKeychainStore: KeychainStoring {
    /// Keychain service identifier used for all attestation items.
    ///
    /// Exposed as `internal` (not `private`) so tests can query the same
    /// service when inspecting item attributes — keeping the test and the
    /// production code in lockstep if this string ever changes.
    static let serviceIdentifier = "com.truora.validations.attestation"

    private let service = SecItemKeychainStore.serviceIdentifier

    /// Runs `SecItemCopyMatching` on a detached task to avoid pinning the calling
    /// actor's serial executor during the synchronous IPC to `securityd`.
    func read(key: String) async throws -> Data? {
        let service = self.service
        return try await Task.detached(priority: .userInitiated) {
            let query: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: service,
                kSecAttrAccount: key,
                kSecReturnData: true,
                kSecMatchLimit: kSecMatchLimitOne
            ]
            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)

            switch status {
            case errSecSuccess:
                guard let data = result as? Data else { throw KeychainError.unexpectedFormat }
                return data
            case errSecItemNotFound:
                return nil
            default:
                throw KeychainError.readFailed(status)
            }
        }.value
    }

    /// Runs `SecItemAdd` / `SecItemUpdate` on a detached task to avoid pinning the calling
    /// actor's serial executor during the synchronous IPC to `securityd`.
    func write(key: String, value: Data) async throws {
        let service = self.service
        try await Task.detached(priority: .userInitiated) {
            // Try adding first; if the item already exists, update it.
            let addQuery: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: service,
                kSecAttrAccount: key,
                kSecValueData: value,
                kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            ]
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)

            if addStatus == errSecSuccess {
                return
            } else if addStatus == errSecDuplicateItem {
                // Update the existing item.
                let searchQuery: [CFString: Any] = [
                    kSecClass: kSecClassGenericPassword,
                    kSecAttrService: service,
                    kSecAttrAccount: key
                ]
                let attributesToUpdate: [CFString: Any] = [kSecValueData: value]
                let updateStatus = SecItemUpdate(
                    searchQuery as CFDictionary,
                    attributesToUpdate as CFDictionary
                )
                guard updateStatus == errSecSuccess else {
                    throw KeychainError.writeFailed(updateStatus)
                }
            } else {
                throw KeychainError.writeFailed(addStatus)
            }
        }.value
    }

    /// Runs `SecItemDelete` on a detached task to avoid pinning the calling
    /// actor's serial executor during the synchronous IPC to `securityd`.
    func delete(key: String) async throws {
        let service = self.service
        try await Task.detached(priority: .userInitiated) {
            let query: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: service,
                kSecAttrAccount: key
            ]
            let status = SecItemDelete(query as CFDictionary)
            // Tolerate "not found" — idempotent delete is fine.
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw KeychainError.writeFailed(status)
            }
        }.value
    }
}
