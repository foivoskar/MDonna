#!/bin/bash
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PASS=0
WARN=0
FAIL=0

pass() {
    echo "✓ PASS: $1"
    PASS=$((PASS + 1))
}

warn() {
    echo "⚠ WARN: $1"
    WARN=$((WARN + 1))
}

fail() {
    echo "✗ FAIL: $1"
    FAIL=$((FAIL + 1))
}

echo
echo "=================================================="
echo "  MDonna — Release Portability Check"
echo "=================================================="
echo

# ------------------------------------------------------------
# 1. Find newest DMG
# ------------------------------------------------------------

DMG="$(
    find "$ROOT/dist" \
        -maxdepth 1 \
        -type f \
        -name 'MDonna-*.dmg' \
        -print0 2>/dev/null \
    | xargs -0 ls -t 2>/dev/null \
    | head -1
)"

if [ -z "${DMG:-}" ] || [ ! -f "$DMG" ]; then
    fail "No MDonna release DMG found in dist/"
    echo
    echo "Build one first with:"
    echo "  ./Scripts/build-release.sh"
    exit 1
fi

echo "Testing:"
echo "  $DMG"
echo

ls -lh "$DMG"

# ------------------------------------------------------------
# 2. Verify DMG structure
# ------------------------------------------------------------

echo
echo "=== DMG integrity ==="

if hdiutil verify "$DMG" >/dev/null 2>&1; then
    pass "Disk image passes hdiutil verification."
else
    fail "Disk image failed verification."
    exit 1
fi

# ------------------------------------------------------------
# 3. Mount isolated read-only copy
# ------------------------------------------------------------

TMP="$(mktemp -d /tmp/mdonna-release-check.XXXXXX)"
MOUNT="$TMP/mount"

mkdir -p "$MOUNT"

cleanup() {
    hdiutil detach "$MOUNT" -force >/dev/null 2>&1 || true
    rm -rf "$TMP"
}

trap cleanup EXIT

echo
echo "=== Mounting DMG read-only ==="

if hdiutil attach \
    "$DMG" \
    -readonly \
    -nobrowse \
    -mountpoint "$MOUNT" \
    >/dev/null; then

    pass "DMG mounted successfully."

else
    fail "Could not mount DMG."
    exit 1
fi

APP="$MOUNT/MDonna.app"

if [ ! -d "$APP" ]; then
    fail "MDonna.app is missing from the DMG."
    exit 1
fi

pass "MDonna.app exists inside the DMG."

if [ -L "$MOUNT/Applications" ]; then
    TARGET="$(readlink "$MOUNT/Applications")"

    if [ "$TARGET" = "/Applications" ]; then
        pass "Applications alias/symlink correctly targets /Applications."
    else
        warn "Applications link points to: $TARGET"
    fi
else
    warn "No Applications symlink found in DMG."
fi

# ------------------------------------------------------------
# 4. Read app metadata
# ------------------------------------------------------------

echo
echo "=== Application metadata ==="

PLIST="$APP/Contents/Info.plist"

if [ ! -f "$PLIST" ]; then
    fail "Contents/Info.plist is missing."
    exit 1
fi

EXEC_NAME="$(
    /usr/libexec/PlistBuddy \
        -c 'Print :CFBundleExecutable' \
        "$PLIST" 2>/dev/null
)"

BUNDLE_ID="$(
    /usr/libexec/PlistBuddy \
        -c 'Print :CFBundleIdentifier' \
        "$PLIST" 2>/dev/null
)"

VERSION="$(
    /usr/libexec/PlistBuddy \
        -c 'Print :CFBundleShortVersionString' \
        "$PLIST" 2>/dev/null || true
)"

MIN_OS="$(
    /usr/libexec/PlistBuddy \
        -c 'Print :LSMinimumSystemVersion' \
        "$PLIST" 2>/dev/null || true
)"

echo "Executable:    ${EXEC_NAME:-unknown}"
echo "Bundle ID:     ${BUNDLE_ID:-unknown}"
echo "Version:       ${VERSION:-unknown}"
echo "Minimum macOS: ${MIN_OS:-not explicitly declared}"

EXEC="$APP/Contents/MacOS/$EXEC_NAME"

if [ ! -f "$EXEC" ]; then
    fail "Main executable is missing."
    exit 1
fi

pass "Main executable exists."

# ------------------------------------------------------------
# 5. Architecture
# ------------------------------------------------------------

echo
echo "=== Architecture ==="

file "$EXEC"

ARCHS="$(lipo -archs "$EXEC" 2>/dev/null || true)"

echo
echo "Architectures: ${ARCHS:-unknown}"

if [[ "$ARCHS" == *arm64* && "$ARCHS" == *x86_64* ]]; then
    pass "Universal 2 binary (Apple Silicon + Intel)."
