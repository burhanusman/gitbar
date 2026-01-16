#!/bin/bash

# Test Homebrew Cask Formula Locally
# This script helps test the gitbar cask formula before submitting to homebrew-cask

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CASK_FILE="$PROJECT_DIR/Casks/gitbar.rb"

echo "🍺 GitBar Homebrew Cask Testing Script"
echo "======================================"
echo ""

# Check if cask file exists
if [ ! -f "$CASK_FILE" ]; then
    echo "❌ Error: Cask file not found at $CASK_FILE"
    exit 1
fi

echo "✓ Found cask formula: $CASK_FILE"
echo ""

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    echo "❌ Error: Homebrew is not installed"
    echo "Install from: https://brew.sh"
    exit 1
fi

echo "✓ Homebrew is installed"
echo ""

# Parse command line arguments
COMMAND="${1:-help}"

case "$COMMAND" in
    audit)
        echo "📋 Running Homebrew audit..."
        echo ""
        brew audit --cask "$CASK_FILE"
        echo ""
        echo "✓ Audit completed"
        ;;

    style)
        echo "🎨 Checking code style..."
        echo ""
        brew style "$CASK_FILE"
        echo ""
        echo "✓ Style check completed"
        ;;

    install)
        echo "📦 Installing GitBar from local cask..."
        echo ""
        brew install --cask "$CASK_FILE"
        echo ""
        echo "✓ Installation completed"
        echo ""
        echo "Testing installation:"
        if [ -d "/Applications/GitBar.app" ]; then
            echo "✓ GitBar.app found in /Applications"
            echo ""
            echo "App Info:"
            /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" \
                "/Applications/GitBar.app/Contents/Info.plist" 2>/dev/null || echo "  Could not read version"
        else
            echo "❌ GitBar.app not found in /Applications"
            exit 1
        fi
        ;;

    uninstall)
        echo "🗑️  Uninstalling GitBar..."
        echo ""
        brew uninstall --cask gitbar
        echo ""
        echo "✓ Uninstall completed"
        ;;

    reinstall)
        echo "🔄 Reinstalling GitBar from local cask..."
        echo ""

        # Uninstall if already installed
        if brew list --cask gitbar &> /dev/null; then
            echo "Removing existing installation..."
            brew uninstall --cask gitbar
        fi

        echo ""
        echo "Installing from local cask..."
        brew install --cask "$CASK_FILE"
        echo ""
        echo "✓ Reinstall completed"
        ;;

    info)
        echo "ℹ️  Cask Information:"
        echo ""
        cat "$CASK_FILE"
        ;;

    sha256)
        echo "🔐 Calculate SHA256 for DMG"
        echo ""

        # Extract version from cask file
        VERSION=$(grep -m1 'version "' "$CASK_FILE" | sed 's/.*version "\(.*\)".*/\1/')
        echo "Version from cask: $VERSION"
        echo ""

        # Prompt for DMG location
        read -p "Enter path to GitBar-v${VERSION}.dmg (or press Enter for build/GitBar-v${VERSION}.dmg): " DMG_PATH

        if [ -z "$DMG_PATH" ]; then
            DMG_PATH="$PROJECT_DIR/build/GitBar-v${VERSION}.dmg"
        fi

        if [ ! -f "$DMG_PATH" ]; then
            echo "❌ Error: DMG not found at $DMG_PATH"
            echo ""
            echo "To calculate SHA256 from GitHub release:"
            echo "  curl -L -o GitBar-v${VERSION}.dmg \\"
            echo "    https://github.com/yourusername/gitbar/releases/download/v${VERSION}/GitBar-v${VERSION}.dmg"
            echo "  shasum -a 256 GitBar-v${VERSION}.dmg"
            exit 1
        fi

        echo "Calculating SHA256 for: $DMG_PATH"
        echo ""
        SHA256=$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')
        echo "SHA256: $SHA256"
        echo ""
        echo "Update your cask file with:"
        echo "  sha256 \"$SHA256\""
        ;;

    test)
        echo "🧪 Running full test suite..."
        echo ""

        echo "1. Auditing cask..."
        brew audit --cask "$CASK_FILE"
        echo "✓ Audit passed"
        echo ""

        echo "2. Checking style..."
        brew style "$CASK_FILE"
        echo "✓ Style check passed"
        echo ""

        echo "3. Installing cask..."
        brew install --cask "$CASK_FILE"
        echo "✓ Installation successful"
        echo ""

        echo "4. Verifying installation..."
        if [ -d "/Applications/GitBar.app" ]; then
            echo "✓ App installed correctly"
        else
            echo "❌ App not found"
            exit 1
        fi
        echo ""

        echo "5. Testing launch..."
        echo "(Opening app for 3 seconds...)"
        open /Applications/GitBar.app
        sleep 3
        killall GitBar 2>/dev/null || true
        echo "✓ App launched successfully"
        echo ""

        echo "6. Uninstalling..."
        brew uninstall --cask gitbar
        echo "✓ Uninstall successful"
        echo ""

        echo "🎉 All tests passed!"
        ;;

    help|*)
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  audit      - Run Homebrew audit on the cask"
        echo "  style      - Check cask formatting and style"
        echo "  install    - Install GitBar from local cask"
        echo "  uninstall  - Uninstall GitBar"
        echo "  reinstall  - Uninstall then install from local cask"
        echo "  info       - Display cask file contents"
        echo "  sha256     - Calculate SHA256 for DMG file"
        echo "  test       - Run full test suite (audit, install, verify, uninstall)"
        echo "  help       - Show this help message"
        echo ""
        echo "Examples:"
        echo "  $0 test        # Run full test suite"
        echo "  $0 install     # Install from local cask"
        echo "  $0 sha256      # Calculate DMG checksum"
        ;;
esac
