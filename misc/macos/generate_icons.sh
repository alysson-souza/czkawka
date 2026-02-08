#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INPUT_SVG="${1:-$SCRIPT_DIR/../../data/icons/io.github.qarmin.czkawka.krokiet.svg}"
OUTPUT_ICNS="${2:-$SCRIPT_DIR/krokiet.icns}"
ICONSET_DIR="$SCRIPT_DIR/Krokiet.iconset"

if [[ ! -f "$INPUT_SVG" ]]; then
    echo "Error: Input SVG file not found: $INPUT_SVG"
    exit 1
fi

echo "Generating macOS app icon..."
echo "Input: $INPUT_SVG"
echo "Output: $OUTPUT_ICNS"

mkdir -p "$ICONSET_DIR"

if command -v rsvg-convert &> /dev/null; then
    echo "Using rsvg-convert for SVG rendering..."
    
    rsvg-convert -w 16 -h 16 "$INPUT_SVG" -o "$ICONSET_DIR/icon_16x16.png"
    rsvg-convert -w 32 -h 32 "$INPUT_SVG" -o "$ICONSET_DIR/icon_32x32.png"
    rsvg-convert -w 64 -h 64 "$INPUT_SVG" -o "$ICONSET_DIR/icon_64x64.png"
    rsvg-convert -w 128 -h 128 "$INPUT_SVG" -o "$ICONSET_DIR/icon_128x128.png"
    rsvg-convert -w 256 -h 256 "$INPUT_SVG" -o "$ICONSET_DIR/icon_256x256.png"
    rsvg-convert -w 512 -h 512 "$INPUT_SVG" -o "$ICONSET_DIR/icon_512x512.png"
    rsvg-convert -w 1024 -h 1024 "$INPUT_SVG" -o "$ICONSET_DIR/icon_1024x1024.png"
    
elif command -v magick &> /dev/null; then
    echo "Using ImageMagick (magick) for SVG rendering..."
    
    magick "$INPUT_SVG" -resize 16x16 "$ICONSET_DIR/icon_16x16.png"
    magick "$INPUT_SVG" -resize 32x32 "$ICONSET_DIR/icon_32x32.png"
    magick "$INPUT_SVG" -resize 64x64 "$ICONSET_DIR/icon_64x64.png"
    magick "$INPUT_SVG" -resize 128x128 "$ICONSET_DIR/icon_128x128.png"
    magick "$INPUT_SVG" -resize 256x256 "$ICONSET_DIR/icon_256x256.png"
    magick "$INPUT_SVG" -resize 512x512 "$ICONSET_DIR/icon_512x512.png"
    magick "$INPUT_SVG" -resize 1024x1024 "$ICONSET_DIR/icon_1024x1024.png"
    
elif command -v convert &> /dev/null; then
    echo "Using ImageMagick (convert) for SVG rendering..."
    
    convert "$INPUT_SVG" -resize 16x16 "$ICONSET_DIR/icon_16x16.png"
    convert "$INPUT_SVG" -resize 32x32 "$ICONSET_DIR/icon_32x32.png"
    convert "$INPUT_SVG" -resize 64x64 "$ICONSET_DIR/icon_64x64.png"
    convert "$INPUT_SVG" -resize 128x128 "$ICONSET_DIR/icon_128x128.png"
    convert "$INPUT_SVG" -resize 256x256 "$ICONSET_DIR/icon_256x256.png"
    convert "$INPUT_SVG" -resize 512x512 "$ICONSET_DIR/icon_512x512.png"
    convert "$INPUT_SVG" -resize 1024x1024 "$ICONSET_DIR/icon_1024x1024.png"
    
else
    echo "Error: No SVG converter found!"
    echo "Please install one of them:"
    echo "  brew install librsvg"
    echo "  brew install imagemagick"
    exit 1
fi

# Create retina (@2x) variants by copying larger sizes
cp "$ICONSET_DIR/icon_32x32.png" "$ICONSET_DIR/icon_16x16@2x.png"
cp "$ICONSET_DIR/icon_64x64.png" "$ICONSET_DIR/icon_32x32@2x.png"
cp "$ICONSET_DIR/icon_256x256.png" "$ICONSET_DIR/icon_128x128@2x.png"
cp "$ICONSET_DIR/icon_512x512.png" "$ICONSET_DIR/icon_256x256@2x.png"
cp "$ICONSET_DIR/icon_1024x1024.png" "$ICONSET_DIR/icon_512x512@2x.png"

iconutil -c icns "$ICONSET_DIR" -o "$OUTPUT_ICNS"

rm -rf "$ICONSET_DIR"

echo "Successfully created: $OUTPUT_ICNS"
