import Foundation
@testable import TruoraValidationsSDK

/// In-memory `KeychainStoring` test double.
///
/// Backed by a `[String: Data]` dictionary protected by `NSLock` for thread-safe
/// access from async test contexts. Uses `@unchecked Sendable` because the lock
/// guarantees exclusive access to mutable state. The protocol methods are `async`
/// (per B3-4) but the implementation is synchronous — the `async` keyword satisfies
/// the protocol without requiring a real detached task in tests.
///
/// Failure-injection flags (`throwOnWrite`, `throwOnRead`) are guarded by the
/// same lock as the underlying storage. Callers MUST mutate them via
/// `setThrowOnWrite(_:)` / `setThrowOnRead(_:)` (or `configureFailures(write:read:)`
/// for atomic setup of both). This avoids a data race the compiler cannot
/// detect through `@unchecked Sendable`.
final class InMemoryKeychainStore: KeychainStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: Data] = [:]
    /// When `true`, `write(_:)` throws `KeychainError.writeFailed(-1)`. Protected by `lock`.
    private var _throwOnWrite: Bool = false
    /// When `true`, `read(_:)` throws `KeychainError.readFailed(-1)`. Protected by `lock`.
    private var _throwOnRead: Bool = false

    // MARK: - Failure-injection knobs (thread-safe)

    /// Toggles the write-failure flag under the lock.
    func setThrowOnWrite(_ value: Bool) {
        lock.lock()
        defer { lock.unlock() }
        _throwOnWrite = value
    }

    /// Toggles the read-failure flag under the lock.
    func setThrowOnRead(_ value: Bool) {
        lock.lock()
        defer { lock.unlock() }
        _throwOnRead = value
    }

    /// Atomically configures both failure flags under a single lock acquisition.
    func configureFailures(write: Bool, read: Bool) {
        lock.lock()
        defer { lock.unlock() }
        _throwOnWrite = write
        _throwOnRead = read
    }

    // MARK: - KeychainStoring

    func read(key: String) async throws -> Data? {
        lock.lock()
        defer { lock.unlock() }
        if _throwOnRead {
            throw KeychainError.readFailed(-1)
        }
        return storage[key]
    }

    func write(key: String, value: Data) async throws {
        lock.lock()
        defer { lock.unlock() }
        if _throwOnWrite {
            throw KeychainError.writeFailed(-1)
        }
        storage[key] = value
    }

    func delete(key: String) async throws {
        lock.lock()
        defer { lock.unlock() }
        storage.removeValue(forKey: key)
    }
}
