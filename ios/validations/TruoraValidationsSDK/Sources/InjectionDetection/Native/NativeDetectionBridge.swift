import Foundation

#if canImport(TruoraDetection)
import TruoraDetection
#endif

/// Bridge to the pre-compiled TruoraDetection C library (XCFramework).
///
/// Returns `nil` from `create()` when the XCFramework binary slices are absent.
/// All callers receive `signature = "unsigned"` in that case.
///
/// The library exposes C functions via `module.modulemap`:
/// - `td_bitmask_version()` — version probe (returns > 0 when linked)
/// - `td_run_checks(checks_mask)` — runs native detection checks
/// - `td_sign_report(...)` — HMAC-SHA256 signature
/// - `td_get_escalation_threshold()` — trust score blocking threshold
/// - `td_free_string(ptr)` — frees Rust-allocated strings
final class NativeDetectionBridge: DetectionBridging {
    private init() {}

    /// Attempt to create a bridge instance.
    /// Returns nil when TruoraDetection.xcframework is not linked or the
    /// library probe returns 0.
    static func create() -> NativeDetectionBridge? {
        #if canImport(TruoraDetection)
        guard td_bitmask_version() > 0 else {
            debugLog("TruoraDetection linked but td_bitmask_version() returned 0")
            return nil
        }
        return NativeDetectionBridge()
        #else
        return nil
        #endif
    }

    /// Bitmask layout version from native library.
    func bitmaskVersion() -> UInt32 {
        #if canImport(TruoraDetection)
        return td_bitmask_version()
        #else
        return 0
        #endif
    }

    /// Run native detection checks and return the raw bitmask.
    func runChecks(checksMask: UInt32) -> UInt32 {
        #if canImport(TruoraDetection)
        return td_run_checks(checksMask)
        #else
        return 0
        #endif
    }

    /// Returns the escalation threshold for trust score blocking.
    func getEscalationThreshold() -> UInt32 {
        #if canImport(TruoraDetection)
        return td_get_escalation_threshold()
        #else
        return 50
        #endif
    }

    /// Generate HMAC-SHA256 signature for the detection report.
    ///
    /// Returns `"unsigned"` if the native library fails to produce a signature.
    /// Memory ownership: Rust allocates the string via `into_raw()`;
    /// we free it via `td_free_string()` in the `defer` block.
    func signReport(
        validationId: String,
        flowType: String,
        trustScore: UInt32,
        riskBitmask: UInt32,
        timestamp: UInt64
    ) -> String {
        #if canImport(TruoraDetection)
        guard let ptr = td_sign_report(
            validationId,
            flowType,
            trustScore,
            riskBitmask,
            timestamp
        ) else {
            debugLog("td_sign_report returned nil — signature unavailable")
            return "unsigned"
        }
        defer { td_free_string(UnsafeMutablePointer(mutating: ptr)) }
        return String(cString: ptr)
        #else
        return "unsigned"
        #endif
    }
}
