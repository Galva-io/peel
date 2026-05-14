#!/usr/bin/env bash
# Wrap the SPM-produced executable into a macOS `.app` bundle.
#
# Usage:
#   ./scripts/bundle.sh [debug|release]
#
# Output:
#   build/Peel.app
set -euo pipefail

CONFIG="${1:-release}"

if [[ "$CONFIG" != "debug" && "$CONFIG" != "release" ]]; then
    echo "Usage: $0 [debug|release]" >&2
    exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/build"
APP="$BUILD_DIR/Peel.app"

echo "→ Building Swift package ($CONFIG)…"
( cd "$ROOT" && swift build -c "$CONFIG" )

BIN_PATH="$(cd "$ROOT" && swift build -c "$CONFIG" --show-bin-path)"
EXEC="$BIN_PATH/Peel"

if [[ ! -x "$EXEC" ]]; then
    echo "→ Built executable not found at $EXEC" >&2
    exit 1
fi

echo "→ Assembling $APP…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp "$EXEC" "$APP/Contents/MacOS/Peel"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"

# Optional: copy assets if present.
if [[ -f "$ROOT/Resources/AppIcon.icns" ]]; then
    cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi

# Local ad-hoc signing so the app can launch on the developer's machine.
# Production releases are signed with a Developer ID separately (see
# .github/workflows/release.yml).
echo "→ Ad-hoc codesigning…"
codesign --force --deep --sign - \
    --entitlements "$ROOT/Resources/Peel.entitlements" \
    "$APP"

echo "✓ Built $APP"
