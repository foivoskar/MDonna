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

MDONNA_ICON_SUPPORT_BEGIN=1

echo
echo "=== Creating application icon ==="

MDONNA_PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MDONNA_APP_PATH="$MDONNA_PROJECT_ROOT/dist/MDonna.app"
MDONNA_ICON_SOURCE="$MDONNA_PROJECT_ROOT/Assets/MDonnaIcon.png"
MDONNA_ICON_TMP="$(mktemp -d /tmp/mdonna-icon.XXXXXX)"
MDONNA_ICONSET="$MDONNA_ICON_TMP/MDonnaIcon.iconset"

if [ ! -f "$MDONNA_ICON_SOURCE" ]; then
    echo "ERROR: Missing icon source: $MDONNA_ICON_SOURCE"
    exit 1
fi

mkdir -p "$MDONNA_ICONSET"
mkdir -p "$MDONNA_APP_PATH/Contents/Resources"

sips -z 16 16 "$MDONNA_ICON_SOURCE" --out "$MDONNA_ICONSET/icon_16x16.png" >/dev/null
sips -z 32 32 "$MDONNA_ICON_SOURCE" --out "$MDONNA_ICONSET/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$MDONNA_ICON_SOURCE" --out "$MDONNA_ICONSET/icon_32x32.png" >/dev/null
sips -z 64 64 "$MDONNA_ICON_SOURCE" --out "$MDONNA_ICONSET/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$MDONNA_ICON_SOURCE" --out "$MDONNA_ICONSET/icon_128x128.png" >/dev/null
sips -z 256 256 "$MDONNA_ICON_SOURCE" --out "$MDONNA_ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$MDONNA_ICON_SOURCE" --out "$MDONNA_ICONSET/icon_256x256.png" >/dev/null
sips -z 512 512 "$MDONNA_ICON_SOURCE" --out "$MDONNA_ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$MDONNA_ICON_SOURCE" --out "$MDONNA_ICONSET/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$MDONNA_ICON_SOURCE" --out "$MDONNA_ICONSET/icon_512x512@2x.png" >/dev/null

iconutil -c icns "$MDONNA_ICONSET" \
    -o "$MDONNA_APP_PATH/Contents/Resources/MDonnaIcon.icns" || exit 1

MDONNA_PLIST="$MDONNA_APP_PATH/Contents/Info.plist"

/usr/libexec/PlistBuddy \
    -c "Set :CFBundleIconFile MDonnaIcon.icns" \
    "$MDONNA_PLIST" 2>/dev/null || \
/usr/libexec/PlistBuddy \
    -c "Add :CFBundleIconFile string MDonnaIcon.icns" \
    "$MDONNA_PLIST" || exit 1

rm -rf "$MDONNA_ICON_TMP"

echo "Icon created:"
ls -lh "$MDONNA_APP_PATH/Contents/Resources/MDonnaIcon.icns"

MDONNA_ICON_SUPPORT_END=1


MDONNA_DOCUMENT_TYPES_BEGIN=1

echo
echo "=== Registering Markdown document type ==="

MDONNA_PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MDONNA_APP_PATH="$MDONNA_PROJECT_ROOT/dist/MDonna.app"
MDONNA_PLIST="$MDONNA_APP_PATH/Contents/Info.plist"

/usr/libexec/PlistBuddy -c "Delete :CFBundleDocumentTypes" "$MDONNA_PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes array" "$MDONNA_PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0 dict" "$MDONNA_PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:CFBundleTypeName string Markdown" "$MDONNA_PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:CFBundleTypeRole string Editor" "$MDONNA_PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:LSHandlerRank string Owner" "$MDONNA_PLIST"

/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes array" "$MDONNA_PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes:0 string net.daringfireball.markdown" "$MDONNA_PLIST"

/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:CFBundleTypeExtensions array" "$MDONNA_PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:CFBundleTypeExtensions:0 string md" "$MDONNA_PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:CFBundleTypeExtensions:1 string markdown" "$MDONNA_PLIST"

/usr/libexec/PlistBuddy -c "Delete :UTImportedTypeDeclarations" "$MDONNA_PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :UTImportedTypeDeclarations array" "$MDONNA_PLIST"
/usr/libexec/PlistBuddy -c "Add :UTImportedTypeDeclarations:0 dict" "$MDONNA_PLIST"
/usr/libexec/PlistBuddy -c "Add :UTImportedTypeDeclarations:0:UTTypeIdentifier string net.daringfireball.markdown" "$MDONNA_PLIST"
/usr/libexec/PlistBuddy -c "Add :UTImportedTypeDeclarations:0:UTTypeDescription string Markdown" "$MDONNA_PLIST"

/usr/libexec/PlistBuddy -c "Add :UTImportedTypeDeclarations:0:UTTypeConformsTo array" "$MDONNA_PLIST"
/usr/libexec/PlistBuddy -c "Add :UTImportedTypeDeclarations:0:UTTypeConformsTo:0 string public.plain-text" "$MDONNA_PLIST"

/usr/libexec/PlistBuddy -c "Add :UTImportedTypeDeclarations:0:UTTypeTagSpecification dict" "$MDONNA_PLIST"
/usr/libexec/PlistBuddy -c "Add :UTImportedTypeDeclarations:0:UTTypeTagSpecification:public.filename-extension array" "$MDONNA_PLIST"
/usr/libexec/PlistBuddy -c "Add :UTImportedTypeDeclarations:0:UTTypeTagSpecification:public.filename-extension:0 string md" "$MDONNA_PLIST"
/usr/libexec/PlistBuddy -c "Add :UTImportedTypeDeclarations:0:UTTypeTagSpecification:public.filename-extension:1 string markdown" "$MDONNA_PLIST"

echo "Markdown document type:"
/usr/libexec/PlistBuddy -c "Print :CFBundleDocumentTypes" "$MDONNA_PLIST"

MDONNA_DOCUMENT_TYPES_END=1

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
