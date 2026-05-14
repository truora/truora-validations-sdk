#ifndef TRUORA_DETECTION_H
#define TRUORA_DETECTION_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/*
 * C ABI for the Truora injection-detection static library.
 *
 * Source of truth is src/ffi.rs in the injection-check repo.
 * Keep this header in sync with it — callers on iOS/Swift rely on
 * these exact signatures, and any drift surfaces only at link time
 * as "undeclared symbol" errors.
 */

/**
 * Runs all native detection checks and returns a bitmask of triggered signals.
 *
 * `checks_mask` is accepted for forward compatibility and ignored in v1 —
 * all checks always run. Callers may pass 0.
 *
 * Bitmask layout (version 1):
 *   Bits  0-7:  emulator/simulator signals
 *   Bits  8-11: camera tampering signals
 *   Bits 12-19: runtime hooking/injection signals
 *   Bits 20-31: native-only extras (Frida memory scan, TracerPid, etc.)
 *
 * The returned value is a plain integer — no heap allocation, no free needed.
 */
uint32_t td_run_checks(uint32_t checks_mask);

/**
 * Signs a detection report with HMAC-SHA256 and returns the 64-character
 * lowercase hex string.
 *
 * The caller MUST free the returned pointer with td_free_string().
 * Passing the pointer to C free() is undefined behavior.
 *
 * Null pointers for `validation_id` or `flow_type` are handled safely —
 * they are treated as empty strings rather than dereferenced.
 *
 * Returns a null-terminated C string on success, or a pointer to an empty
 * string on internal error.
 */
char* td_sign_report(
    const char* validation_id,
    const char* flow_type,
    uint32_t trust_score,
    uint32_t bitmask,
    uint64_t timestamp
);

/**
 * Returns the bitmask layout version for runtime compatibility checks.
 *
 * Callers should verify this matches the version expected by the managed
 * detection layer before OR-ing native and managed bitmasks. Version 1 is
 * the current layout.
 */
uint32_t td_bitmask_version(void);

/**
 * Returns the escalation threshold for trust-score blocking.
 *
 * If the combined trust score falls at or below this value, the managed layer
 * aborts the capture session. The value is hardcoded in v1.
 */
uint32_t td_get_escalation_threshold(void);

/**
 * Frees a string returned by td_sign_report.
 *
 * Passing NULL is safe. Passing any pointer not obtained from td_sign_report
 * is undefined behavior.
 */
void td_free_string(char* ptr);

#ifdef __cplusplus
}
#endif

#endif /* TRUORA_DETECTION_H */
