#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="MDonna"
ICON_SOURCE="$ROOT/Assets/MDonnaIcon.png"
ICONSET="$ROOT/.build/MDonna.iconset"
ICNS="$ROOT/.build/MDonnaIcon.icns"
INSTALL_PATH="/Applications/$APP_NAME.app"

echo
echo "========================================"
echo "  MDonna — Build & Install"
echo "========================================"
echo

# ------------------------------------------------------------
# 1. Check required files
# ------------------------------------------------------------

if [ ! -f "$ICON_SOURCE" ]; then
    echo "ERROR: Icon not found:"
    echo "  $ICON_SOURCE"
    exit 1
fi

if [ ! -x "$ROOT/Scripts/build-app.sh" ]; then
    chmod +x "$ROOT/Scripts/build-app.sh"
fi

# ------------------------------------------------------------
# 2. Build the application using the existing build system
# ------------------------------------------------------------

echo "▶ Building MDonna..."
"$ROOT/Scripts/build-app.sh"

echo
echo "✓ Application build completed."

# ------------------------------------------------------------
# 3. Locate the newly built .app
# ------------------------------------------------------------

APP=""

if [ -d "$ROOT/dist/MDonna.app" ]; then
    APP="$ROOT/dist/MDonna.app"
else
    APP="$(find "$ROOT/dist" "$ROOT/.build" \
        -type d \
        -name "MDonna.app" \
        -print 2>/dev/null \
        | head -n 1 || true)"
fi

if [ -z "$APP" ] || [ ! -d "$APP" ]; then
    echo
    echo "ERROR: Could not find the newly built MDonna.app"
    exit 1
fi

echo "✓ Built application:"
echo "  $APP"

# ------------------------------------------------------------
# 4. Create a proper macOS .icns from Assets/MDonnaIcon.png
# ------------------------------------------------------------

echo
echo "▶ Creating macOS icon..."

rm -rf "$ICONSET"
mkdir -p "$ICONSET"
mkdir -p "$(dirname "$ICNS")"

sips -z 16   16   "$ICON_SOURCE" --out "$ICONSET/icon_16x16.png"      >/dev/null
sips -z 32   32   "$ICON_SOURCE" --out "$ICONSET/icon_16x16@2x.png"   >/dev/null
sips -z 32   32   "$ICON_SOURCE" --out "$ICONSET/icon_32x32.png"      >/dev/null
sips -z 64   64   "$ICON_SOURCE" --out "$ICONSET/icon_32x32@2x.png"   >/dev/null
sips -z 128  128  "$ICON_SOURCE" --out "$ICONSET/icon_128x128.png"    >/dev/null
sips -z 256  256  "$ICON_SOURCE" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256  256  "$ICON_SOURCE" --out "$ICONSET/icon_256x256.png"    >/dev/null
sips -z 512  512  "$ICON_SOURCE" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512  512  "$ICON_SOURCE" --out "$ICONSET/icon_512x512.png"    >/dev/null
sips -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET/icon_512x512@2x.png" >/dev/null

rm -f "$ICNS"
iconutil -c icns "$ICONSET" -o "$ICNS"

echo "✓ Icon created."

# ------------------------------------------------------------
# 5. Put icon inside application bundle
# ------------------------------------------------------------

RESOURCES="$APP/Contents/Resources"
PLIST="$APP/Contents/Info.plist"

mkdir -p "$RESOURCES"

cp "$ICNS" "$RESOURCES/MDonnaIcon.icns"

if [ ! -f "$PLIST" ]; then
    echo "ERROR: Info.plist not found inside app."
    exit 1
fi

/usr/libexec/PlistBuddy \
    -c "Delete :CFBundleIconFile" \
    "$PLIST" >/dev/null 2>&1 || true

/usr/libexec/PlistBuddy \
    -c "Add :CFBundleIconFile string MDonnaIcon.icns" \
    "$PLIST"

echo "✓ New icon installed in bundle."

# ------------------------------------------------------------
# 6. Ad-hoc sign after modifying the application bundle
# ------------------------------------------------------------

echo
echo "▶ Signing application..."

codesign \
    --force \
    --deep \
    --sign - \
    "$APP"

echo "✓ Application signed."

# ------------------------------------------------------------
# 7. Close old running version
# ------------------------------------------------------------

osascript -e 'tell application "MDonna" to quit' >/dev/null 2>&1 || true
sleep 1

# ------------------------------------------------------------
# 8. Replace previous /Applications version
# ------------------------------------------------------------

echo
echo "▶ Installing into /Applications..."

if [ -d "$INSTALL_PATH" ]; then
    rm -rf "$INSTALL_PATH"
fi

ditto "$APP" "$INSTALL_PATH"

echo "✓ Installed:"
echo "  $INSTALL_PATH"

# ------------------------------------------------------------
# 9. Refresh Finder/Dock icon caches
# ------------------------------------------------------------

touch "$INSTALL_PATH"
killall Finder >/dev/null 2>&1 || true
killall Dock   >/dev/null 2>&1 || true

# ------------------------------------------------------------
# 10. Verify and launch
# ------------------------------------------------------------

echo
echo "▶ Verifying signature..."

codesign --verify --deep --strict "$INSTALL_PATH"

echo
echo "▶ Launching MDonna..."

open "$INSTALL_PATH"

echo
echo "========================================"
echo "  ✓ MDonna successfully installed"
echo "========================================"
echo
echo "Future builds:"
echo
echo "  ./Scripts/build-and-install.sh"
echo
