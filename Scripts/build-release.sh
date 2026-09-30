#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="MDonna"
BUILD_SCRIPT="$ROOT/Scripts/build-app.sh"
APP="$ROOT/dist/MDonna.app"

WORK="$ROOT/.build/release-dmg"
STAGING="$WORK/staging"
RW_DMG="$WORK/MDonna-rw.dmg"

VOLUME_NAME="MDonna Installer"

echo
echo "=========================================="
echo "  MDonna — DMG Release Builder"
echo "=========================================="
echo

# ------------------------------------------------------------
# CLEAN OLD RELEASE WORK
# ------------------------------------------------------------

hdiutil detach "/Volumes/$VOLUME_NAME" -force >/dev/null 2>&1 || true

rm -rf "$WORK"
mkdir -p "$WORK"
mkdir -p "$ROOT/dist"

# ------------------------------------------------------------
# BUILD APPLICATION
# ------------------------------------------------------------

echo "▶ Building MDonna..."
echo

chmod +x "$BUILD_SCRIPT"
"$BUILD_SCRIPT"

if [ ! -d "$APP" ]; then
    echo
    echo "ERROR: MDonna.app was not produced:"
    echo "  $APP"
    exit 1
fi

echo
echo "✓ Application built:"
echo "  $APP"

# ------------------------------------------------------------
# VERSION
# ------------------------------------------------------------

PLIST="$APP/Contents/Info.plist"

VERSION="$(
    /usr/libexec/PlistBuddy \
        -c 'Print :CFBundleShortVersionString' \
        "$PLIST" 2>/dev/null || true
)"

if [ -z "$VERSION" ]; then
    VERSION="0.1.0"
fi

# ------------------------------------------------------------
# ARCHITECTURE
# ------------------------------------------------------------

EXECUTABLE="$APP/Contents/MacOS/MDonna"

ARCHS="$(lipo -archs "$EXECUTABLE" 2>/dev/null || true)"

if [[ "$ARCHS" == *"arm64"* && "$ARCHS" == *"x86_64"* ]]; then
    ARCH_LABEL="universal"
elif [[ "$ARCHS" == *"arm64"* ]]; then
    ARCH_LABEL="arm64"
elif [[ "$ARCHS" == *"x86_64"* ]]; then
    ARCH_LABEL="x86_64"
else
    ARCH_LABEL="macOS"
fi

FINAL_DMG="$ROOT/dist/MDonna-${VERSION}-macOS-${ARCH_LABEL}.dmg"

echo
echo "Version:      $VERSION"
echo "Architecture: ${ARCHS:-unknown}"
echo "Output:"
echo "  $FINAL_DMG"

rm -f "$FINAL_DMG"

# ------------------------------------------------------------
# PREPARE DMG CONTENT
# ------------------------------------------------------------

echo
echo "▶ Preparing installer contents..."

mkdir -p "$STAGING/.background"

ditto "$APP" "$STAGING/MDonna.app"

ln -s /Applications "$STAGING/Applications"

# ------------------------------------------------------------
# CREATE BACKGROUND IMAGE
# ------------------------------------------------------------

cat > "$WORK/background.swift" <<'SWIFT'
import AppKit

let width: CGFloat = 720
let height: CGFloat = 420

let image = NSImage(size: NSSize(width: width, height: height))

image.lockFocus()

guard let context = NSGraphicsContext.current?.cgContext else {
    fatalError("Could not create drawing context")
}

let colorSpace = CGColorSpaceCreateDeviceRGB()

let colors = [
    NSColor(
        calibratedRed: 0.985,
        green: 0.976,
        blue: 0.955,
        alpha: 1.0
    ).cgColor,

    NSColor(
        calibratedRed: 0.945,
        green: 0.925,
        blue: 0.910,
        alpha: 1.0
    ).cgColor
] as CFArray

let locations: [CGFloat] = [0.0, 1.0]

if let gradient = CGGradient(
    colorsSpace: colorSpace,
    colors: colors,
    locations: locations
) {
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: height),
        end: CGPoint(x: width, y: 0),
        options: []
    )
}

let centered = NSMutableParagraphStyle()
centered.alignment = .center

let titleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(
        ofSize: 29,
        weight: .semibold
    ),
    .foregroundColor: NSColor(
        calibratedRed: 0.11,
        green: 0.10,
        blue: 0.16,
        alpha: 1.0
    ),
    .paragraphStyle: centered
]

NSString(string: "MDonna").draw(
    in: NSRect(
        x: 0,
        y: 335,
        width: width,
        height: 45
    ),
    withAttributes: titleAttributes
)

let subtitleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(
        ofSize: 15,
        weight: .regular
    ),
    .foregroundColor: NSColor(
        calibratedWhite: 0.36,
        alpha: 1.0
    ),
    .paragraphStyle: centered
]

NSString(string: "Drag MDonna to Applications").draw(
    in: NSRect(
        x: 0,
        y: 305,
        width: width,
        height: 28
    ),
    withAttributes: subtitleAttributes
)

let arrowColor = NSColor(
    calibratedRed: 0.43,
    green: 0.36,
    blue: 0.67,
    alpha: 0.75
)

