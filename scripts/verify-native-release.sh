#!/bin/zsh
set -euo pipefail

PROJECT_ROOT="${0:A:h:h}"
APP_BUNDLE="${1:-$PROJECT_ROOT/outputs/Curlman.app}"
DMG_PATH="${2:-$PROJECT_ROOT/outputs/Curlman.dmg}"
REQUIRE_NOTARIZATION="${CURLMAN_REQUIRE_NOTARIZATION:-0}"
BINARY="$APP_BUNDLE/Contents/MacOS/CurlmanNative"

fail() {
    echo "Release verification failed: $1" >&2
    exit 1
}

[[ -d "$APP_BUNDLE" ]] || fail "missing app bundle at $APP_BUNDLE"
[[ -f "$DMG_PATH" ]] || fail "missing DMG at $DMG_PATH"
[[ -x "$BINARY" ]] || fail "missing executable at $BINARY"
[[ -f "$APP_BUNDLE/Contents/Resources/PrivacyInfo.xcprivacy" ]] || fail "privacy manifest is missing"

plutil -lint \
    "$APP_BUNDLE/Contents/Info.plist" \
    "$APP_BUNDLE/Contents/Resources/PrivacyInfo.xcprivacy" >/dev/null

ARCHITECTURES="$(lipo -archs "$BINARY")"
[[ " $ARCHITECTURES " == *" arm64 "* ]] || fail "arm64 architecture is missing"
[[ " $ARCHITECTURES " == *" x86_64 "* ]] || fail "x86_64 architecture is missing"

codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
hdiutil verify "$DMG_PATH" >/dev/null

ENTITLEMENTS_OUTPUT="$(mktemp)"
cleanup() {
    rm -f "$ENTITLEMENTS_OUTPUT"
}
trap cleanup EXIT
codesign -d --entitlements :- "$APP_BUNDLE" >"$ENTITLEMENTS_OUTPUT" 2>/dev/null
if /usr/libexec/PlistBuddy -c 'Print :com.apple.security.get-task-allow' "$ENTITLEMENTS_OUTPUT" 2>/dev/null | grep -q true; then
    fail "development entitlement get-task-allow is enabled"
fi

if [[ "$REQUIRE_NOTARIZATION" == "1" ]]; then
    SIGNATURE_DETAILS="$(codesign -dvvv "$APP_BUNDLE" 2>&1)"
    [[ "$SIGNATURE_DETAILS" == *"Authority=Developer ID Application:"* ]] || fail "Developer ID signature is missing"
    [[ "$SIGNATURE_DETAILS" == *"Runtime Version="* ]] || fail "Hardened Runtime is missing"
    xcrun stapler validate "$APP_BUNDLE"
    xcrun stapler validate "$DMG_PATH"
    spctl --assess --type execute --verbose=4 "$APP_BUNDLE"
    spctl --assess --type open --context context:primary-signature --verbose=4 "$DMG_PATH"
fi

echo "Verified Curlman release: $ARCHITECTURES"
