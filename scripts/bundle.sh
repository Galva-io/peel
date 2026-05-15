#!/usr/bin/env bash
# Wrap the SPM-produced executable into a macOS `.app` bundle.
#
# Usage:
#   ./scripts/bundle.sh [debug|release]
#
# Output:
#   build/Peel.app
#
# Notes:
#   • Compiles `Sources/PeelApp/Resources/Assets.xcassets` via `actool` so the
#     app icon and AccentColor reach the bundle. The Tuist/xcodebuild path
#     handles this natively; this script mirrors it for SPM-only builds.
#   • Ad-hoc signs locally. Release signing happens in
#     `.github/workflows/release.yml`.
set -euo pipefail

CONFIG="${1:-release}"

if [[ "$CONFIG" != "debug" && "$CONFIG" != "release" ]]; then
    echo "Usage: $0 [debug|release]" >&2
    exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/build"
APP="$BUILD_DIR/Peel.app"
ASSETS_DIR="$ROOT/Sources/PeelApp/Resources/Assets.xcassets"

echo "→ Building Swift package ($CONFIG)…"
( cd "$ROOT" && swift build -c "$CONFIG" )

BIN_PATH="$(cd "$ROOT" && swift build -c "$CONFIG" --show-bin-path)"
EXEC="$BIN_PATH/Peel"

if [[ ! -x "$EXEC" ]]; then
    echo "→ Built executable not found at $EXEC" >&2
    exit 1
fi

echo "→ Assembling ${APP}…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp "$EXEC" "$APP/Contents/MacOS/Peel"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"

# Compile the asset catalog if it's present. actool merges its output into a
# partial Info.plist (icon-name, primary-icon keys); we splice that into our
# main Info.plist with /usr/libexec/PlistBuddy so the final Info.plist
# advertises whatever assets actool produced.
if [[ -d "$ASSETS_DIR" ]]; then
    echo "→ Compiling asset catalog with actool…"
    PARTIAL_PLIST="$(mktemp -t peel-actool-plist).plist"
    # `--accent-color-name` only exists on iOS; macOS picks up an AccentColor
    # entry from the catalog automatically. `actool` is fussy about flag
    # ordering — keep the positional asset-catalog path last.
    xcrun actool \
        --output-format human-readable-text \
        --notices --warnings \
        --output-partial-info-plist "$PARTIAL_PLIST" \
        --app-icon AppIcon \
        --enable-on-demand-resources NO \
        --target-device mac \
        --minimum-deployment-target 14.0 \
        --platform macosx \
        --compile "$APP/Contents/Resources" \
        "$ASSETS_DIR" >/dev/null

    if [[ -f "$PARTIAL_PLIST" ]]; then
        # Merge actool's keys into our Info.plist. The `Merge` PlistBuddy
        # verb is undocumented but stable since 10.6.
        /usr/libexec/PlistBuddy -c "Merge $PARTIAL_PLIST" "$APP/Contents/Info.plist" >/dev/null || true
        rm -f "$PARTIAL_PLIST"
    fi
fi

# Ad-hoc local sign so the app can launch on the developer's machine.
echo "→ Ad-hoc codesigning…"
codesign --force --deep --sign - \
    --entitlements "$ROOT/Resources/Peel.entitlements" \
    "$APP"

echo "✓ Built $APP"
