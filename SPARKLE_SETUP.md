# Sparkle Auto-Update Setup Guide

This document describes how to configure and use Sparkle 2 for automatic app updates in GitBar.

## Overview

GitBar uses [Sparkle 2](https://sparkle-project.org/) for automatic software updates. Updates are distributed via GitHub Releases with EdDSA signature verification.

## Setup Steps

### 1. Add Sparkle Framework

**Option A: Swift Package Manager (Recommended)**

1. Open `GitBar.xcodeproj` in Xcode
2. Select the project in the navigator
3. Select the "GitBar" target
4. Go to "Package Dependencies" tab
5. Click "+" to add a package
6. Enter: `https://github.com/sparkle-project/Sparkle`
7. Select version: 2.x (up to next major)
8. Click "Add Package"
9. Select "Sparkle" library and add to "GitBar" target

**Option B: Manual Framework**

Download the latest Sparkle 2 release from:
https://github.com/sparkle-project/Sparkle/releases

### 2. Generate EdDSA Keys

Sparkle uses EdDSA signatures to ensure update authenticity.

```bash
# Download generate_keys tool from Sparkle release
cd ~/Downloads/Sparkle-2.x.x
./bin/generate_keys

# Output will show:
# Public key: YOUR_PUBLIC_KEY_HERE
# Private key saved to: ./sparkle_private_key
```

**Important:**
- Save the private key securely (e.g., GitHub Secrets as `SPARKLE_PRIVATE_KEY`)
- Add public key to `GitBar/Info.plist` under `SUPublicEDKey`
- **Never commit the private key to git**

### 3. Configure Info.plist

Already configured in `GitBar/Info.plist`:

```xml
<key>SUFeedURL</key>
<string>https://github.com/yourusername/gitbar/releases/latest/download/appcast.xml</string>
<key>SUPublicEDKey</key>
<string>YOUR_PUBLIC_KEY_HERE</string>
<key>SUEnableAutomaticChecks</key>
<true/>
```

Replace:
- `yourusername` with your GitHub username
- `YOUR_PUBLIC_KEY_HERE` with the public key from step 2

### 4. Build and Sign the App

```bash
# Development build (no signing)
xcodebuild -project GitBar.xcodeproj \
  -scheme GitBar \
  -configuration Debug \
  build

# Release build (with Developer ID signing)
xcodebuild -project GitBar.xcodeproj \
  -scheme GitBar \
  -configuration Release \
  build

# Archive for distribution
xcodebuild -project GitBar.xcodeproj \
  -scheme GitBar \
  -configuration Release \
  -archivePath ./build/GitBar.xcarchive \
  archive

# Export signed app
xcodebuild -exportArchive \
  -archivePath ./build/GitBar.xcarchive \
  -exportPath ./build/Release \
  -exportOptionsPlist exportOptions.plist
```

### 5. Create Update Package

```bash
# Create zip of the signed app
cd build/Release
zip -r GitBar.zip GitBar.app

# Get file size for appcast
ls -l GitBar.zip
```

### 6. Generate Appcast

Use Sparkle's `generate_appcast` tool:

```bash
# Download and extract Sparkle
cd ~/Downloads/Sparkle-2.x.x

# Run generate_appcast
./bin/generate_appcast \
  --ed-key-file /path/to/sparkle_private_key \
  /path/to/gitbar/releases/

# This will:
# 1. Scan all .zip files in the directory
# 2. Generate EdDSA signatures
# 3. Create/update appcast.xml with proper metadata
```

### 7. Release Workflow

**Manual Release:**

1. Build and sign the app
2. Create zip file
3. Generate appcast with `generate_appcast`
4. Create GitHub release with tag (e.g., `v1.0.1`)
5. Upload `GitBar.zip` to release
6. Upload `appcast.xml` to release

**Automated GitHub Action:**

```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3

      - name: Build app
        run: |
          xcodebuild -project GitBar.xcodeproj \
            -scheme GitBar \
            -configuration Release \
            -archivePath ./build/GitBar.xcarchive \
            archive

      - name: Export app
        run: |
          xcodebuild -exportArchive \
            -archivePath ./build/GitBar.xcarchive \
            -exportPath ./build/Release \
            -exportOptionsPlist exportOptions.plist

      - name: Create zip
        run: |
          cd build/Release
          zip -r GitBar.zip GitBar.app

      - name: Setup Sparkle
        run: |
          curl -L -o sparkle.tar.xz https://github.com/sparkle-project/Sparkle/releases/download/2.x.x/Sparkle-2.x.x.tar.xz
          tar -xf sparkle.tar.xz

      - name: Generate appcast
        env:
          SPARKLE_PRIVATE_KEY: ${{ secrets.SPARKLE_PRIVATE_KEY }}
        run: |
          echo "$SPARKLE_PRIVATE_KEY" > private_key
          ./bin/generate_appcast \
            --ed-key-file private_key \
            ./build/Release/
          rm private_key

      - name: Create Release
        uses: softprops/action-gh-release@v1
        with:
          files: |
            build/Release/GitBar.zip
            build/Release/appcast.xml
          draft: false
          prerelease: false
```

## Testing Updates

### Test v1.0.0 to v1.0.1 Update Flow

1. **Build v1.0.0:**
   ```bash
   # Set version to 1.0.0 in project settings
   # Build and run the app
   ```

2. **Create v1.0.1 release:**
   - Update version to 1.0.1 in project
   - Build and create zip
   - Generate appcast
   - Upload to GitHub releases

3. **Test update:**
   - Launch v1.0.0 app
   - Open Settings → Check for updates
   - Should detect v1.0.1
   - Click "Install Update"
   - Verify app restarts and shows v1.0.1

### Local Testing

For local testing without GitHub:

1. Set up local HTTP server:
   ```bash
   cd /path/to/releases
   python3 -m http.server 8080
   ```

2. Update `SUFeedURL` in Info.plist:
   ```xml
   <string>http://localhost:8080/appcast.xml</string>
   ```

3. Test the update flow

## Update Settings

GitBar provides these update controls in Settings:

- **Check for updates automatically** (toggle)
  - When enabled: Checks daily for updates
  - When disabled: Only manual checks via "Check Now"

- **Check Now** (button)
  - Manually trigger update check
  - Shows last check time

- **Last checked** (status)
  - Displays relative time of last update check

## Troubleshooting

### Updates not appearing

1. Check `SUFeedURL` is correct in Info.plist
2. Verify appcast.xml is accessible at the feed URL
3. Check Xcode console for Sparkle debug logs
4. Ensure version numbers follow semantic versioning

### Signature verification fails

1. Verify public key in Info.plist matches private key used to sign
2. Ensure appcast was generated with `generate_appcast` tool
3. Check `sparkle:edSignature` attribute is present in appcast.xml

### App doesn't restart after update

1. Check app is signed with hardened runtime
2. Verify entitlements include necessary permissions
3. Ensure app bundle structure is correct after export

## Security Considerations

- **Private Key:** Store private key in GitHub Secrets, never commit to repo
- **Public Key:** Safe to include in Info.plist and commit
- **HTTPS:** Always use HTTPS for feed URL in production
- **Code Signing:** App must be properly signed with Developer ID
- **Notarization:** Notarize app with Apple for Gatekeeper approval

## Resources

- [Sparkle Documentation](https://sparkle-project.org/documentation/)
- [Sparkle GitHub](https://github.com/sparkle-project/Sparkle)
- [EdDSA Signing Guide](https://sparkle-project.org/documentation/signing/)
- [Appcast Format](https://sparkle-project.org/documentation/publishing/)
