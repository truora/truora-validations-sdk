import Foundation
@testable import TruoraValidationsSDK

/// Configurable mock for `SystemInfoProviding` used in injection detection tests.
///
/// All properties are settable via init for deterministic test scenarios.
/// Properties are mutable so tests can simulate state changes between detection
/// layer calls (e.g., a new jailbreak file appearing mid-session).
final class MockSystemInfoProvider: SystemInfoProviding, @unchecked Sendable {
    var isSimulator: Bool
    var deviceModel: String
    var simulatorDeviceName: String?
    var existingFiles: Set<String>
    var canWriteSandbox: Bool
    var loadedDylibs: [String]

    init(
        isSimulator: Bool = false,
        deviceModel: String = "iPhone",
        simulatorDeviceName: String? = nil,
        existingFiles: Set<String> = [],
        canWriteSandbox: Bool = false,
        loadedDylibs: [String] = []
    ) {
        self.isSimulator = isSimulator
        self.deviceModel = deviceModel
        self.simulatorDeviceName = simulatorDeviceName
        self.existingFiles = existingFiles
        self.canWriteSandbox = canWriteSandbox
        self.loadedDylibs = loadedDylibs
    }

    func fileExists(at path: String) -> Bool {
        existingFiles.contains(path)
    }

    func canWriteOutsideSandbox(testPath: String) -> Bool {
        canWriteSandbox
    }
}
