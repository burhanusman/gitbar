# Build and Release Guide

This document describes how to build, sign, notarize, and distribute GitBar.

## Prerequisites

### 1. Apple Developer Account
- Enroll in the [Apple Developer Program](https://developer.apple.com/programs/)
- Required for creating Developer ID certificates and notarizing apps

### 2. Developer ID Application Certificate

Install your Developer ID Application certificate in Keychain:

1. Go to [Apple Developer Certificates](https://developer.apple.com/account/resources/certificates/list)
2. Create a new certificate (Developer ID Application)
3. Download and install it in your Keychain

To verify your certificate is installed:
```bash
security find-identity -v -p codesigning
```

Look for an identity like:
```
1) XXXXXXXXXX "Developer ID Application: Your Name (TEAM_ID)"
```

### 3. Configure Notarization Credentials

Store your Apple ID credentials in Keychain for use with `notarytool`:

```bash
xcrun notarytool store-credentials "gitbar-notarytool" \
    --apple-id "your-apple-id@example.com" \
    --team-id "YOUR_TEAM_ID" \
    --password "your-app-specific-password"
```

**Important:** Use an app-specific password, not your regular Apple ID password.
Generate one at [appleid.apple.com](https://appleid.apple.com) → Security → App-Specific Passwords.

### 4. Update Xcode Project Settings

Before building for release, update the following in `GitBar.xcodeproj`:

1. Set your **Development Team** ID in Release configuration
2. Verify **Code Signing Identity** is set to "Developer ID Application"

You can do this via Xcode:
- Open `GitBar.xcodeproj`
- Select the GitBar target → Signing & Capabilities
- For Release configuration: Set Team and ensure Manual signing is selected

Or edit `GitBar.xcodeproj/project.pbxproj` directly:
```xml
DEVELOPMENT_TEAM = YOUR_TEAM_ID;
CODE_SIGN_IDENTITY = "Developer ID Application";
```

## Development Build

For local development with automatic code signing:

```bash
xcodebuild -project GitBar.xcodeproj -scheme GitBar -configuration Debug
```

The Debug configuration uses automatic signing with "Apple Development" identity.

## Release Build

### Option 1: Automated Build Script (Recommended)

The easiest way to create a release build:

```bash
./scripts/build-release.sh
```

This script will:
1. Build the app with Release configuration
2. Sign the app with Developer ID certificate and hardened runtime
3. Create a distributable archive
4. Submit for notarization
5. Staple the notarization ticket
6. Create a DMG for distribution
7. Verify code signature and Gatekeeper assessment

The final app and DMG will be in the `build/` directory.

**Options:**
- `--skip-notarization`: Build and sign without notarizing (for testing)
- `--skip-build`: Only notarize an existing build

### Option 2: Manual Build and Notarization

If you prefer to do it step by step:

#### 1. Build and Archive

```bash
xcodebuild -project GitBar.xcodeproj \
    -scheme GitBar \
    -configuration Release \
    -archivePath build/GitBar.xcarchive \
    archive
```

#### 2. Export Signed App

Create `ExportOptions.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>stripSwiftSymbols</key>
    <true/>
</dict>
</plist>
```

Export:
```bash
xcodebuild -exportArchive \
    -archivePath build/GitBar.xcarchive \
    -exportPath build \
    -exportOptionsPlist ExportOptions.plist
```

#### 3. Verify Code Signature

```bash
codesign --verify --deep --strict --verbose=2 build/GitBar.app
codesign -dv --verbose=4 build/GitBar.app
```

#### 4. Notarize

```bash
./scripts/notarize.sh build/GitBar.app
```

Or manually:
```bash
# Create archive
ditto -c -k --keepParent build/GitBar.app build/GitBar.zip

# Submit for notarization
xcrun notarytool submit build/GitBar.zip \
    --keychain-profile "gitbar-notarytool" \
    --wait

# Staple ticket
xcrun stapler staple build/GitBar.app
```

#### 5. Verify Gatekeeper Assessment

```bash
spctl --assess --verbose=4 --type execute build/GitBar.app
```

Should output:
```
build/GitBar.app: accepted
source=Notarized Developer ID
```

## Code Signing Configuration

### Entitlements (`GitBar/GitBar.entitlements`)

The app uses the following entitlements:

- **Hardened Runtime**: Required for notarization
  - All hardened runtime exceptions are disabled for maximum security
- **App Sandbox**: Sandboxed for enhanced security
- **File Access**: User-selected read-write access for git repositories
- **Network Client**: Required for update checks
- **Bookmarks**: App-scoped bookmarks for persisting folder selections

### Xcode Build Settings

**Debug Configuration:**
- `CODE_SIGN_STYLE = Automatic`
- `CODE_SIGN_IDENTITY = "Apple Development"`
- `ENABLE_HARDENED_RUNTIME = YES`

**Release Configuration:**
- `CODE_SIGN_STYLE = Manual`
- `CODE_SIGN_IDENTITY = "Developer ID Application"`
- `DEVELOPMENT_TEAM = YOUR_TEAM_ID`
- `ENABLE_HARDENED_RUNTIME = YES`

## Distribution

After building and notarizing:

1. **DMG Creation**: The build script automatically creates a DMG
2. **Upload**: Distribute via your preferred method (website, GitHub releases, etc.)
3. **First Launch**: Users can open the app without Gatekeeper warnings

### Manual DMG Creation

```bash
hdiutil create -volname "GitBar" \
    -srcfolder build/GitBar.app \
    -ov -format UDZO \
    build/GitBar.dmg
```

## Troubleshooting

### Signing Issues

**Error: "No signing certificate found"**
- Verify your Developer ID certificate is installed: `security find-identity -v -p codesigning`
- Ensure the certificate is valid and not expired

**Error: "User interaction is not allowed"**
- Unlock your Keychain: `security unlock-keychain ~/Library/Keychains/login.keychain-db`

### Notarization Issues

**Error: "Invalid credentials"**
- Re-run `xcrun notarytool store-credentials` with correct credentials
- Ensure you're using an app-specific password, not your Apple ID password

**Error: "The binary is not signed with a valid Developer ID certificate"**
- Verify signing with: `codesign -dv --verbose=4 build/GitBar.app`
- Ensure you're using "Developer ID Application" not "Apple Development"

### Gatekeeper Issues

**Error: "app is damaged and can't be opened"**
- The app needs to be notarized or the com.apple.quarantine xattr needs to be removed
- Run: `xattr -cr build/GitBar.app` (only for local testing!)

### Check Notarization Status

```bash
# List recent submissions
xcrun notarytool history --keychain-profile "gitbar-notarytool"

# Get detailed info about a submission
xcrun notarytool info SUBMISSION_ID --keychain-profile "gitbar-notarytool"

# Get notarization log
xcrun notarytool log SUBMISSION_ID --keychain-profile "gitbar-notarytool"
```

## References

- [Notarizing macOS Software](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [Code Signing Guide](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/Introduction/Introduction.html)
- [Hardened Runtime](https://developer.apple.com/documentation/security/hardened_runtime)
- [App Sandbox](https://developer.apple.com/documentation/security/app_sandbox)
