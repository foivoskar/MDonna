#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

source "$ROOT/Scripts/version.sh"

ARCH="$(uname -m)"
WORK="$ROOT/.build/local-dmg"
STAGING="$WORK/staging"
APP="$ROOT/dist/MDonna.app"
DMG="$ROOT/dist/MDonna-${MDONNA_VERSION}-macOS-${ARCH}.dmg"
VOLUME="MDonna ${MDONNA_VERSION}"

if [ "$(uname -s)" != "Darwin" ]; then
    echo "ERROR: Local DMG creation requires macOS."
    exit 1
fi

for TOOL in hdiutil shasum; do
    if ! command -v "$TOOL" >/dev/null 2>&1; then
        echo "ERROR: Required tool not found:"
        echo "  $TOOL"
        exit 1
    fi
done

"$ROOT/Scripts/build-app.sh"

rm -rf "$WORK"
mkdir -p "$STAGING"

ditto "$APP" "$STAGING/MDonna.app"
ln -s /Applications "$STAGING/Applications"

rm -f "$DMG"

echo
echo "Creating local installer..."

hdiutil create \
    -volname "$VOLUME" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDZO \
    "$DMG"

hdiutil verify "$DMG"

SHA256="$(shasum -a 256 "$DMG" | awk '{print $1}')"

echo
echo "============================================================"
echo "  MDONNA LOCAL INSTALLER COMPLETE"
echo "============================================================"
echo
echo "DMG:"
echo "  $DMG"
echo
echo "SHA-256:"
echo "  $SHA256"
echo
echo "The application was compiled and signed locally."
echo "No Developer ID or Apple notarization was used."
echo

open "$DMG"
