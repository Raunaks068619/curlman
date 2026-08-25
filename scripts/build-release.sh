#!/bin/zsh
set -euo pipefail

PROJECT_ROOT="${0:A:h:h}"
OUTPUT_DIR="$PROJECT_ROOT/outputs"
APP_BUNDLE="$OUTPUT_DIR/Curlman.app"
DMG_PATH="$OUTPUT_DIR/Curlman.dmg"
ICON_SOURCE="$PROJECT_ROOT/Brand/Curlman-Icon.png"
ICONSET_DIR="$PROJECT_ROOT/work/AppIcon.iconset"

cd "$PROJECT_ROOT"
swift build -c release --arch arm64
BIN_DIR="$(swift build -c release --show-bin-path)"

if [[ -e "$APP_BUNDLE" ]]; then
    rm -rf "$APP_BUNDLE"
fi

mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources" "$OUTPUT_DIR" "$PROJECT_ROOT/work"
cp "$BIN_DIR/CurlmanNative" "$APP_BUNDLE/Contents/MacOS/CurlmanNative"
cp "$PROJECT_ROOT/Packaging/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"
sips -z 16 16 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
sips -z 64 64 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null
iconutil -c icns "$ICONSET_DIR" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET_DIR"

chmod 755 "$APP_BUNDLE/Contents/MacOS/CurlmanNative"

codesign --force --deep --sign - "$APP_BUNDLE"

DMG_STAGE="$(mktemp -d "$PROJECT_ROOT/work/curlman-dmg.XXXXXX")"
ditto "$APP_BUNDLE" "$DMG_STAGE/Curlman.app"
ln -s /Applications "$DMG_STAGE/Applications"

if [[ -e "$DMG_PATH" ]]; then
    rm -f "$DMG_PATH"
fi

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

rm -rf "$DMG_STAGE"
echo "$APP_BUNDLE"
echo "$DMG_PATH"
