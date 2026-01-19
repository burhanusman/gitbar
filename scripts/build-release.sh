#!/bin/bash
set -e

# Build, sign, notarize, and package GitBar for distribution
# This script automates the complete release process

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
DERIVED_DATA="$BUILD_DIR/DerivedData"
APP_NAME="GitBar"

# Configuration
CONFIGURATION="Release"
SCHEME="GitBar"
KEYCHAIN_PROFILE="${KEYCHAIN_PROFILE:-gitbar-notarytool}"

# Parse arguments
SKIP_NOTARIZATION=false
SKIP_BUILD=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-notarization)
            SKIP_NOTARIZATION=true
            shift
            ;;
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--skip-notarization] [--skip-build]"
            exit 1
            ;;
    esac
done

# Clean build directory
echo "🧹 Cleaning build directory..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

if [ "$SKIP_BUILD" = false ]; then
    echo "🔨 Building $APP_NAME (Release)..."

    # Build the app
    xcodebuild -project "$PROJECT_DIR/GitBar.xcodeproj" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -derivedDataPath "$DERIVED_DATA" \
        -archivePath "$BUILD_DIR/$APP_NAME.xcarchive" \
        archive

    echo "📦 Exporting app..."

    # Create export options plist
    cat > "$BUILD_DIR/ExportOptions.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>TNJF6P8FFF</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>stripSwiftSymbols</key>
    <true/>
</dict>
</plist>
EOF

    # Export the archive
    xcodebuild -exportArchive \
        -archivePath "$BUILD_DIR/$APP_NAME.xcarchive" \
        -exportPath "$BUILD_DIR" \
        -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist"

    echo "✅ Build complete!"
else
    echo "⏭️  Skipping build (--skip-build flag set)"
fi

APP_PATH="$BUILD_DIR/$APP_NAME.app"

if [ ! -d "$APP_PATH" ]; then
    echo "❌ Error: App not found at $APP_PATH"
    exit 1
fi

# Verify code signature
echo "🔍 Verifying code signature..."
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

if [ "$SKIP_NOTARIZATION" = false ]; then
    echo "🚀 Starting notarization..."
    "$SCRIPT_DIR/notarize.sh" "$APP_PATH" "$KEYCHAIN_PROFILE"
else
    echo "⏭️  Skipping notarization (--skip-notarization flag set)"
fi

# Get version for DMG filename
VERSION=$(defaults read "$APP_PATH/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo "1.0.0")
DMG_FILENAME="$APP_NAME-v$VERSION.dmg"
DMG_PATH="$BUILD_DIR/$DMG_FILENAME"

# Create beautiful DMG with drag-to-Applications UX
echo "💿 Creating DMG..."
"$SCRIPT_DIR/create-dmg.sh" "$APP_PATH" "$BUILD_DIR"

# Sign DMG if not skipping notarization
if [ "$SKIP_NOTARIZATION" = false ]; then
    echo "🔏 Signing DMG..."
    codesign --sign "Developer ID Application" --timestamp "$DMG_PATH"

    echo "🚀 Notarizing DMG..."
    DMG_NOTARIZE_ZIP="$BUILD_DIR/$APP_NAME-dmg-notarize.zip"
    zip -j "$DMG_NOTARIZE_ZIP" "$DMG_PATH"

    xcrun notarytool submit "$DMG_NOTARIZE_ZIP" \
        --keychain-profile "$KEYCHAIN_PROFILE" \
        --wait

    echo "🔖 Stapling notarization ticket to DMG..."
    xcrun stapler staple "$DMG_PATH"

    rm "$DMG_NOTARIZE_ZIP"
    echo "✅ DMG signed and notarized!"
else
    echo "⏭️  Skipping DMG signing/notarization"
fi

echo ""
echo "✅ Release build complete!"
echo "📍 App: $APP_PATH"
echo "📍 DMG: $DMG_PATH"
echo "📊 DMG Size: $(du -h "$DMG_PATH" | cut -f1)"

# Display signing info
echo ""
echo "📋 Code Signature Details:"
codesign -dv --verbose=4 "$APP_PATH" 2>&1 | grep -E "Authority|TeamIdentifier|Identifier|Format"

# Display Gatekeeper assessment
echo ""
echo "🔒 Gatekeeper Assessment:"
spctl --assess --verbose=4 --type execute "$APP_PATH" 2>&1 || echo "⚠️  App not yet notarized or assessment failed"
