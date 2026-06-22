#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INPUT_SVG="${1:-$SCRIPT_DIR/../../krokiet/icons/krokiet_logo.svg}"
OUTPUT_ICNS="${2:-$SCRIPT_DIR/krokiet.icns}"

if [[ ! -f "$INPUT_SVG" ]]; then
    echo "Error: Input SVG file not found: $INPUT_SVG"
    exit 1
fi

STAGING_DIR=$(mktemp -d)
trap 'rm -rf "$STAGING_DIR"' EXIT

echo "Generating macOS app icon..."
echo "Input: $INPUT_SVG"
echo "Output: $OUTPUT_ICNS"

PNG_ICON="$STAGING_DIR/krokiet.png"
TIFF_ICON="$STAGING_DIR/krokiet.tiff"

if command -v rsvg-convert &> /dev/null; then
    rsvg-convert -w 1024 -h 1024 "$INPUT_SVG" -o "$PNG_ICON"
elif command -v magick &> /dev/null; then
    magick "$INPUT_SVG" -resize 1024x1024 "PNG32:$PNG_ICON"
elif command -v convert &> /dev/null; then
    convert "$INPUT_SVG" -resize 1024x1024 "PNG32:$PNG_ICON"
else
    echo "Error: No SVG converter found!"
    echo "Please install one of:"
    echo "  brew install librsvg"
    echo "  brew install imagemagick"
    exit 1
fi

if ! command -v sips &> /dev/null; then
    echo "Error: sips not found"
    exit 1
fi

if ! command -v tiff2icns &> /dev/null; then
    echo "Error: tiff2icns not found"
    exit 1
fi

sips -s format tiff "$PNG_ICON" --out "$TIFF_ICON" > /dev/null
tiff2icns "$TIFF_ICON" "$OUTPUT_ICNS"

if [[ ! -f "$OUTPUT_ICNS" ]]; then
    echo "Error: Failed to create icon: $OUTPUT_ICNS"
    exit 1
fi

echo "Successfully created: $OUTPUT_ICNS"
