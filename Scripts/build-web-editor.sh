#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v node >/dev/null 2>&1; then
    echo "ERROR: Node.js is required."
    exit 1
fi

if ! command -v npm >/dev/null 2>&1; then
    echo "ERROR: npm is required."
    exit 1
fi

cd "$ROOT/WebEditor"

if [ "${MDONNA_WEB_CLEAN:-0}" = "1" ] || [ ! -d node_modules ]; then
    echo
    echo "Installing locked WebEditor dependencies..."
    npm ci
fi

echo
echo "Building WebEditor..."
npm run build

for FILE in \
    "$ROOT/Sources/MDonna/Resources/WebEditor/editor.js" \
    "$ROOT/Sources/MDonna/Resources/WebEditor/index.html" \
    "$ROOT/Sources/MDonna/Resources/WebEditor/theme.css" \
    "$ROOT/Sources/MDonna/Resources/WebEditor/katex.min.css"
do
    if [ ! -f "$FILE" ]; then
        echo "ERROR: Missing generated WebEditor resource:"
        echo "  $FILE"
        exit 1
    fi
done

if [ ! -d "$ROOT/Sources/MDonna/Resources/WebEditor/fonts" ]; then
    echo "ERROR: Missing generated KaTeX fonts."
    exit 1
fi

echo
echo "WebEditor build complete."
