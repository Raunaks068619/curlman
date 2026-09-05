#!/bin/zsh
set -euo pipefail

if [[ "$#" -ne 1 ]]; then
    echo "Usage: $0 <Curlman.app|Curlman.dmg>" >&2
    exit 64
fi

TARGET="$1"
if [[ ! -e "$TARGET" ]]; then
    echo "Notarization target does not exist: $TARGET" >&2
    exit 1
fi

SUBMISSION="$TARGET"
TEMP_DIR=""
cleanup() {
    if [[ -n "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup EXIT

if [[ "$TARGET" == *.app ]]; then
    TEMP_DIR="$(mktemp -d)"
    SUBMISSION="$TEMP_DIR/Curlman.app.zip"
    ditto -c -k --keepParent "$TARGET" "$SUBMISSION"
fi

NOTARY_ARGUMENTS=()
if [[ -n "${CURLMAN_NOTARY_PROFILE:-}" ]]; then
    NOTARY_ARGUMENTS+=(--keychain-profile "$CURLMAN_NOTARY_PROFILE")
elif [[ -n "${CURLMAN_NOTARY_KEY_PATH:-}" && -n "${CURLMAN_NOTARY_KEY_ID:-}" && -n "${CURLMAN_NOTARY_ISSUER_ID:-}" ]]; then
    NOTARY_ARGUMENTS+=(
        --key "$CURLMAN_NOTARY_KEY_PATH"
        --key-id "$CURLMAN_NOTARY_KEY_ID"
        --issuer "$CURLMAN_NOTARY_ISSUER_ID"
    )
else
    echo "Configure CURLMAN_NOTARY_PROFILE or the App Store Connect API key variables." >&2
    exit 1
fi

xcrun notarytool submit "$SUBMISSION" "${NOTARY_ARGUMENTS[@]}" --wait
xcrun stapler staple "$TARGET"
xcrun stapler validate "$TARGET"
