import XCTest
@testable import TruoraValidationsSDK

final class AttestationStatusMapperTests: XCTestCase {
    // MARK: - Helpers

    private func metadata(for snapshot: AttestationSnapshot) -> [String: Any] {
        buildAttestationMetadata(snapshot)
    }

    // MARK: - All variants contain the four expected keys

    func testAllVariants_containFourRequiredKeys() {
        let snapshots: [AttestationSnapshot] = [
            .pending,
            .ready(token: "tok", type: "app_attest"),
            .unavailable(reason: "unsupported"),
            .unavailable(reason: "disabled"),
            .unavailable(reason: "something_new"),
            .error(reason: "timeout"),
            .error(reason: "quota"),
            .error(reason: "keychain"),
            .error(reason: "other")
        ]
        for snapshot in snapshots {
            let m = metadata(for: snapshot)
            XCTAssertNotNil(m["attest_token"], "attest_token missing for \(snapshot)")
            XCTAssertNotNil(m["attest_type"], "attest_type missing for \(snapshot)")
            XCTAssertNotNil(m["attest_status"], "attest_status missing for \(snapshot)")
            XCTAssertNotNil(m["device_api_level"], "device_api_level missing for \(snapshot)")
        }
    }

    // MARK: - device_api_level is always 0 on iOS

    func testAllVariants_deviceApiLevelIsZero() {
        let snapshots: [AttestationSnapshot] = [
            .pending,
            .ready(token: "t", type: "app_attest"),
            .unavailable(reason: "unsupported"),
            .error(reason: "other")
        ]
        for snapshot in snapshots {
            let level = metadata(for: snapshot)["device_api_level"] as? Int
            XCTAssertEqual(level, 0, "device_api_level must be 0 on iOS for \(snapshot)")
        }
    }

    // MARK: - .ready

    func testReady_statusIsOk() {
        let m = metadata(for: .ready(token: "abc", type: "app_attest"))
        XCTAssertEqual(m["attest_status"] as? String, "ok")
    }

    func testReady_typeIsAppAttest() {
        let m = metadata(for: .ready(token: "abc", type: "app_attest"))
        XCTAssertEqual(m["attest_type"] as? String, "app_attest")
    }

    func testReady_tokenIsPreserved() {
        let m = metadata(for: .ready(token: "mytoken123", type: "app_attest"))
        XCTAssertEqual(m["attest_token"] as? String, "mytoken123")
    }

    // MARK: - .pending

    func testPending_statusIsPending() {
        let m = metadata(for: .pending)
        XCTAssertEqual(m["attest_status"] as? String, "pending")
    }

    func testPending_typeIsNone() {
        let m = metadata(for: .pending)
        XCTAssertEqual(m["attest_type"] as? String, "none")
    }

    func testPending_tokenIsEmpty() {
        let m = metadata(for: .pending)
        XCTAssertEqual(m["attest_token"] as? String, "")
    }

    // MARK: - .unavailable

    func testUnavailable_unsupported_statusIsUnavailableUnsupported() {
        let m = metadata(for: .unavailable(reason: "unsupported"))
        XCTAssertEqual(m["attest_status"] as? String, "unavailable_unsupported")
    }

    func testUnavailable_disabled_statusIsUnavailableDisabled() {
        // B4-2: "disabled" must emit a distinct wire value from "unsupported".
        let m = metadata(for: .unavailable(reason: "disabled"))
        XCTAssertEqual(m["attest_status"] as? String, "unavailable_disabled")
    }

    func testUnavailable_unknownReason_statusIsUnavailableOther() {
        // Any unrecognised reason falls through to unavailable_other.
        let m = metadata(for: .unavailable(reason: "something_new"))
        XCTAssertEqual(m["attest_status"] as? String, "unavailable_other")
    }

    func testUnavailable_typeIsNone() {
        let m = metadata(for: .unavailable(reason: "unsupported"))
        XCTAssertEqual(m["attest_type"] as? String, "none")
    }

