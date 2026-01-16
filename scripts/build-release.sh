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
    <string>\${DEVELOPMENT_TEAM}</string>
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

# Create DMG for distribution
echo "💿 Creating DMG..."
DMG_PATH="$BUILD_DIR/$APP_NAME.dmg"
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$APP_PATH" \
    -ov -format UDZO \
    "$DMG_PATH"

echo "✅ Release build complete!"
echo "📍 App: $APP_PATH"
echo "📍 DMG: $DMG_PATH"

# Display signing info
echo ""
echo "📋 Code Signature Details:"
codesign -dv --verbose=4 "$APP_PATH" 2>&1 | grep -E "Authority|TeamIdentifier|Identifier|Format"

# Display Gatekeeper assessment
echo ""
echo "🔒 Gatekeeper Assessment:"
spctl --assess --verbose=4 --type execute "$APP_PATH" 2>&1 || echo "⚠️  App not yet notarized or assessment failed"
