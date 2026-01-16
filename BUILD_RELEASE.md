# GitBar Build and Release Guide

Complete guide for building, signing, and releasing GitBar with Sparkle auto-updates.

## Prerequisites

- macOS 13.0 or later
- Xcode 15.0 or later
- Apple Developer ID certificate (for distribution)
- GitHub account with repository access
- Homebrew (for installing tools)

### Install Required Tools

```bash
# Install create-dmg for DMG creation
brew install create-dmg
```

## Initial Setup

### 1. Add Sparkle Framework

Run the helper script or follow manual instructions:

```bash
./add_sparkle_package.sh
```

Or add manually in Xcode:
1. Open `GitBar.xcodeproj`
2. Project Settings → Package Dependencies
3. Add: `https://github.com/sparkle-project/Sparkle` (version 2.x)

### 2. Generate Sparkle Signing Keys

```bash
# Download Sparkle tools
curl -L -o Sparkle.tar.xz \
  https://github.com/sparkle-project/Sparkle/releases/download/2.5.2/Sparkle-2.5.2.tar.xz
tar -xf Sparkle.tar.xz

# Generate EdDSA key pair
./bin/generate_keys

# Output shows:
# A key has been generated and saved in your keychain. Add the `SUPublicEDKey` key to
# your Info.plist and copy this value to it:
# [PUBLIC_KEY_HERE]
```

**Important:**
- Public key → Add to `GitBar/Info.plist` under `SUPublicEDKey`
- Private key → Save to GitHub Secrets as `SPARKLE_PRIVATE_KEY`
- Keep Sparkle tools directory for later use with `generate_appcast`

### 3. Configure Info.plist

Update `GitBar/Info.plist` with your values:

```xml
<key>SUFeedURL</key>
<string>https://github.com/YOUR_USERNAME/gitbar/releases/latest/download/appcast.xml</string>
<key>SUPublicEDKey</key>
<string>YOUR_PUBLIC_KEY_FROM_GENERATE_KEYS</string>
```

## Development Builds

### Local Development (No Signing)

```bash
xcodebuild -project GitBar.xcodeproj \
  -scheme GitBar \
  -configuration Debug \
  clean build
```

Built app: `build/Debug/GitBar.app`

### Run Development Build

```bash
open build/Debug/GitBar.app
```

## Release Builds

### 1. Update Version Numbers

Edit project settings or use command line:

```bash
# Using PlistBuddy
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString 1.0.1" GitBar/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion 1" GitBar/Info.plist
```

Or in Xcode:
- Select project → Target → General
- Update Version (e.g., 1.0.1)
- Update Build (e.g., 1)

### 2. Create Archive

```bash
xcodebuild -project GitBar.xcodeproj \
  -scheme GitBar \
  -configuration Release \
  -archivePath ./build/GitBar.xcarchive \
  archive
```

### 3. Export Signed App

Create `exportOptions.plist`:

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
    <key>signingCertificate</key>
    <string>Developer ID Application</string>
</dict>
</plist>
```

Export the archive:

```bash
xcodebuild -exportArchive \
  -archivePath ./build/GitBar.xcarchive \
  -exportPath ./build/Release \
  -exportOptionsPlist exportOptions.plist
```

### 4. Notarize with Apple

```bash
# Store credentials (one time)
xcrun notarytool store-credentials "gitbar-notary" \
  --apple-id "your@email.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "app-specific-password"

# Create zip for notarization
cd build/Release
zip -r GitBar-notarize.zip GitBar.app

# Submit for notarization
xcrun notarytool submit GitBar-notarize.zip \
  --keychain-profile "gitbar-notary" \
  --wait

# Staple notarization ticket
xcrun stapler staple GitBar.app

# Verify
spctl -a -vvv -t install GitBar.app
```

### 5. Create DMG Installer

GitBar uses `create-dmg` to create professional DMG installers with drag-to-Applications UX:

```bash
# Create DMG with custom background and layout
./scripts/create-dmg.sh build/Release/GitBar.app build

# This creates: build/GitBar-v1.0.0.dmg
```

**Alternative: Create ZIP for Distribution**

```bash
# Create final zip for distribution
cd build/Release
zip -r GitBar.zip GitBar.app

# Get file size (needed for appcast)
ls -l GitBar.zip | awk '{print $5}'
```

See [DMG_DISTRIBUTION.md](DMG_DISTRIBUTION.md) for detailed DMG creation and customization guide.

## Creating a Release

### 1. Generate Appcast

```bash
# Navigate to Sparkle tools directory
cd ~/Downloads/Sparkle-2.5.2

# Generate appcast with signatures
./bin/generate_appcast \
  --ed-key-file /path/to/sparkle_private_key \
  /path/to/gitbar/build/Release/

# This creates/updates appcast.xml with:
# - File size
# - EdDSA signature
# - Version metadata
```

### 2. Create GitHub Release

```bash
# Create and push version tag
git tag -a v1.0.1 -m "Release version 1.0.1"
git push origin v1.0.1

# Create GitHub release (using gh CLI)
gh release create v1.0.1 \
  --title "GitBar v1.0.1" \
  --notes "Release notes here..." \
  build/Release/GitBar.zip \
  build/Release/appcast.xml
