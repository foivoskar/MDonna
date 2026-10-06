#!/bin/bash
set -euo pipefail

REPOSITORY_URL="https://github.com/foivoskar/MDonna.git"
CHECK_ONLY=0
EXPLICIT_SOURCE=0
SOURCE_DIR=""

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

usage() {
    cat <<'USAGE'

MDonna source-first installer

Usage:

    ./install.sh
    ./install.sh --check
    ./install.sh --source-dir PATH

MDonna is compiled locally from source.
No prebuilt MDonna executable is downloaded.

USAGE
}

while [ -n "${1:-}" ]; do
    case "$1" in
        --check)
            CHECK_ONLY=1
            shift
            ;;
        --source-dir)
            if [ -z "${2:-}" ]; then
                echo "ERROR: --source-dir requires a path."
                exit 1
            fi
            SOURCE_DIR="$2"
            EXPLICIT_SOURCE=1
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option:"
            echo "  $1"
            usage
            exit 1
            ;;
    esac
done

echo
echo "============================================================"
echo "  MDONNA SOURCE-FIRST INSTALLER"
echo "============================================================"
echo

if [ "$(uname -s)" != "Darwin" ]; then
    echo "ERROR: The current native MDonna shell supports macOS only."
    exit 1
fi

MACOS_VERSION="$(sw_vers -productVersion 2>/dev/null || true)"
MACOS_MAJOR="${MACOS_VERSION%%.*}"

if [ -z "$MACOS_VERSION" ] || ! [[ "$MACOS_MAJOR" =~ ^[0-9]+$ ]]; then
    echo "ERROR: Could not determine macOS version."
    exit 1
fi

if [ "$MACOS_MAJOR" -lt 14 ]; then
    echo "ERROR: MDonna requires macOS 14 or later."
    exit 1
fi

if ! xcode-select -p >/dev/null 2>&1; then
    echo
    echo "Apple Command Line Tools are required."
    echo
    echo "Run:"
    echo
    echo "  xcode-select --install"
    echo
    exit 1
fi

for TOOL in git node npm xcrun codesign hdiutil iconutil sips shasum; do
    if ! command -v "$TOOL" >/dev/null 2>&1; then
        echo "ERROR: Required tool not found:"
        echo "  $TOOL"
        exit 1
    fi
done

SWIFT="$(xcrun --find swift 2>/dev/null || true)"

if [ -z "$SWIFT" ]; then
    echo "ERROR: Apple Swift could not be found."
    exit 1
fi

SWIFT_VERSION_OUTPUT="$("$SWIFT" --version)"
SWIFT_VERSION="$(printf '%s\n' "$SWIFT_VERSION_OUTPUT" | sed -n 's/.*Swift version \([0-9][0-9.]*\).*/\1/p' | head -n 1)"
SWIFT_MAJOR="${SWIFT_VERSION%%.*}"

if [ -z "$SWIFT_VERSION" ] || [ "$SWIFT_MAJOR" -lt 6 ]; then
    echo "ERROR: Swift 6 or later is required."
    exit 1
fi

NODE_VERSION="$(node --version | sed 's/^v//')"
NODE_MAJOR="${NODE_VERSION%%.*}"

if [ -z "$NODE_VERSION" ] || [ "$NODE_MAJOR" -lt 18 ]; then
    echo "ERROR: Node.js 18 or later is required."
    exit 1
fi

echo "macOS:"
echo "  $MACOS_VERSION"
echo
echo "Architecture:"
echo "  $(uname -m)"
echo
echo "Swift:"
echo "  $SWIFT_VERSION"
echo
echo "Node.js:"
echo "  $NODE_VERSION"
echo
echo "npm:"
echo "  $(npm --version)"
echo

if [ "$CHECK_ONLY" -eq 1 ]; then
    echo "============================================================"
    echo "  THIS MAC CAN BUILD MDONNA"
    echo "============================================================"
    echo
    exit 0
fi

if [ "$EXPLICIT_SOURCE" -eq 0 ]; then
    if [ -d "$SCRIPT_DIR/.git" ]; then
        ORIGIN="$(git -C "$SCRIPT_DIR" remote get-url origin 2>/dev/null || true)"

        case "$ORIGIN" in
            "https://github.com/foivoskar/MDonna.git"|"https://github.com/foivoskar/MDonna"|"git@github.com:foivoskar/MDonna.git")
                SOURCE_DIR="$SCRIPT_DIR"
                ;;
        esac
    fi

    if [ -z "$SOURCE_DIR" ]; then
        SOURCE_DIR="$HOME/MDonna"
    fi
fi

if [ -e "$SOURCE_DIR" ]; then

    if [ ! -d "$SOURCE_DIR/.git" ]; then
        echo "ERROR: Source directory exists but is not a Git repository:"
        echo "  $SOURCE_DIR"
        exit 1
    fi

    cd "$SOURCE_DIR"

    ORIGIN="$(git remote get-url origin 2>/dev/null || true)"

    case "$ORIGIN" in
        "https://github.com/foivoskar/MDonna.git"|"https://github.com/foivoskar/MDonna"|"git@github.com:foivoskar/MDonna.git")
            ;;
        *)
            echo "ERROR: Unexpected Git origin:"
            echo "  $ORIGIN"
            exit 1
            ;;
    esac

    if [ -n "$(git status --porcelain)" ]; then
        echo "ERROR: Source checkout contains local changes."
        echo
        git status -sb
        exit 1
    fi

    if [ "$(git branch --show-current)" = "main" ]; then
        git fetch origin
        git pull --ff-only origin main
    fi

else

    echo "Cloning MDonna source..."
    git clone "$REPOSITORY_URL" "$SOURCE_DIR"
    cd "$SOURCE_DIR"

fi

echo
echo "Building MDonna locally from source..."

MDONNA_WEB_CLEAN=1 "$SOURCE_DIR/Scripts/build-local-dmg.sh"
