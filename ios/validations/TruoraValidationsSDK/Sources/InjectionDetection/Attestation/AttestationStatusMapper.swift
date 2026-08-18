import Foundation

/// Maps an `AttestationSnapshot` to the four metadata fields expected by the
/// injection-detection logging contract.
///
/// **Wire format** (always present, never omitted):
/// - `attest_token`     — `String`; the assertion token or `""`.
/// - `attest_type`      — `String`; `"app_attest"` when ready, `"none"` otherwise.
/// - `attest_status`    — `String`; see taxonomy table below.
/// - `device_api_level` — `Int`; always `0` on iOS (iOS major version is NOT sent here).
///
/// **Status taxonomy**:
/// | `attest_status`             | Source snapshot                                |
/// |-----------------------------|------------------------------------------------|
/// | `ok`                        | `.ready(...)`                                  |
/// | `pending`                   | `.pending`                                     |
/// | `unavailable_unsupported`   | `.unavailable("unsupported")`                  |
/// | `unavailable_disabled`      | `.unavailable("disabled")`                     |
/// | `unavailable_other`         | `.unavailable(<any other reason>)`             |
/// | `error_timeout`             | `.error("timeout")`                            |
/// | `error_quota`               | `.error("quota")`                              |
/// | `error_keychain`            | `.error("keychain")`                           |
/// | `error_other`               | `.error("other")` or any unrecognised reason   |
func buildAttestationMetadata(_ snapshot: AttestationSnapshot) -> [String: Any] {
    switch snapshot {
    case .ready(let token, _):
        return [
            "attest_token": token,
            "attest_type": "app_attest",
            "attest_status": "ok",
            "device_api_level": 0
        ]

    case .pending:
        return [
            "attest_token": "",
            "attest_type": "none",
            "attest_status": "pending",
            "device_api_level": 0
        ]

    case .unavailable(let reason):
        let status = switch reason {
        case "unsupported": "unavailable_unsupported"
        case "disabled": "unavailable_disabled"
        default: "unavailable_other"
        }
        return [
            "attest_token": "",
            "attest_type": "none",
            "attest_status": status,
            "device_api_level": 0
        ]

    case .error(let reason):
        let status = switch reason {
        case "timeout": "error_timeout"
        case "quota": "error_quota"
        case "keychain": "error_keychain"
        default: "error_other"
        }
        return [
            "attest_token": "",
            "attest_type": "none",
            "attest_status": status,
            "device_api_level": 0
        ]
    }
}
