#!/bin/bash
set -e

# Create beautiful DMG installer for GitBar
# Uses create-dmg tool for professional drag-to-Applications UX

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
DMG_RESOURCES="$PROJECT_DIR/dmg-resources"
APP_NAME="GitBar"

# Parse arguments
APP_PATH="${1:-$BUILD_DIR/$APP_NAME.app}"
OUTPUT_DIR="${2:-$BUILD_DIR}"

if [ ! -d "$APP_PATH" ]; then
    echo "❌ Error: App not found at $APP_PATH"
    echo "Usage: $0 [app-path] [output-dir]"
    echo "Example: $0 build/GitBar.app build"
    exit 1
fi

# In CI/headless environments, use dmgbuild (no AppleScript needed) for reliable layout
if [ -n "$CI" ] || [ -n "$GITHUB_ACTIONS" ]; then
    echo "⚠️  CI environment detected, using dmgbuild-based DMG creation..."
    "$SCRIPT_DIR/create-dmg-v2.sh" "$APP_PATH" "$OUTPUT_DIR"
    exit $?
fi

# Check if create-dmg is installed
if ! command -v create-dmg &> /dev/null; then
    echo "❌ Error: create-dmg not found"
    echo "Install with: brew install create-dmg"
    exit 1
fi

# Get version from Info.plist
VERSION=$(defaults read "$APP_PATH/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo "1.0.0")
DMG_FILENAME="$APP_NAME-v$VERSION.dmg"
DMG_PATH="$OUTPUT_DIR/$DMG_FILENAME"

echo "📦 Creating DMG for $APP_NAME v$VERSION..."
echo "📍 App: $APP_PATH"
echo "📍 Output: $DMG_PATH"

# Remove old DMG if it exists
rm -f "$DMG_PATH"

# Generate background image if needed (prefer TIFF for Retina support)
if [ ! -f "$DMG_RESOURCES/background.tiff" ]; then
    echo "🎨 Generating DMG background images (1x + 2x for Retina)..."
    cd "$PROJECT_DIR"
    ./generate_dmg_background.swift
fi

# Determine which background file to use (TIFF for Retina, PNG as fallback)
if [ -f "$DMG_RESOURCES/background.tiff" ]; then
    BACKGROUND_FILE="$DMG_RESOURCES/background.tiff"
    echo "🖼️  Using multi-resolution TIFF background (Retina-ready)"
elif [ -f "$DMG_RESOURCES/background.png" ]; then
    BACKGROUND_FILE="$DMG_RESOURCES/background.png"
    echo "🖼️  Using PNG background (non-Retina)"
else
    echo "❌ Error: No background image found"
    exit 1
fi

# Create DMG with create-dmg
echo "💿 Creating DMG with drag-to-Applications layout..."

# Check for volume icon - prefer dmg-resources, then app bundle
VOLICON_ARG=""
if [ -f "$DMG_RESOURCES/AppIcon.icns" ]; then
    VOLICON_ARG="--volicon $DMG_RESOURCES/AppIcon.icns"
    echo "🎨 Using volume icon from dmg-resources"
elif [ -f "$APP_PATH/Contents/Resources/AppIcon.icns" ]; then
    VOLICON_ARG="--volicon $APP_PATH/Contents/Resources/AppIcon.icns"
    echo "🎨 Using volume icon from app bundle"
else
    echo "⚠️  No volume icon found, DMG will use default icon"
fi

create-dmg \
  --volname "$APP_NAME" \
  $VOLICON_ARG \
  --background "$BACKGROUND_FILE" \
  --window-pos 200 120 \
  --window-size 660 400 \
  --icon-size 100 \
  --icon "$APP_NAME.app" 165 200 \
  --hide-extension "$APP_NAME.app" \
  --app-drop-link 495 200 \
  "$DMG_PATH" \
  "$APP_PATH"

if [ ! -f "$DMG_PATH" ]; then
    echo "❌ Error: DMG creation failed"
    exit 1
fi

# Get DMG size in MB
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
