import XCTest
@testable import TruoraValidationsSDK

/// Pins the `NoOpReason -> wire string` mapping that the Android SDK expects.
///
/// IMPORTANT — wire-format layering:
/// `NoOpReason.wireValue` is the SUFFIX consumed by `AttestationStatusMapper`.
/// The final `attest_status` value sent on the wire is
/// `"unavailable_<wireValue>"` (e.g. `"unavailable_disabled"`,
/// `"unavailable_unsupported"`, `"unavailable_other"`), composed downstream by
/// `buildAttestationMetadata` from a `.unavailable(reason:)` snapshot. The
/// suffix-only assertions below pin the contract of this struct in isolation.
/// `AttestationStatusMapperTests` covers the canonical mapper-side wire-string
/// composition once the mapper lands.
///
/// If any of these assertions fail, the cross-platform `attest_status` contract
/// has drifted. Update Android in lockstep before changing these expectations.
final class NoOpAttestationProviderTests: XCTestCase {
    // MARK: - Wire taxonomy

    func testWireValue_disabled_isLiteralDisabled() {
        XCTAssertEqual(NoOpAttestationProvider.NoOpReason.disabled.wireValue, "disabled")
    }

    func testWireValue_unsupported_isLiteralUnsupported() {
        XCTAssertEqual(NoOpAttestationProvider.NoOpReason.unsupported.wireValue, "unsupported")
    }

    func testWireValue_other_returnsAssociatedStringVerbatim() {
        XCTAssertEqual(
            NoOpAttestationProvider.NoOpReason.other("future_value").wireValue,
            "future_value"
        )
    }

    // MARK: - Snapshot integration

    func testSnapshot_withDisabled_emitsUnavailableDisabled() async {
        let provider = NoOpAttestationProvider(reason: .disabled)
        let snapshot = await provider.snapshot()
        guard case .unavailable(let reason) = snapshot else {
            XCTFail("Expected .unavailable, got \(snapshot)")
            return
        }
        XCTAssertEqual(reason, "disabled")
    }

    func testSnapshot_withUnsupported_emitsUnavailableUnsupported() async {
        let provider = NoOpAttestationProvider(reason: .unsupported)
        let snapshot = await provider.snapshot()
        guard case .unavailable(let reason) = snapshot else {
            XCTFail("Expected .unavailable, got \(snapshot)")
            return
        }
        XCTAssertEqual(reason, "unsupported")
    }

    func testSnapshot_withOther_emitsUnavailableWithCustomReason() async {
        let provider = NoOpAttestationProvider(reason: .other("custom_taxonomy_value"))
        let snapshot = await provider.snapshot()
        guard case .unavailable(let reason) = snapshot else {
            XCTFail("Expected .unavailable, got \(snapshot)")
            return
        }
        XCTAssertEqual(reason, "custom_taxonomy_value")
    }
}