arrowColor.setStroke()
arrowColor.setFill()

let line = NSBezierPath()
line.lineWidth = 4
line.lineCapStyle = .round

line.move(
    to: NSPoint(
        x: 313,
        y: 185
    )
)

line.line(
    to: NSPoint(
        x: 407,
        y: 185
    )
)

line.stroke()

let head = NSBezierPath()

head.move(
    to: NSPoint(
        x: 407,
        y: 185
    )
)

head.line(
    to: NSPoint(
        x: 387,
        y: 200
    )
)

head.line(
    to: NSPoint(
        x: 387,
        y: 170
    )
)

head.close()
head.fill()

let footerAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(
        ofSize: 11,
        weight: .regular
    ),
    .foregroundColor: NSColor(
        calibratedWhite: 0.52,
        alpha: 1.0
    ),
    .paragraphStyle: centered
]

NSString(
    string: "Markdown, immediately readable."
).draw(
    in: NSRect(
        x: 0,
        y: 35,
        width: width,
        height: 22
    ),
    withAttributes: footerAttributes
)

image.unlockFocus()

guard
    let tiff = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiff),
    let png = bitmap.representation(
        using: .png,
        properties: [:]
    )
else {
    fatalError("Could not encode background PNG")
}

try png.write(
    to: URL(
        fileURLWithPath: CommandLine.arguments[1]
    ),
    options: .atomic
)
SWIFT

swift \
    "$WORK/background.swift" \
    "$STAGING/.background/background.png"

echo "✓ Installer background created."

# ------------------------------------------------------------
# CREATE WRITABLE DMG
# ------------------------------------------------------------

echo
echo "▶ Creating writable DMG..."

rm -f "$RW_DMG"

hdiutil create \
    -srcfolder "$STAGING" \
    -volname "$VOLUME_NAME" \
    -fs HFS+ \
    -format UDRW \
    "$RW_DMG" \
    >/dev/null

echo "✓ Writable DMG created."

# ------------------------------------------------------------
# MOUNT IT
# ------------------------------------------------------------

echo
echo "▶ Mounting installer..."

hdiutil detach "/Volumes/$VOLUME_NAME" \
    -force >/dev/null 2>&1 || true

hdiutil attach \
    "$RW_DMG" \
    -readwrite \
    -noverify \
    -noautoopen \
    >/dev/null

MOUNT="/Volumes/$VOLUME_NAME"

if [ ! -d "$MOUNT" ]; then
    echo
    echo "ERROR: DMG mounted but expected volume was not found:"
    echo "  $MOUNT"
    exit 1
fi

chflags hidden "$MOUNT/.background" 2>/dev/null || true

# ------------------------------------------------------------
# STYLE FINDER WINDOW
# ------------------------------------------------------------

echo "▶ Styling Finder installer window..."

osascript <<APPLESCRIPT
tell application "Finder"

    tell disk "$VOLUME_NAME"

        open

        set current view of container window to icon view

        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set pathbar visible of container window to false

        set bounds of container window to {200, 150, 920, 570}

        set opts to icon view options of container window

        set arrangement of opts to not arranged
        set icon size of opts to 112
        set text size of opts to 13

        set background picture of opts to file ".background:background.png"

        set position of item "MDonna.app" of container window to {205, 215}
        set position of item "Applications" of container window to {515, 215}

        update without registering applications

        delay 3

        close

    end tell

end tell
APPLESCRIPT

sync
sleep 3

# ------------------------------------------------------------
# DETACH
# ------------------------------------------------------------

echo "▶ Closing writable image..."

hdiutil detach "$MOUNT" >/dev/null

# ------------------------------------------------------------
# COMPRESS FINAL DMG
# ------------------------------------------------------------

echo "▶ Compressing final DMG..."

hdiutil convert \
    "$RW_DMG" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$FINAL_DMG" \
    >/dev/null

rm -f "$RW_DMG"

# ------------------------------------------------------------
# VERIFY
# ------------------------------------------------------------

if [ ! -f "$FINAL_DMG" ]; then
    echo
    echo "ERROR: Final DMG was not created."
    exit 1
fi

echo
echo "▶ Verifying installer..."

hdiutil verify "$FINAL_DMG" >/dev/null

echo
echo "=========================================="
echo "  ✓ RELEASE SUCCESSFULLY CREATED"
echo "=========================================="
echo

echo "Application:"
echo "  $APP"
echo

echo "DMG:"
echo "  $FINAL_DMG"
echo

echo "Size:"
du -h "$FINAL_DMG"

echo
echo "Opening installer..."
echo

# ------------------------------------------------------------
# OPEN FINAL INSTALLER
# ------------------------------------------------------------

open "$FINAL_DMG"

for i in {1..20}; do
    if [ -d "/Volumes/$VOLUME_NAME" ]; then
        break
    fi

    sleep 0.5
done

if [ -d "/Volumes/$VOLUME_NAME" ]; then
    open "/Volumes/$VOLUME_NAME"
fi

echo
echo "=========================================="
echo "  DONE"
echo "=========================================="
