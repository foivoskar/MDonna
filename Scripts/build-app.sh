#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

source "$ROOT/Scripts/version.sh"

APP_NAME="MDonna"
BUNDLE_ID="org.mdonna.editor"
DIST="$ROOT/dist"
APP="$DIST/$APP_NAME.app"
ICON_SOURCE="$ROOT/Assets/MDonnaIcon.png"
ICON_WORK="$ROOT/.build/mdonna-icon"
ICONSET="$ICON_WORK/MDonnaIcon.iconset"
ICNS="$APP/Contents/Resources/MDonnaIcon.icns"

if [ "$(uname -s)" != "Darwin" ]; then
    echo "ERROR: The current native MDonna shell builds on macOS only."
    exit 1
fi

for TOOL in xcrun codesign iconutil sips plutil; do
    if ! command -v "$TOOL" >/dev/null 2>&1; then
        echo "ERROR: Required tool not found:"
        echo "  $TOOL"
        exit 1
    fi
done

SWIFT="$(xcrun --find swift 2>/dev/null || true)"

if [ -z "$SWIFT" ] || [ ! -x "$SWIFT" ]; then
    echo "ERROR: Apple Swift could not be found."
    exit 1
fi

if [ ! -f "$ICON_SOURCE" ]; then
    echo "ERROR: Icon source not found:"
    echo "  $ICON_SOURCE"
    exit 1
fi

"$ROOT/Scripts/build-web-editor.sh"

echo
echo "Building MDonna $MDONNA_VERSION..."

"$SWIFT" build -c release

BIN_DIR="$("$SWIFT" build -c release --show-bin-path)"
EXECUTABLE="$BIN_DIR/$APP_NAME"
RESOURCE_BUNDLE="$BIN_DIR/MDonna_MDonna.bundle"

if [ ! -f "$EXECUTABLE" ]; then
    echo "ERROR: Release executable was not produced."
    exit 1
fi

if [ ! -d "$RESOURCE_BUNDLE" ]; then
    echo "ERROR: SwiftPM resource bundle was not produced."
    exit 1
fi

rm -rf "$APP"

mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp "$EXECUTABLE" "$APP/Contents/MacOS/$APP_NAME"
chmod +x "$APP/Contents/MacOS/$APP_NAME"

if [ -d "$RESOURCE_BUNDLE/Contents/Resources" ]; then
    cp -R "$RESOURCE_BUNDLE/Contents/Resources/." "$APP/Contents/Resources/"
else
    cp -R "$RESOURCE_BUNDLE/." "$APP/Contents/Resources/"
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
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
    <string>${MDONNA_VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${MDONNA_BUILD_NUMBER}</string>
    <key>CFBundleIconFile</key>
    <string>MDonnaIcon.icns</string>
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
            <string>Markdown</string>
            <key>CFBundleTypeRole</key>
            <string>Editor</string>
            <key>LSHandlerRank</key>
            <string>Owner</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>net.daringfireball.markdown</string>
            </array>
            <key>CFBundleTypeExtensions</key>
            <array>
                <string>md</string>
                <string>markdown</string>
            </array>
        </dict>
    </array>
    <key>UTImportedTypeDeclarations</key>
    <array>
        <dict>
            <key>UTTypeIdentifier</key>
            <string>net.daringfireball.markdown</string>
            <key>UTTypeDescription</key>
            <string>Markdown</string>
            <key>UTTypeConformsTo</key>
            <array>
                <string>public.plain-text</string>
            </array>
            <key>UTTypeTagSpecification</key>
            <dict>
                <key>public.filename-extension</key>
                <array>
                    <string>md</string>
                    <string>markdown</string>
                </array>
            </dict>
        </dict>
    </array>
</dict>
</plist>
PLIST

plutil -lint "$APP/Contents/Info.plist"

rm -rf "$ICON_WORK"
mkdir -p "$ICONSET"

sips -z 16 16 "$ICON_SOURCE" --out "$ICONSET/icon_16x16.png" >/dev/null
sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET/icon_32x32.png" >/dev/null
sips -z 64 64 "$ICON_SOURCE" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$ICON_SOURCE" --out "$ICONSET/icon_128x128.png" >/dev/null
sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET/icon_256x256.png" >/dev/null
sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET/icon_512x512@2x.png" >/dev/null

iconutil -c icns "$ICONSET" -o "$ICNS"

rm -rf "$ICON_WORK"

echo
echo "Applying local ad-hoc signature..."

codesign \
    --force \
    --deep \
    --sign - \
    "$APP"

codesign \
    --verify \
    --deep \
    --strict \
    "$APP"

echo
echo "============================================================"
echo "  MDONNA APP BUILD COMPLETE"
echo "============================================================"
echo
echo "Version:"
echo "  $MDONNA_VERSION"
echo
echo "Build:"
echo "  $MDONNA_BUILD_NUMBER"
echo
echo "Application:"
echo "  $APP"
echo
echo "Signing:"
echo "  local ad-hoc"
echo
