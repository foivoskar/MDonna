#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="$(
    cd "$(dirname "$0")" &&
    pwd
)"

ARCHIVE="$SCRIPT_DIR/MDonna.zip"
TARGET="/Applications/MDonna.app"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/mdonna-install.XXXXXX")"

trap 'rm -rf "$TEMP_DIR"' EXIT

echo
echo "=== MDonna Installer ==="
echo

if [ ! -f "$ARCHIVE" ]; then
    echo "ERROR: MDonna.zip not found."
    exit 1
fi

echo "Extracting..."

ditto \
    -x \
    -k \
    "$ARCHIVE" \
    "$TEMP_DIR"

SOURCE="$TEMP_DIR/MDonna.app"

if [ ! -d "$SOURCE" ]; then
    echo "ERROR: MDonna.app not found in archive."
    exit 1
fi

echo "Verifying..."

codesign \
    --verify \
    --deep \
    --strict \
    "$SOURCE"

echo "Closing existing MDonna..."

killall MDonna 2>/dev/null || true

echo "Installing in /Applications..."

if [ -w "/Applications" ]; then

    rm -rf "$TARGET"

    ditto \
        "$SOURCE" \
        "$TARGET"

else

    sudo rm -rf "$TARGET"

    sudo ditto \
        "$SOURCE" \
        "$TARGET"
fi

xattr \
    -dr \
    com.apple.quarantine \
    "$TARGET" \
    2>/dev/null || true

touch "$TARGET"

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

"$LSREGISTER" \
    -f \
    "$TARGET"

echo
echo "MDonna installed successfully:"
echo "$TARGET"
echo

open "$TARGET"
