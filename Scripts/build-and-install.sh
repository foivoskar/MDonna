#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP="$ROOT/dist/MDonna.app"
TARGET="/Applications/MDonna.app"

"$ROOT/Scripts/build-app.sh"

osascript -e 'tell application "MDonna" to quit' >/dev/null 2>&1 || true
sleep 1

echo
echo "Installing local MDonna build..."

if [ -w "/Applications" ]; then
    rm -rf "$TARGET"
    ditto "$APP" "$TARGET"
else
    sudo rm -rf "$TARGET"
    sudo ditto "$APP" "$TARGET"
fi

codesign --verify --deep --strict "$TARGET"

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

if [ -x "$LSREGISTER" ]; then
    "$LSREGISTER" -f "$TARGET" >/dev/null 2>&1 || true
fi

touch "$TARGET"
open "$TARGET"

echo
echo "Installed:"
echo "  $TARGET"
echo
