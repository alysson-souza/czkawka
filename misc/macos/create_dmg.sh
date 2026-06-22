#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BINARY_PATH="${1:-target/release/krokiet}"
OUTPUT_DMG="${2:-mac_krokiet_arm64.dmg}"
DISPLAY_NAME="Krokiet"
BUNDLE_ID="io.github.qarmin.czkawka.krokiet"
BUNDLE_DIR_NAME="Krokiet"
VERSION=$(grep "^version" "$SCRIPT_DIR/../../krokiet/Cargo.toml" | head -1 | cut -d'"' -f2)
EXECUTABLE_NAME="krokiet"
REAL_EXECUTABLE_NAME="krokiet-bin"

echo "Creating macOS DMG..."
echo "Binary: $BINARY_PATH"
echo "Output: $OUTPUT_DMG"
echo "Version: $VERSION"
echo "App bundle: $BUNDLE_DIR_NAME.app"
echo "Volume name: $BUNDLE_DIR_NAME"

if [[ ! -f "$BINARY_PATH" ]]; then
    echo "Error: Binary not found at $BINARY_PATH"
    exit 1
fi

TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT
DMG_ROOT="$TEMP_DIR/dmg-root"
APP_BUNDLE="$DMG_ROOT/$BUNDLE_DIR_NAME.app"
MACOS_DIR="$APP_BUNDLE/Contents/MacOS"
FRAMEWORKS_DIR="$APP_BUNDLE/Contents/Frameworks"
ICON_PATH="$TEMP_DIR/krokiet.icns"

echo "Creating app bundle..."

mkdir -p "$MACOS_DIR"
mkdir -p "$APP_BUNDLE/Contents/Resources"
mkdir -p "$FRAMEWORKS_DIR"

APP_EXECUTABLE="$MACOS_DIR/$REAL_EXECUTABLE_NAME"
cp "$BINARY_PATH" "$APP_EXECUTABLE"
chmod +x "$APP_EXECUTABLE"
codesign --remove-signature "$APP_EXECUTABLE" 2> /dev/null || true

cat > "$MACOS_DIR/$EXECUTABLE_NAME" <<'EOF'
#!/bin/sh
APP_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
export PATH="$APP_DIR:$PATH"
exec "$APP_DIR/krokiet-bin" "$@"
EOF
chmod +x "$MACOS_DIR/$EXECUTABLE_NAME"

sed \
  -e "s|VERSION_PLACEHOLDER|$VERSION|g" \
  -e "s|BUNDLE_ID_PLACEHOLDER|$BUNDLE_ID|g" \
  -e "s|BUNDLE_NAME_PLACEHOLDER|$DISPLAY_NAME|g" \
  "$SCRIPT_DIR/Info.plist" > "$APP_BUNDLE/Contents/Info.plist"

echo "Generating icon..."
bash "$SCRIPT_DIR/generate_icons.sh" "$SCRIPT_DIR/../../krokiet/icons/krokiet_logo.svg" "$ICON_PATH"
cp "$ICON_PATH" "$APP_BUNDLE/Contents/Resources/krokiet.icns"

