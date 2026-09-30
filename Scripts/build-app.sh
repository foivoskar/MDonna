#!/bin/bash

set -euo pipefail

PROJECT_DIR="$(
    cd "$(dirname "$0")/.." &&
    pwd
)"

cd "$PROJECT_DIR"

APP_NAME="MDonna"
BUNDLE_ID="org.mdonna.editor"

INSTALL_APP="/Applications/MDonna.app"
STAGING_APP="$PROJECT_DIR/.build/MDonna-Packaged.app"

ICON_SOURCE="$PROJECT_DIR/Assets/MDonnaIcon.png"
ICONSET_DIR="$PROJECT_DIR/.build/MDonna.iconset"
ICON_ICNS="$PROJECT_DIR/.build/MDonna.icns"


echo
echo "=== Building MDonna Release ==="

swift build -c release

BIN_DIR="$(
    swift build \
        -c release \
        --show-bin-path
)"

EXECUTABLE="$BIN_DIR/$APP_NAME"
RESOURCE_BUNDLE="$BIN_DIR/MDonna_MDonna.bundle"


test -f "$EXECUTABLE"

if [ ! -d "$RESOURCE_BUNDLE" ]; then
    echo "ERROR: SwiftPM resource bundle not found:"
    echo "$RESOURCE_BUNDLE"
    exit 1
fi


echo
echo "=== Creating application icon ==="

test -f "$ICON_SOURCE"

rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

sips -z 16 16 \
    "$ICON_SOURCE" \
    --out "$ICONSET_DIR/icon_16x16.png" \
    >/dev/null

sips -z 32 32 \
    "$ICON_SOURCE" \
    --out "$ICONSET_DIR/icon_16x16@2x.png" \
    >/dev/null

sips -z 32 32 \
    "$ICON_SOURCE" \
    --out "$ICONSET_DIR/icon_32x32.png" \
    >/dev/null

sips -z 64 64 \
    "$ICON_SOURCE" \
    --out "$ICONSET_DIR/icon_32x32@2x.png" \
    >/dev/null

sips -z 128 128 \
    "$ICON_SOURCE" \
    --out "$ICONSET_DIR/icon_128x128.png" \
    >/dev/null

sips -z 256 256 \
    "$ICON_SOURCE" \
    --out "$ICONSET_DIR/icon_128x128@2x.png" \
    >/dev/null

sips -z 256 256 \
    "$ICON_SOURCE" \
    --out "$ICONSET_DIR/icon_256x256.png" \
    >/dev/null

sips -z 512 512 \
    "$ICON_SOURCE" \
    --out "$ICONSET_DIR/icon_256x256@2x.png" \
    >/dev/null

sips -z 512 512 \
    "$ICON_SOURCE" \
    --out "$ICONSET_DIR/icon_512x512.png" \
    >/dev/null

sips -z 1024 1024 \
    "$ICON_SOURCE" \
    --out "$ICONSET_DIR/icon_512x512@2x.png" \
    >/dev/null

rm -f "$ICON_ICNS"

iconutil \
    -c icns \
    "$ICONSET_DIR" \
    -o "$ICON_ICNS"

echo "✓ MDonna.icns generated"


echo
echo "=== Creating application bundle ==="

rm -rf "$STAGING_APP"

mkdir -p "$STAGING_APP/Contents/MacOS"
mkdir -p "$STAGING_APP/Contents/Resources"


echo
echo "=== Copying executable ==="

cp "$EXECUTABLE" \
   "$STAGING_APP/Contents/MacOS/MDonna"

chmod +x \
    "$STAGING_APP/Contents/MacOS/MDonna"


echo
echo "=== Copying WebEditor resources ==="

if [ -d "$RESOURCE_BUNDLE/Contents/Resources" ]; then

    cp -R \
        "$RESOURCE_BUNDLE/Contents/Resources/." \
        "$STAGING_APP/Contents/Resources/"

else

    cp -R \
        "$RESOURCE_BUNDLE/." \
        "$STAGING_APP/Contents/Resources/"
fi


echo
echo "=== Copying application icon ==="

cp "$ICON_ICNS" \
   "$STAGING_APP/Contents/Resources/MDonna.icns"


echo
echo "=== Writing Info.plist ==="

cat > "$STAGING_APP/Contents/Info.plist" <<PLIST
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

    <key>CFBundleIconFile</key>
    <string>MDonna.icns</string>

    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>

    <key>NSHighResolutionCapable</key>
    <true/>

    <key>NSPrincipalClass</key>
    <string>NSApplication</string>

    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>

            <key>CFBundleTypeName</key>
            <string>Markdown Document</string>

            <key>CFBundleTypeRole</key>
            <string>Editor</string>

            <key>LSHandlerRank</key>
            <string>Alternate</string>

            <key>CFBundleTypeExtensions</key>
            <array>
                <string>md</string>
                <string>markdown</string>
            </array>

            <key>LSItemContentTypes</key>
            <array>
                <string>net.daringfireball.markdown</string>
            </array>

        </dict>
    </array>

</dict>
</plist>
PLIST


echo
echo "=== Checking Info.plist ==="

plutil -lint \
    "$STAGING_APP/Contents/Info.plist"


echo
echo "=== Signing application ==="

codesign \
    --force \
    --deep \
    --sign - \
    "$STAGING_APP"


echo
echo "=== Verifying signature ==="

codesign \
    --verify \
    --deep \
    --strict \
    "$STAGING_APP"


echo
echo "=== Installing into /Applications ==="

killall MDonna 2>/dev/null || true

rm -rf "$INSTALL_APP"

ditto \
    "$STAGING_APP" \
    "$INSTALL_APP"

touch "$INSTALL_APP"


echo
echo "=== Registering MDonna ==="

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

"$LSREGISTER" \
    -f \
    "$INSTALL_APP"


echo
echo "=========================================="
echo " MDonna installed successfully"
echo "=========================================="
echo
echo "$INSTALL_APP"