    func testUnavailable_tokenIsEmpty() {
        let m = metadata(for: .unavailable(reason: "unsupported"))
        XCTAssertEqual(m["attest_token"] as? String, "")
    }

    // MARK: - .error variants

    func testError_timeout_statusIsErrorTimeout() {
        let m = metadata(for: .error(reason: "timeout"))
        XCTAssertEqual(m["attest_status"] as? String, "error_timeout")
    }

    func testError_quota_statusIsErrorQuota() {
        let m = metadata(for: .error(reason: "quota"))
        XCTAssertEqual(m["attest_status"] as? String, "error_quota")
    }

    func testError_keychain_statusIsErrorKeychain() {
        let m = metadata(for: .error(reason: "keychain"))
        XCTAssertEqual(m["attest_status"] as? String, "error_keychain")
    }

    func testError_other_statusIsErrorOther() {
        let m = metadata(for: .error(reason: "other"))
        XCTAssertEqual(m["attest_status"] as? String, "error_other")
    }

    func testError_unknownReason_statusIsErrorOther() {
        // Any unrecognised reason falls through to error_other
        let m = metadata(for: .error(reason: "something_unexpected"))
        XCTAssertEqual(m["attest_status"] as? String, "error_other")
    }

    func testError_typeIsNone() {
        let m = metadata(for: .error(reason: "timeout"))
        XCTAssertEqual(m["attest_type"] as? String, "none")
    }

    func testError_tokenIsEmpty() {
        let m = metadata(for: .error(reason: "quota"))
        XCTAssertEqual(m["attest_token"] as? String, "")
    }

    // MARK: - End-to-end wire format (NoOp -> snapshot -> mapper)

    /// Pins the COMPLETE `attest_status` wire string produced when a NoOp
    /// snapshot flows through `buildAttestationMetadata`. This guards the
    /// `unavailable_` prefix that downstream backends key on; a regression
    /// that drops the prefix would slip past the suffix-only assertions
    /// in `NoOpAttestationProviderTests`. Mirrors the taxonomy table in
    /// `AttestationStatusMapper`.
    func testWireValue_throughMapper_producesUnavailableUnderscoreReason() async {
        let cases: [(NoOpAttestationProvider.NoOpReason, String)] = [
            (.disabled, "unavailable_disabled"),
            (.unsupported, "unavailable_unsupported"),
            // Any `.other` value collapses to `unavailable_other` at the
            // mapper layer — the suffix is intentionally NOT echoed back.
            (.other("test"), "unavailable_other")
        ]
        for (reason, expectedStatus) in cases {
            let provider = NoOpAttestationProvider(reason: reason)
            let snapshot = await provider.snapshot()
            let m = metadata(for: snapshot)
            XCTAssertEqual(
                m["attest_status"] as? String,
                expectedStatus,
                "attest_status mismatch for NoOpReason \(reason)"
            )
            XCTAssertEqual(
                m["attest_type"] as? String,
                "none",
                "attest_type must be 'none' for unavailable snapshots"
            )
            XCTAssertEqual(
                m["attest_token"] as? String,
                "",
                "attest_token must be empty for unavailable snapshots"
            )
        }
    }

    // MARK: - Sendable conformance (I3)

    /// Verifies that `AttestationSnapshot` can be passed across an actor boundary.
    ///
    /// If `AttestationSnapshot` does not conform to `Sendable`, this test will
    /// fail to compile. The actor boundary crossing is the compile-time proof.
    func testAttestationSnapshot_isSendableAcrossActorBoundary() async {
        let snapshot: AttestationSnapshot = .ready(token: "tok", type: "app_attest")
        // Passing `snapshot` into an isolated actor closure is only allowed when
        // `AttestationSnapshot` is `Sendable`. The Swift compiler enforces this.
        let result = await Task.detached {
            snapshot
        }.value
        if case .ready(let token, let type) = result {
            XCTAssertEqual(token, "tok")
            XCTAssertEqual(type, "app_attest")
        } else {
            XCTFail("Expected .ready after crossing actor boundary, got \(result)")
        }
    }
}