is_system_library() {
    case "$1" in
        /System/Library/*|/usr/lib/*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

is_macho_file() {
    file "$1" | grep -q "Mach-O"
}

remove_signature_if_present() {
    local binary="$1"
    codesign --remove-signature "$binary" 2> /dev/null || true
}

dylib_reference_for_target() {
    local target="$1"
    local dylib_name="$2"
    case "$target" in
        "$MACOS_DIR"/*)
            printf '@executable_path/../Frameworks/%s\n' "$dylib_name"
            ;;
        *)
            printf '@loader_path/%s\n' "$dylib_name"
            ;;
    esac
}

source_hash() {
    local source_path="$1"
    printf '%s' "$(realpath "$source_path")" | shasum -a 256 | cut -c 1-12
}

bundled_dylib_path() {
    local source_path="$1"
    local dep_name="$2"
    local stem
    local suffix
    stem="${dep_name%.dylib}"
    suffix=$(source_hash "$source_path")
    printf '%s/%s-%s.dylib\n' "$FRAMEWORKS_DIR" "$stem" "$suffix"
}

external_dylibs_for_target() {
    local target="$1"
    otool -L "$target" | awk 'NR > 1 { print $1 }' | while IFS= read -r dep; do
        if [[ -z "$dep" || "$dep" == @* || "$dep" != /* ]] || is_system_library "$dep"; then
            continue
        fi
        printf '%s\n' "$dep"
    done
}

copy_dylib_if_needed() {
    local dep="$1"
    local source_path
    local dep_name
    local bundled_dep
    source_path=$(realpath "$dep")
    dep_name=$(basename "$dep")
    bundled_dep=$(bundled_dylib_path "$source_path" "$dep_name")

    if [[ -f "$bundled_dep" ]]; then
        return 1
    fi

    cp "$source_path" "$bundled_dep"
    chmod u+w "$bundled_dep"
    remove_signature_if_present "$bundled_dep"
    install_name_tool -id "@rpath/$(basename "$bundled_dep")" "$bundled_dep"
    return 0
}

bundle_external_dylibs() {
    local copied_any
    while true; do
        copied_any=0
        while IFS= read -r -d '' target; do
            if ! is_macho_file "$target"; then
                continue
            fi
            while IFS= read -r dep; do
                if copy_dylib_if_needed "$dep"; then
                    copied_any=1
                fi
            done < <(external_dylibs_for_target "$target")
        done < <(find "$MACOS_DIR" "$FRAMEWORKS_DIR" -type f -print0)

        if [[ "$copied_any" -eq 0 ]]; then
            break
        fi
    done
}

rewrite_external_dylibs() {
    while IFS= read -r -d '' target; do
        if ! is_macho_file "$target"; then
            continue
        fi
        while IFS= read -r dep; do
            local source_path
            local dep_name
            local bundled_dep
            local bundled_name
            local new_ref
            source_path=$(realpath "$dep")
            dep_name=$(basename "$dep")
            bundled_dep=$(bundled_dylib_path "$source_path" "$dep_name")
            bundled_name=$(basename "$bundled_dep")
            new_ref=$(dylib_reference_for_target "$target" "$bundled_name")
            install_name_tool -change "$dep" "$new_ref" "$target"
        done < <(external_dylibs_for_target "$target")
    done < <(find "$MACOS_DIR" "$FRAMEWORKS_DIR" -type f -print0)
}

copy_tool_with_dylibs() {
    local tool_name="$1"
    local source_path
    if ! source_path=$(command -v "$tool_name"); then
        echo "Error: required runtime tool not found: $tool_name"
        exit 1
    fi

    local target_path="$MACOS_DIR/$tool_name"
    cp "$source_path" "$target_path"
    chmod +x "$target_path"
    remove_signature_if_present "$target_path"
}

sign_macho_files() {
    while IFS= read -r -d '' binary; do
        if is_macho_file "$binary"; then
            codesign --force --sign - "$binary"
        fi
    done < <(find "$MACOS_DIR" "$FRAMEWORKS_DIR" -type f -print0)
}

verify_no_external_dylibs() {
    local failed=0
    while IFS= read -r binary; do
        if ! is_macho_file "$binary"; then
            continue
        fi

        if otool -L "$binary" | awk 'NR > 1 { print $1 }' | grep -E '^(/opt/homebrew|/usr/local|/opt/local)/' > /dev/null; then
            echo "Error: bundled binary still links to external Homebrew/MacPorts libraries: $binary"
            otool -L "$binary"
            failed=1
        fi
    done < <(find "$MACOS_DIR" "$FRAMEWORKS_DIR" -type f)

    if [[ "$failed" -ne 0 ]]; then
        exit 1
    fi
}

verify_signatures() {
    while IFS= read -r -d '' binary; do
        if is_macho_file "$binary"; then
            codesign --verify --strict "$binary"
        fi
    done < <(find "$MACOS_DIR" "$FRAMEWORKS_DIR" -type f -print0)

    codesign --verify --strict "$APP_BUNDLE"
}

echo "Bundling runtime dependencies..."
copy_tool_with_dylibs ffmpeg
copy_tool_with_dylibs ffprobe
bundle_external_dylibs
rewrite_external_dylibs
verify_no_external_dylibs

echo "Signing bundled Mach-O files (ad-hoc)..."
sign_macho_files

echo "Signing app bundle (ad-hoc)..."
codesign --force --sign - "$APP_BUNDLE"
verify_signatures

ln -s /Applications "$DMG_ROOT/Applications"

APP_SIZE=$(du -sm "$DMG_ROOT" | cut -f1)
DMG_SIZE=$((APP_SIZE + 20))

echo "Creating DMG (${DMG_SIZE}MB)..."
hdiutil create -ov -size "${DMG_SIZE}m" -volname "$BUNDLE_DIR_NAME" -srcfolder "$DMG_ROOT" -fs HFS+ -format UDZO "$OUTPUT_DMG"

echo "Successfully created: $OUTPUT_DMG"
ls -lh "$OUTPUT_DMG"
