#!/bin/bash
set -e

# Create DMG installer for GitBar using dmgbuild
# Works reliably in CI environments (no AppleScript required)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
DMG_RESOURCES="$PROJECT_DIR/dmg-resources"
APP_NAME="GitBar"

# Parse arguments
APP_PATH="${1:-$BUILD_DIR/Release/$APP_NAME.app}"
OUTPUT_DIR="${2:-$BUILD_DIR}"

# Also check common build locations
if [ ! -d "$APP_PATH" ]; then
    if [ -d "$BUILD_DIR/$APP_NAME.app" ]; then
        APP_PATH="$BUILD_DIR/$APP_NAME.app"
    elif [ -d "$BUILD_DIR/Release/$APP_NAME.app" ]; then
        APP_PATH="$BUILD_DIR/Release/$APP_NAME.app"
    fi
fi

if [ ! -d "$APP_PATH" ]; then
    echo "❌ Error: App not found at $APP_PATH"
    echo "Usage: $0 [app-path] [output-dir]"
    echo "Example: $0 build/GitBar.app build"
    exit 1
fi

# Check if dmgbuild is installed
DMGBUILD_PATH="$HOME/.local/bin/dmgbuild"
if [ ! -f "$DMGBUILD_PATH" ]; then
    DMGBUILD_PATH=$(which dmgbuild 2>/dev/null || true)
fi

if [ -z "$DMGBUILD_PATH" ] || [ ! -f "$DMGBUILD_PATH" ]; then
    echo "❌ Error: dmgbuild not found"
    echo "Install with: pipx install dmgbuild"
    exit 1
fi

# Get version from Info.plist
VERSION=$(defaults read "$APP_PATH/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo "1.0.0")
DMG_FILENAME="$APP_NAME-v$VERSION.dmg"
DMG_PATH="$OUTPUT_DIR/$DMG_FILENAME"

echo "📦 Creating DMG for $APP_NAME v$VERSION..."
echo "📍 App: $APP_PATH"
echo "📍 Output: $DMG_PATH"
echo "🔧 Using: dmgbuild (AppleScript-free)"

# Remove old DMG if it exists
rm -f "$DMG_PATH"

# Generate background image if needed
if [ ! -f "$DMG_RESOURCES/background.png" ]; then
    echo "🎨 Generating DMG background image..."
    cd "$PROJECT_DIR"
    if [ -f "scripts/generate_retro_background.swift" ]; then
        swift scripts/generate_retro_background.swift
    fi
fi

# Ensure output directory exists
mkdir -p "$OUTPUT_DIR"

# Create DMG with dmgbuild
echo "💿 Creating DMG with custom background..."

export APP_PATH="$APP_PATH"
export DMG_RESOURCES="$DMG_RESOURCES"

"$DMGBUILD_PATH" \
    -s "$PROJECT_DIR/dmg-settings.py" \
    "$APP_NAME" \
    "$DMG_PATH"

if [ ! -f "$DMG_PATH" ]; then
    echo "❌ Error: DMG creation failed"
    exit 1
fi

# Get DMG size
DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1)

echo ""
echo "✅ DMG created successfully!"
echo "📍 Location: $DMG_PATH"
echo "📊 Size: $DMG_SIZE"
echo ""

# Verify DMG can be mounted
echo "🔍 Verifying DMG..."
hdiutil verify "$DMG_PATH" -quiet

echo "✅ DMG verification passed!"
echo ""
echo "🚀 Ready for distribution!"
echo "   Filename: $DMG_FILENAME"
echo "   Size: $DMG_SIZE"
