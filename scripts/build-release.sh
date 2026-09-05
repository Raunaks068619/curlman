#!/bin/zsh
set -euo pipefail

PROJECT_ROOT="${0:A:h:h}"
OUTPUT_DIR="${CURLMAN_OUTPUT_DIR:-$PROJECT_ROOT/outputs}"
WORK_DIR="${CURLMAN_WORK_DIR:-$PROJECT_ROOT/work/release}"
APP_BUNDLE="$OUTPUT_DIR/Curlman.app"
DMG_PATH="$OUTPUT_DIR/Curlman.dmg"
CHECKSUM_PATH="$OUTPUT_DIR/Curlman.dmg.sha256"
MANIFEST_PATH="$OUTPUT_DIR/Curlman-build.json"
MANIFEST_PLIST="$WORK_DIR/Curlman-build.plist"
INFO_PLIST="$PROJECT_ROOT/Packaging/Info.plist"
ENTITLEMENTS="$PROJECT_ROOT/Packaging/Curlman.entitlements"
PRIVACY_MANIFEST="$PROJECT_ROOT/Packaging/PrivacyInfo.xcprivacy"
ICON_SOURCE="$PROJECT_ROOT/Brand/Curlman-Icon.icns"
SIGN_IDENTITY="${CURLMAN_SIGN_IDENTITY:--}"
NOTARIZE="${CURLMAN_NOTARIZE:-0}"

if [[ "$NOTARIZE" == "1" && "$SIGN_IDENTITY" == "-" ]]; then
    echo "CURLMAN_NOTARIZE=1 requires a Developer ID signing identity." >&2
    exit 1
fi

for required_file in "$INFO_PLIST" "$ENTITLEMENTS" "$PRIVACY_MANIFEST" "$ICON_SOURCE"; do
    if [[ ! -f "$required_file" ]]; then
        echo "Required release input is missing: $required_file" >&2
        exit 1
    fi
done

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST")"
GITHUB_STARS="${CURLMAN_GITHUB_STARS:-$(/usr/libexec/PlistBuddy -c 'Print :CurlmanGitHubStars' "$INFO_PLIST")}"

case "$GITHUB_STARS" in
    ''|*[!0-9]*)
        echo "CURLMAN_GITHUB_STARS must be a non-negative integer." >&2
        exit 1
        ;;
esac

rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR" "$OUTPUT_DIR"

build_architecture() {
    local architecture="$1"
    local scratch_path="$WORK_DIR/build-$architecture"
    swift build \
        --package-path "$PROJECT_ROOT" \
        --scratch-path "$scratch_path" \
        -c release \
        --arch "$architecture"
    swift build \
        --package-path "$PROJECT_ROOT" \
        --scratch-path "$scratch_path" \
        -c release \
        --arch "$architecture" \
        --show-bin-path
}

ARM64_BIN_DIR="$(build_architecture arm64 | tail -n 1)"
X86_64_BIN_DIR="$(build_architecture x86_64 | tail -n 1)"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"

lipo -create \
    "$ARM64_BIN_DIR/CurlmanNative" \
    "$X86_64_BIN_DIR/CurlmanNative" \
    -output "$APP_BUNDLE/Contents/MacOS/CurlmanNative"

cp "$INFO_PLIST" "$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CurlmanGitHubStars $GITHUB_STARS" "$APP_BUNDLE/Contents/Info.plist"
cp "$ICON_SOURCE" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
cp "$PRIVACY_MANIFEST" "$APP_BUNDLE/Contents/Resources/PrivacyInfo.xcprivacy"
chmod 755 "$APP_BUNDLE/Contents/MacOS/CurlmanNative"

if [[ "$SIGN_IDENTITY" == "-" ]]; then
    codesign \
        --force \
        --options runtime \
        --timestamp=none \
        --entitlements "$ENTITLEMENTS" \
        --sign - \
        "$APP_BUNDLE"
else
    codesign \
        --force \
        --options runtime \
        --timestamp \
        --entitlements "$ENTITLEMENTS" \
        --sign "$SIGN_IDENTITY" \
        "$APP_BUNDLE"
fi

codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

if [[ "$NOTARIZE" == "1" ]]; then
    "$PROJECT_ROOT/scripts/notarize-release.sh" "$APP_BUNDLE"
fi

DMG_STAGE="$(mktemp -d "$WORK_DIR/dmg-stage.XXXXXX")"
cleanup() {
    rm -rf "$DMG_STAGE"
}
trap cleanup EXIT

ditto "$APP_BUNDLE" "$DMG_STAGE/Curlman.app"
ln -s /Applications "$DMG_STAGE/Applications"

rm -f "$DMG_PATH" "$CHECKSUM_PATH" "$MANIFEST_PATH"
STAGE_KB="$(du -sk "$DMG_STAGE" | awk '{print $1}')"
DMG_SIZE_MB="$(( (STAGE_KB + 1023) / 1024 + 20 ))"

hdiutil create \
    -size "${DMG_SIZE_MB}m" \
    -fs HFS+ \
    -volname "Curlman" \
    -srcfolder "$DMG_STAGE" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

if [[ "$SIGN_IDENTITY" != "-" ]]; then
    codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG_PATH"
fi

if [[ "$NOTARIZE" == "1" ]]; then
    "$PROJECT_ROOT/scripts/notarize-release.sh" "$DMG_PATH"
fi

(cd "$OUTPUT_DIR" && shasum -a 256 Curlman.dmg > "${CHECKSUM_PATH:t}")
DMG_SHA256="$(awk '{print $1}' "$CHECKSUM_PATH")"
DMG_BYTES="$(stat -f '%z' "$DMG_PATH")"

plutil -create xml1 "$MANIFEST_PLIST"
plutil -insert product -string "Curlman" "$MANIFEST_PLIST"
plutil -insert version -string "$VERSION" "$MANIFEST_PLIST"
plutil -insert build -string "$BUILD_NUMBER" "$MANIFEST_PLIST"
plutil -insert architectures -json '["arm64","x86_64"]' "$MANIFEST_PLIST"
plutil -insert signingIdentity -string "$SIGN_IDENTITY" "$MANIFEST_PLIST"
plutil -insert githubStars -integer "$GITHUB_STARS" "$MANIFEST_PLIST"
if [[ "$NOTARIZE" == "1" ]]; then
    plutil -insert notarized -bool YES "$MANIFEST_PLIST"
else
    plutil -insert notarized -bool NO "$MANIFEST_PLIST"
fi
plutil -insert dmg -dictionary "$MANIFEST_PLIST"
plutil -insert dmg.file -string "Curlman.dmg" "$MANIFEST_PLIST"
plutil -insert dmg.bytes -integer "$DMG_BYTES" "$MANIFEST_PLIST"
plutil -insert dmg.sha256 -string "$DMG_SHA256" "$MANIFEST_PLIST"
plutil -insert createdAt -string "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$MANIFEST_PLIST"
plutil -convert json -o "$MANIFEST_PATH" "$MANIFEST_PLIST"

CURLMAN_REQUIRE_NOTARIZATION="$NOTARIZE" \
    "$PROJECT_ROOT/scripts/verify-native-release.sh" "$APP_BUNDLE" "$DMG_PATH"

echo "App: $APP_BUNDLE"
echo "DMG: $DMG_PATH"
echo "Checksum: $CHECKSUM_PATH"
echo "Manifest: $MANIFEST_PATH"