elif [[ "$ARCHS" == *arm64* ]]; then
    pass "Apple Silicon arm64 binary."
    warn "This release does not contain an Intel x86_64 executable."
elif [[ "$ARCHS" == *x86_64* ]]; then
    warn "Intel-only release."
else
    fail "Could not determine executable architecture."
fi

echo
echo "Build target information:"

if command -v vtool >/dev/null 2>&1; then
    vtool -show-build "$EXEC" 2>/dev/null || true
else
    otool -l "$EXEC" \
        | grep -A8 'LC_BUILD_VERSION' \
        || true
fi

# ------------------------------------------------------------
# 6. Code signature
# ------------------------------------------------------------

echo
echo "=== Code signature ==="

if codesign \
    --verify \
    --deep \
    --strict \
    --verbose=2 \
    "$APP" 2>&1; then

    pass "Bundle signature is internally valid."

else
    fail "Bundle signature verification failed."
fi

SIGNATURE_INFO="$(codesign -dv --verbose=4 "$APP" 2>&1 || true)"

echo
echo "$SIGNATURE_INFO" \
    | grep -E 'Identifier=|Format=|CodeDirectory|Signature=|TeamIdentifier=' \
    || true

if echo "$SIGNATURE_INFO" | grep -q 'Signature=adhoc'; then
    warn "Application is ad-hoc signed. Portable, but not yet notarized for public distribution."
fi

# ------------------------------------------------------------
# 7. Gatekeeper assessment
# ------------------------------------------------------------

echo
echo "=== Gatekeeper assessment ==="

SPCTL_OUTPUT="$(spctl --assess --type execute --verbose=4 "$APP" 2>&1)"
SPCTL_STATUS=$?

echo "$SPCTL_OUTPUT"

if [ "$SPCTL_STATUS" -eq 0 ]; then
    pass "Gatekeeper accepts this application."
else
    warn "Gatekeeper does not currently accept it automatically. This is expected for an ad-hoc/non-notarized build."
fi

# ------------------------------------------------------------
# 8. Check every Mach-O file for external dependencies
# ------------------------------------------------------------

echo
echo "=== Dynamic library dependencies ==="

BAD_DEPS=()

