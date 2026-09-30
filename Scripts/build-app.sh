#!/bin/bash

set -euo pipefail

PROJECT_DIR="$(
    cd "$(dirname "$0")/.." &&
    pwd
)"

cd "$PROJECT_DIR"

APP_NAME="MDonna"
BUNDLE_ID="org.mdonna.editor"

DIST_DIR="$PROJECT_DIR/dist"
APP="$DIST_DIR/$APP_NAME.app"

echo
echo "=== Building MDonna Release ==="

swift build -c release

BIN_DIR="$(
    swift build -c release --show-bin-path
)"

EXECUTABLE="$BIN_DIR/$APP_NAME"
RESOURCE_BUNDLE="$BIN_DIR/MDonna_MDonna.bundle"

if [ ! -f "$EXECUTABLE" ]; then
    echo "ERROR: Release executable not found:"
    echo "$EXECUTABLE"
    exit 1
fi

if [ ! -d "$RESOURCE_BUNDLE" ]; then
    echo "ERROR: SwiftPM resource bundle not found:"
    echo "$RESOURCE_BUNDLE"
    exit 1
fi


echo
echo "=== Creating MDonna.app ==="

rm -rf "$APP"

mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"


echo
echo "=== Copying executable ==="

cp "$EXECUTABLE" \
   "$APP/Contents/MacOS/$APP_NAME"

chmod +x \
   "$APP/Contents/MacOS/$APP_NAME"


echo
echo "=== Copying resources ==="

#
# A normal macOS application keeps its resources under
# Contents/Resources.
#
# SwiftPM creates:
#
#   MDonna_MDonna.bundle/Contents/Resources/...
#
# We copy the actual resource contents into the app's own
# Contents/Resources directory.
#

if [ -d "$RESOURCE_BUNDLE/Contents/Resources" ]; then

    cp -R \
        "$RESOURCE_BUNDLE/Contents/Resources/." \
        "$APP/Contents/Resources/"

else

    cp -R \
        "$RESOURCE_BUNDLE/." \
        "$APP/Contents/Resources/"
fi


echo "=== Writing Info.plist ==="

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">

<plist version="1.0">
<dict>

    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>

    <key>CFBundleDisplayName</key>
    <string>MDonna</string>

    <key>CFBundleExecutable</key>
    <string>MDonna</string>

    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>

    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>

    <key>CFBundleName</key>
    <string>MDonna</string>

    <key>CFBundlePackageType</key>
    <string>APPL</string>

    <key>CFBundleShortVersionString</key>
    <string>0.1</string>

    <key>CFBundleVersion</key>
    <string>1</string>

    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>

    <key>NSHighResolutionCapable</key>
    <true/>

    <key>NSPrincipalClass</key>
    <string>NSApplication</string>

</dict>
</plist>
PLIST


echo
echo "=== Checking Info.plist ==="

plutil -lint \
    "$APP/Contents/Info.plist"


echo
echo "=== Ad-hoc signing app ==="

codesign \
    --force \
    --deep \
    --sign - \
    "$APP"


echo
echo "=== Verifying signature ==="

codesign \
    --verify \
    --deep \
    --strict \
    "$APP"


echo
echo "=========================================="
echo " MDonna.app created successfully"
echo "=========================================="
echo
echo "$APP"
echo