```

Or manually:
1. Go to GitHub → Releases → Draft new release
2. Tag: `v1.0.1`
3. Title: `GitBar v1.0.1`
4. Description: Release notes
5. Upload: `GitBar.zip` and `appcast.xml`
6. Publish release

### 3. Test Update

1. Install previous version (e.g., v1.0.0)
2. Launch app
3. Open Settings
4. Click "Check for Updates"
5. Verify update prompt appears
6. Install update and verify app restarts with v1.0.1

## Automated Release (GitHub Actions)

Create `.github/workflows/release.yml`:

```yaml
name: Release GitBar

on:
  push:
    tags:
      - 'v*'

jobs:
  build-and-release:
    runs-on: macos-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Xcode
        uses: maxim-lobanov/setup-xcode@v1
        with:
          xcode-version: latest-stable

      - name: Import signing certificate
        env:
          CERTIFICATE_BASE64: ${{ secrets.CERTIFICATE_BASE64 }}
          CERTIFICATE_PASSWORD: ${{ secrets.CERTIFICATE_PASSWORD }}
        run: |
          echo $CERTIFICATE_BASE64 | base64 --decode > certificate.p12
          security create-keychain -p actions temp.keychain
          security default-keychain -s temp.keychain
          security unlock-keychain -p actions temp.keychain
          security import certificate.p12 -k temp.keychain \
            -P $CERTIFICATE_PASSWORD -T /usr/bin/codesign
          security set-key-partition-list -S apple-tool:,apple: \
            -s -k actions temp.keychain
          rm certificate.p12

      - name: Build and archive
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

      - name: Notarize app
        env:
          APPLE_ID: ${{ secrets.APPLE_ID }}
          APPLE_PASSWORD: ${{ secrets.APPLE_APP_PASSWORD }}
          TEAM_ID: ${{ secrets.TEAM_ID }}
        run: |
          cd build/Release
          zip -r GitBar-notarize.zip GitBar.app
          xcrun notarytool submit GitBar-notarize.zip \
            --apple-id "$APPLE_ID" \
            --password "$APPLE_PASSWORD" \
            --team-id "$TEAM_ID" \
            --wait
          xcrun stapler staple GitBar.app
          rm GitBar-notarize.zip

      - name: Create distribution zip
        run: |
          cd build/Release
          zip -r GitBar.zip GitBar.app

      - name: Setup Sparkle
        run: |
          curl -L -o Sparkle.tar.xz \
            https://github.com/sparkle-project/Sparkle/releases/download/2.5.2/Sparkle-2.5.2.tar.xz
          tar -xf Sparkle.tar.xz

      - name: Generate appcast
        env:
          SPARKLE_PRIVATE_KEY: ${{ secrets.SPARKLE_PRIVATE_KEY }}
        run: |
          echo "$SPARKLE_PRIVATE_KEY" > private_key
          chmod 600 private_key
          ./bin/generate_appcast \
            --ed-key-file private_key \
            ./build/Release/
          rm private_key

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v1
        with:
          files: |
            build/Release/GitBar.zip
            build/Release/appcast.xml
          draft: false
          prerelease: false
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### Required GitHub Secrets

Set these in GitHub → Settings → Secrets and variables → Actions:

- `CERTIFICATE_BASE64`: Base64 encoded Developer ID certificate (.p12)
- `CERTIFICATE_PASSWORD`: Password for the certificate
- `APPLE_ID`: Apple ID email
- `APPLE_APP_PASSWORD`: App-specific password from appleid.apple.com
- `TEAM_ID`: Your Apple Developer Team ID
- `SPARKLE_PRIVATE_KEY`: Private key from `generate_keys`

## Troubleshooting

### Build fails with Sparkle not found

1. Ensure Sparkle package is added in Xcode
2. Check Package Dependencies tab shows Sparkle 2.x
3. Try: Product → Clean Build Folder
4. Try: File → Packages → Resolve Package Versions

### Code signing fails

1. Check Developer ID certificate is installed: `security find-identity -v`
2. Verify DEVELOPMENT_TEAM is set correctly
3. Check entitlements file is valid

### Notarization fails

1. Verify app is signed with hardened runtime: `codesign -dv --verbose=4 GitBar.app`
2. Check for signing issues: `spctl -a -vvv -t install GitBar.app`
3. View notarization logs: `xcrun notarytool log <submission-id>`

### Updates not detected

1. Check appcast.xml is accessible at SUFeedURL
2. Verify EdDSA signature in appcast matches public key in Info.plist
3. Check version numbers follow semantic versioning (1.0.0, 1.0.1, etc.)
4. Enable Sparkle debug logging in development

## Version Numbering

Follow semantic versioning:

- **Major.Minor.Patch** (e.g., 1.2.3)
- Major: Breaking changes
- Minor: New features, backwards compatible
- Patch: Bug fixes only

Examples:
- 1.0.0 → Initial release
- 1.0.1 → Bug fixes
- 1.1.0 → New features
- 2.0.0 → Major rewrite/breaking changes

## Automated Release Script

For a complete automated release workflow (build + sign + notarize + DMG):

```bash
./scripts/build-release.sh
```

This handles:
- Building in Release configuration
- Code signing with Developer ID
- Notarizing app bundle
- Creating and signing DMG
- Notarizing DMG
- Verification steps

## Resources

- [DMG Distribution Guide](DMG_DISTRIBUTION.md)
- [Sparkle Setup](SPARKLE_SETUP.md)
- [Build Guide](BUILD.md)
- [Xcode Build Settings](https://developer.apple.com/documentation/xcode/build-settings-reference)
- [Notarization Guide](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
