#!/bin/bash
set -e

# Notarization script for GitBar
# Uses xcrun notarytool to submit the app for notarization
# Credentials should be stored in Keychain using:
# xcrun notarytool store-credentials "gitbar-notarytool" --apple-id "YOUR_APPLE_ID" --team-id "YOUR_TEAM_ID" --password "APP_SPECIFIC_PASSWORD"

APP_PATH="$1"
KEYCHAIN_PROFILE="${2:-gitbar-notarytool}"

if [ -z "$APP_PATH" ]; then
    echo "Usage: $0 <path-to-app> [keychain-profile]"
    echo "Example: $0 build/GitBar.app gitbar-notarytool"
    exit 1
fi

if [ ! -d "$APP_PATH" ]; then
    echo "Error: App not found at $APP_PATH"
    exit 1
fi

echo "📦 Creating archive for notarization..."
ARCHIVE_PATH="${APP_PATH%.app}.zip"
ditto -c -k --keepParent "$APP_PATH" "$ARCHIVE_PATH"

echo "🚀 Submitting for notarization..."
xcrun notarytool submit "$ARCHIVE_PATH" \
    --keychain-profile "$KEYCHAIN_PROFILE" \
    --wait

echo "✅ Notarization complete!"

echo "🔖 Stapling notarization ticket to app..."
xcrun stapler staple "$APP_PATH"

echo "✅ App successfully notarized and stapled!"
echo "📍 Notarized app: $APP_PATH"

# Clean up archive
rm "$ARCHIVE_PATH"
