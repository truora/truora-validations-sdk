#!/usr/bin/env bash
# Pre-build check: warns when TruoraDetection.xcframework binary slices are absent.
# Added as a Tuist .pre() script on TruoraValidationsSDK target.
# Follows the copy-webview.sh pattern: warn but never fail the build.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
XCFRAMEWORK="$PROJECT_DIR/XCFrameworks/TruoraDetection.xcframework"
DEVICE_SLICE="$XCFRAMEWORK/ios-arm64/TruoraDetection.framework"

if [ ! -d "$DEVICE_SLICE" ]; then
    echo "warning: Native detection binary not found at $XCFRAMEWORK"
    echo "warning: SDK will run in degraded mode."
    echo "warning: Copy TruoraDetection.xcframework from injection-check build output (scripts/build-ios.sh)."
fi
# Always exit 0 — absence is not a build failure.
