#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INPUT_SVG="${1:-$SCRIPT_DIR/../../krokiet/icons/krokiet_logo.svg}"
OUTPUT_ICNS="${2:-$SCRIPT_DIR/krokiet.icns}"
ICONSET_DIR="$SCRIPT_DIR/Krokiet.iconset"

if [[ ! -f "$INPUT_SVG" ]]; then
    echo "Error: Input SVG file not found: $INPUT_SVG"
    exit 1
fi

STAGING_DIR=$(mktemp -d)
trap 'rm -rf "$STAGING_DIR" "$ICONSET_DIR"' EXIT

echo "Generating macOS app icon..."
echo "Input: $INPUT_SVG"
echo "Output: $OUTPUT_ICNS"

render_png() {
    local size="$1"
    local out="$STAGING_DIR/${size}.png"
    if command -v rsvg-convert &> /dev/null; then
        rsvg-convert -w "$size" -h "$size" "$INPUT_SVG" -o "$out"
    elif command -v magick &> /dev/null; then
        magick "$INPUT_SVG" -resize "${size}x${size}" "$out"
    elif command -v convert &> /dev/null; then
        convert "$INPUT_SVG" -resize "${size}x${size}" "$out"
    else
        echo "Error: No SVG converter found!"
        echo "Please install one of:"
        echo "  brew install librsvg"
        echo "  brew install imagemagick"
        exit 1
    fi
}

render_png 16
render_png 32
render_png 64
render_png 128
render_png 256
render_png 512
render_png 1024

# Assemble iconset with the 10 filenames that iconutil accepts
mkdir -p "$ICONSET_DIR"
cp "$STAGING_DIR/16.png"   "$ICONSET_DIR/icon_16x16.png"
cp "$STAGING_DIR/32.png"   "$ICONSET_DIR/icon_16x16@2x.png"
cp "$STAGING_DIR/32.png"   "$ICONSET_DIR/icon_32x32.png"
cp "$STAGING_DIR/64.png"   "$ICONSET_DIR/icon_32x32@2x.png"
cp "$STAGING_DIR/128.png"  "$ICONSET_DIR/icon_128x128.png"
cp "$STAGING_DIR/256.png"  "$ICONSET_DIR/icon_128x128@2x.png"
cp "$STAGING_DIR/256.png"  "$ICONSET_DIR/icon_256x256.png"
cp "$STAGING_DIR/512.png"  "$ICONSET_DIR/icon_256x256@2x.png"
cp "$STAGING_DIR/512.png"  "$ICONSET_DIR/icon_512x512.png"
cp "$STAGING_DIR/1024.png" "$ICONSET_DIR/icon_512x512@2x.png"

iconutil -c icns "$ICONSET_DIR" -o "$OUTPUT_ICNS"

echo "Successfully created: $OUTPUT_ICNS"