while IFS= read -r -d '' FILE; do

    if ! file -b "$FILE" 2>/dev/null | grep -q 'Mach-O'; then
        continue
    fi

    REL="${FILE#$APP/}"

    echo
    echo "--- $REL"

    otool -L "$FILE" 2>/dev/null || true

    while IFS= read -r DEP; do

        [ -z "$DEP" ] && continue

        case "$DEP" in

            /System/Library/*)
                ;;

            /usr/lib/*)
                ;;

            @rpath/*)
                ;;

            @loader_path/*)
                ;;

            @executable_path/*)
                ;;

            *)
                BAD_DEPS+=("$REL -> $DEP")
                ;;

        esac

    done < <(
        otool -L "$FILE" 2>/dev/null \
        | tail -n +2 \
        | awk '{print $1}'
    )

done < <(find "$APP" -type f -print0)

echo

if [ "${#BAD_DEPS[@]}" -eq 0 ]; then

    pass "No Mach-O executable depends on arbitrary external absolute paths."

else

    fail "Non-system external dynamic-library dependencies found:"

    for ITEM in "${BAD_DEPS[@]}"; do
        echo "    $ITEM"
    done

fi

# ------------------------------------------------------------
# 9. Check LC_RPATH entries
# ------------------------------------------------------------

echo
echo "=== Runtime search paths ==="

BAD_RPATHS=()

while IFS= read -r -d '' FILE; do

    if ! file -b "$FILE" 2>/dev/null | grep -q 'Mach-O'; then
        continue
    fi

    REL="${FILE#$APP/}"

    while IFS= read -r RPATH; do

        [ -z "$RPATH" ] && continue

        echo "$REL : $RPATH"

        case "$RPATH" in
            /Users/*|*Dropbox*|*"/dev/MDonna"*|"$ROOT"*)
                BAD_RPATHS+=("$REL -> $RPATH")
                ;;
        esac

    done < <(
        otool -l "$FILE" 2>/dev/null \
        | awk '
            /cmd LC_RPATH/ {
                getline
                getline
                if ($1 == "path") print $2
            }
        '
    )

done < <(find "$APP" -type f -print0)

if [ "${#BAD_RPATHS[@]}" -eq 0 ]; then

    pass "No development-machine paths found in LC_RPATH."

else

    fail "Development paths found in LC_RPATH:"

    for ITEM in "${BAD_RPATHS[@]}"; do
        echo "    $ITEM"
    done

fi

# ------------------------------------------------------------
# 10. Search executable for local development paths
# ------------------------------------------------------------

echo
echo "=== Hard-coded paths in executable ==="

BINARY_PATHS="$(
    strings "$EXEC" 2>/dev/null \
    | grep -E \
        '/Users/foivos|/Users/[^/]+/(Dropbox|dev)/|Dropbox/dev/MDonna' \
    | sort -u \
    || true
)"

if [ -z "$BINARY_PATHS" ]; then

    pass "No local user/repository paths found in the main executable."

else

    fail "Local filesystem paths are embedded in the executable:"
    echo "$BINARY_PATHS"

fi

# ------------------------------------------------------------
# 11. Search text resources for local paths
# ------------------------------------------------------------

echo
echo "=== Development paths in bundled text resources ==="

RESOURCE_PATHS="$(
    grep -R -I -n -E \
        '/Users/foivos|/Users/[^/]+/(Dropbox|dev)/|Dropbox/dev/MDonna' \
        "$APP/Contents" \
        2>/dev/null \
    | head -100 \
    || true
)"

if [ -z "$RESOURCE_PATHS" ]; then

    pass "No local development paths found in bundled text resources."

else

    warn "Local paths occur in bundled text resources:"
    echo
    echo "$RESOURCE_PATHS"
    echo
    echo "These may be harmless source-map/debug references, but should be reviewed."

fi

# ------------------------------------------------------------
# 12. Check symlinks inside application
# ------------------------------------------------------------

echo
echo "=== Symlinks inside MDonna.app ==="

BAD_LINKS=()
LINK_COUNT=0

while IFS= read -r -d '' LINK; do

    LINK_COUNT=$((LINK_COUNT + 1))

    TARGET="$(readlink "$LINK")"

    echo "${LINK#$APP/} -> $TARGET"

    case "$TARGET" in
        /Users/*|*Dropbox*|*"/dev/MDonna"*)
            BAD_LINKS+=("${LINK#$APP/} -> $TARGET")
            ;;
    esac

done < <(find "$APP" -type l -print0)

if [ "${#BAD_LINKS[@]}" -eq 0 ]; then
    pass "No symlinks point back to the development machine."
else
    fail "Development-machine symlinks found:"
    printf '    %s\n' "${BAD_LINKS[@]}"
fi

# ------------------------------------------------------------
# 13. Ensure obvious development directories are not bundled
# ------------------------------------------------------------

echo
echo "=== Development artefacts ==="

DEV_ARTIFACTS="$(
    find "$APP" \
        \( \
            -name node_modules \
            -o -name .git \
            -o -name Backups \
        \) \
        -print 2>/dev/null
)"

if [ -z "$DEV_ARTIFACTS" ]; then
    pass "No Git repository, node_modules or Backups directory bundled."
else
    warn "Development artefacts exist in the app:"
    echo "$DEV_ARTIFACTS"
fi

# ------------------------------------------------------------
# 14. Copy app outside repository and launch it
# ------------------------------------------------------------

echo
echo "=== Isolated launch test ==="

TEST_APP="$TMP/isolated/MDonna.app"

mkdir -p "$TMP/isolated"

ditto "$APP" "$TEST_APP"

if codesign \
    --verify \
    --deep \
    --strict \
    "$TEST_APP" >/dev/null 2>&1; then

    pass "Copied application remains signature-valid outside the DMG/repository."

else

    fail "Copied application failed signature verification."

fi

echo
echo "Launching temporary copy:"
echo "  $TEST_APP"
echo

open -n "$TEST_APP"

sleep 4

PID="$(
    pgrep -f "$TEST_APP/Contents/MacOS/MDonna" \
    | head -1 \
    || true
)"

if [ -n "$PID" ]; then

    pass "MDonna launched successfully from an arbitrary temporary directory."

    echo "Temporary test process PID: $PID"
    kill "$PID" >/dev/null 2>&1 || true

else

    warn "Could not confirm the temporary process automatically."
    echo "If a MDonna window appeared, the launch itself succeeded."

fi

# ------------------------------------------------------------
# RESULT
# ------------------------------------------------------------

echo
echo "=================================================="
echo "  RELEASE CHECK SUMMARY"
echo "=================================================="
echo
echo "PASS : $PASS"
echo "WARN : $WARN"
echo "FAIL : $FAIL"
echo

if [ "$FAIL" -eq 0 ]; then

    echo "✓ No portability-blocking problems were detected."
    echo

    if [[ "$ARCHS" == *arm64* && "$ARCHS" != *x86_64* ]]; then
        echo "This DMG is currently suitable for Apple Silicon Macs."
    fi

    echo
    echo "Warnings about Gatekeeper/ad-hoc signing are expected"
    echo "until Developer ID signing + Apple notarization are added."

else

    echo "✗ Do NOT distribute this DMG yet."
    echo "  At least one portability problem needs to be fixed."

fi

echo
echo "DMG checked:"
echo "  $DMG"
echo
