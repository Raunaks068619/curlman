#!/bin/zsh
set -euo pipefail

PROJECT_ROOT="${0:A:h:h}"
OUTPUT_DIR="$PROJECT_ROOT/outputs"
APP_BUNDLE="$OUTPUT_DIR/API Panel.app"
DMG_PATH="$OUTPUT_DIR/API-Panel.dmg"

cd "$PROJECT_ROOT"
swift build -c release --arch arm64
BIN_DIR="$(swift build -c release --show-bin-path)"

if [[ -e "$APP_BUNDLE" ]]; then
    rm -rf "$APP_BUNDLE"
fi

mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources" "$OUTPUT_DIR" "$PROJECT_ROOT/work"
cp "$BIN_DIR/APIPanel" "$APP_BUNDLE/Contents/MacOS/APIPanel"
cp "$PROJECT_ROOT/Packaging/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
chmod 755 "$APP_BUNDLE/Contents/MacOS/APIPanel"

codesign --force --deep --sign - "$APP_BUNDLE"

DMG_STAGE="$(mktemp -d "$PROJECT_ROOT/work/api-panel-dmg.XXXXXX")"
ditto "$APP_BUNDLE" "$DMG_STAGE/API Panel.app"
ln -s /Applications "$DMG_STAGE/Applications"

if [[ -e "$DMG_PATH" ]]; then
    rm -f "$DMG_PATH"
fi

hdiutil create \
    -volname "API Panel" \
    -srcfolder "$DMG_STAGE" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

rm -rf "$DMG_STAGE"
echo "$APP_BUNDLE"
echo "$DMG_PATH"

