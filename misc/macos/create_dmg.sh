#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BINARY_PATH="${1:-target/release/krokiet}"
OUTPUT_DMG="${2:-mac_krokiet_universal.dmg}"
VARIANT_NAME="${3:-krokiet}"

DISPLAY_NAME="$(tr '[:lower:]' '[:upper:]' <<< "${VARIANT_NAME:0:1}")${VARIANT_NAME:1}"
VERSION=$(grep "^version" "$SCRIPT_DIR/../../krokiet/Cargo.toml" | head -1 | cut -d'"' -f2)

echo "Creating macOS DMG..."
echo "Binary: $BINARY_PATH"
echo "Output: $OUTPUT_DMG"
echo "Variant: $VARIANT_NAME"
echo "Version: $VERSION"

if [[ ! -f "$BINARY_PATH" ]]; then
    echo "Error: Binary not found at $BINARY_PATH"
    exit 1
fi

TEMP_DIR=$(mktemp -d)
APP_BUNDLE="$TEMP_DIR/$DISPLAY_NAME.app"

echo "Creating app bundle..."

mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BINARY_PATH" "$APP_BUNDLE/Contents/MacOS/krokiet"
chmod +x "$APP_BUNDLE/Contents/MacOS/krokiet"

sed "s/VERSION_PLACEHOLDER/$VERSION/g" "$SCRIPT_DIR/Info.plist" > "$APP_BUNDLE/Contents/Info.plist"

if [[ ! -f "$SCRIPT_DIR/krokiet.icns" ]]; then
    echo "Generating icon..."
    bash "$SCRIPT_DIR/generate_icons.sh"
fi
cp "$SCRIPT_DIR/krokiet.icns" "$APP_BUNDLE/Contents/Resources/krokiet.icns"

DMG_TEMP="$TEMP_DIR/temp.dmg"
MOUNT_POINT="$TEMP_DIR/mount"

APP_SIZE=$(du -sm "$APP_BUNDLE" | cut -f1)
DMG_SIZE=$((APP_SIZE + 20))

echo "Creating temporary DMG (${DMG_SIZE}MB)..."
hdiutil create -size "${DMG_SIZE}m" -volname "$DISPLAY_NAME" -srcfolder "$APP_BUNDLE" -fs HFS+ -format UDRW "$DMG_TEMP"

mkdir -p "$MOUNT_POINT"
hdiutil attach "$DMG_TEMP" -mountpoint "$MOUNT_POINT" -nobrowse

ln -s /Applications "$MOUNT_POINT/Applications"

echo "Finalizing DMG..."
hdiutil detach "$MOUNT_POINT" -force

hdiutil convert "$DMG_TEMP" -format UDZO -o "$OUTPUT_DMG"

rm -rf "$TEMP_DIR"

echo "Successfully created: $OUTPUT_DMG"
ls -lh "$OUTPUT_DMG"
