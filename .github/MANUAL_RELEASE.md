# Manual Release Process

This guide provides step-by-step instructions for releasing GitBar manually, as a backup to the automated GitHub Actions workflow.

## When to Use Manual Release

Use this process when:
- GitHub Actions is unavailable
- You need to troubleshoot the automated workflow
- You want to create a local test release
- You're releasing from a machine without Actions access

## Prerequisites

Ensure you have all prerequisites installed and configured:

```bash
# Check Xcode is installed
xcodebuild -version

# Install create-dmg
brew install create-dmg

# Verify Developer ID certificate
security find-identity -v -p codesigning | grep "Developer ID Application"

# Verify notarization credentials
xcrun notarytool history --keychain-profile gitbar-notarytool
```

## Step 1: Prepare for Release

### 1.1 Update Version Number

Choose your version number (e.g., `1.0.0`, `1.1.0`, `2.0.0-beta1`):

```bash
VERSION="1.0.0"

# Update Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" GitBar/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" GitBar/Info.plist

# Verify the change
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" GitBar/Info.plist
```

### 1.2 Commit Version Update

```bash
git add GitBar/Info.plist
git commit -m "Bump version to $VERSION"
git push origin main
```

### 1.3 Create Git Tag

```bash
# Create annotated tag
git tag -a "v$VERSION" -m "Release version $VERSION"

# Push tag to GitHub
git push origin "v$VERSION"
```

## Step 2: Build and Sign

### 2.1 Clean Build

```bash
# Remove previous builds
rm -rf build/

# Create build directory
mkdir -p build
```

### 2.2 Build with Script

Use the automated build script:

```bash
# Build, sign, and notarize
./scripts/build-release.sh

# This will:
# - Build in Release configuration
# - Sign with Developer ID
# - Notarize the app bundle
# - Create and sign DMG
# - Notarize the DMG
```

**Or build manually:**

```bash
# Build archive
xcodebuild -project GitBar.xcodeproj \
  -scheme GitBar \
  -configuration Release \
  -archivePath ./build/GitBar.xcarchive \
  archive

# Create export options
cat > build/ExportOptions.plist << 'EOF'
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
EOF

# Export signed app
xcodebuild -exportArchive \
  -archivePath ./build/GitBar.xcarchive \
  -exportPath ./build \
  -exportOptionsPlist ./build/ExportOptions.plist

# Verify signature
codesign --verify --deep --strict --verbose=2 ./build/GitBar.app
```

## Step 3: Notarize App

### 3.1 Setup Notarization Credentials (One-time)

```bash
# Store credentials in keychain
xcrun notarytool store-credentials "gitbar-notarytool" \
  --apple-id "your@email.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "xxxx-xxxx-xxxx-xxxx"
```

### 3.2 Notarize App Bundle

```bash
# Create zip for notarization
cd build
zip -r GitBar-notarize.zip GitBar.app

# Submit for notarization
xcrun notarytool submit GitBar-notarize.zip \
  --keychain-profile "gitbar-notarytool" \
  --wait

# Staple notarization ticket
xcrun stapler staple GitBar.app

# Verify notarization
spctl --assess --verbose=4 --type execute GitBar.app

# Clean up
rm GitBar-notarize.zip
cd ..
```

## Step 4: Create DMG

### 4.1 Generate DMG

```bash
# Use create-dmg script
./scripts/create-dmg.sh build/GitBar.app build

# This creates: build/GitBar-v1.0.0.dmg
```

### 4.2 Sign and Notarize DMG

```bash
VERSION="1.0.0"
DMG_PATH="build/GitBar-v${VERSION}.dmg"

# Sign DMG
codesign --sign "Developer ID Application" --timestamp "$DMG_PATH"

# Create zip for notarization
cd build
zip "GitBar-dmg-notarize.zip" "GitBar-v${VERSION}.dmg"

# Submit for notarization
xcrun notarytool submit "GitBar-dmg-notarize.zip" \
  --keychain-profile "gitbar-notarytool" \
  --wait

# Staple ticket
xcrun stapler staple "GitBar-v${VERSION}.dmg"

# Verify
spctl --assess --verbose=4 --type open --context context:primary-signature "$DMG_PATH"

# Clean up
rm GitBar-dmg-notarize.zip
cd ..
```

## Step 5: Create Distribution Archive

### 5.1 Create ZIP for Sparkle Updates

```bash
VERSION="1.0.0"

# Create zip from notarized app
cd build
zip -r "GitBar-v${VERSION}.zip" GitBar.app
cd ..
```

## Step 6: Generate Appcast

### 6.1 Download Sparkle Tools (if needed)

```bash
# Download Sparkle
curl -L -o Sparkle.tar.xz \
  https://github.com/sparkle-project/Sparkle/releases/download/2.6.4/Sparkle-2.6.4.tar.xz

# Extract
tar -xf Sparkle.tar.xz

# Make executable
chmod +x bin/generate_appcast
```

### 6.2 Generate Appcast with Signatures

```bash
VERSION="1.0.0"

# You need your Sparkle private key
# Either from: ~/Library/Application Support/Sparkle/EdDSA
# Or from your secure password manager

# Generate appcast
./bin/generate_appcast \
  --ed-key-file /path/to/sparkle_private_key \
  --download-url-prefix "https://github.com/yourusername/gitbar/releases/download/v${VERSION}/" \
  build/

# This creates/updates: build/appcast.xml
```

### 6.3 Update Repository Appcast

```bash
# Copy generated appcast to repo root
cp build/appcast.xml ./appcast.xml

# Commit
git add appcast.xml
git commit -m "Update appcast.xml for v${VERSION}"
git push origin main
```

## Step 7: Create GitHub Release

### 7.1 Using GitHub CLI (Recommended)

```bash
VERSION="1.0.0"

# Create release notes
cat > release_notes.md << EOF
## GitBar v${VERSION}

### Installation

**Option 1: Download DMG (Recommended)**
- Download GitBar-v${VERSION}.dmg
- Open the DMG and drag GitBar to Applications folder
- Launch from Applications

**Option 2: Homebrew Cask**
\`\`\`bash
brew install --cask gitbar
\`\`\`

**Option 3: Direct Download**
- Download GitBar-v${VERSION}.zip
- Extract and move to Applications folder

### Auto-Updates

GitBar includes Sparkle for automatic updates. The app will check for updates automatically and notify you when new versions are available.

### System Requirements

- macOS 13.0 (Ventura) or later
- Apple Silicon or Intel processor

---

**Full Changelog**: https://github.com/yourusername/gitbar/commits/v${VERSION}
EOF

# Create release
gh release create "v${VERSION}" \
  --title "GitBar v${VERSION}" \
  --notes-file release_notes.md \
  "build/GitBar-v${VERSION}.dmg#DMG Installer" \
  "build/GitBar-v${VERSION}.zip#Zip Archive" \
  "appcast.xml#Sparkle Appcast"

# Clean up
rm release_notes.md
```

### 7.2 Using GitHub Web Interface

1. Go to https://github.com/yourusername/gitbar/releases/new
2. **Choose a tag:** Select `v1.0.0` (or create new tag)
3. **Release title:** `GitBar v1.0.0`
4. **Description:** Add release notes (see template above)
5. **Attach files:**
   - Upload `build/GitBar-v1.0.0.dmg`
   - Upload `build/GitBar-v1.0.0.zip`
   - Upload `appcast.xml`
6. **Pre-release:** Check if beta/alpha, uncheck for stable
7. Click **Publish release**

## Step 8: Verify Release

### 8.1 Test DMG Installation

```bash
# Download DMG
curl -L -o test.dmg \
  "https://github.com/yourusername/gitbar/releases/download/v1.0.0/GitBar-v1.0.0.dmg"

# Open DMG
open test.dmg

# Manually test:
# 1. Drag to Applications
# 2. Launch app
# 3. Verify no Gatekeeper warnings
# 4. Check version in About menu
```

### 8.2 Test Appcast

```bash
# Verify appcast is accessible
curl -L "https://github.com/yourusername/gitbar/releases/latest/download/appcast.xml"

# Should return XML with:
# - Correct version number
# - Valid download URLs
# - EdDSA signature
```

### 8.3 Test Auto-Update (if previous version exists)

1. Install previous version of GitBar
2. Launch the app
3. Open Settings/Preferences
4. Click "Check for Updates"
5. Verify update notification appears
6. Test update installation
7. Verify app restarts with new version

## Verification Checklist

Before announcing the release:

- [ ] App launches without Gatekeeper warnings
- [ ] DMG is properly signed and notarized
- [ ] Version number is correct in About dialog
- [ ] All menu bar features work
- [ ] Repository sync works correctly
- [ ] Settings persist between launches
- [ ] Appcast.xml is accessible via URL
- [ ] GitHub Release has all three files (DMG, ZIP, appcast.xml)
- [ ] Release notes are complete and accurate
- [ ] Auto-update works from previous version

## Troubleshooting

### Notarization Stuck

If notarization appears stuck:

```bash
# Check submission status
xcrun notarytool history --keychain-profile gitbar-notarytool

# Get detailed logs for a submission
xcrun notarytool log <submission-id> --keychain-profile gitbar-notarytool
```

### Gatekeeper Blocks App

If Gatekeeper blocks the app after installation:

```bash
# Check signature
codesign -vvv --deep --strict build/GitBar.app

# Check notarization
spctl --assess --verbose=4 build/GitBar.app

# Check for quarantine attribute
xattr -l build/GitBar.app

# If necessary, remove quarantine (for local testing only)
xattr -d com.apple.quarantine build/GitBar.app
```

### Appcast Not Working

Verify appcast structure:

```bash
# Check appcast format
xmllint --format appcast.xml

# Verify signature
./bin/verify_signature appcast.xml \
  --ed-key-file /path/to/sparkle_public_key
```

## Emergency Rollback

If you need to rollback a release:

1. Delete the GitHub release (keep the tag)
2. Revert appcast.xml to previous version
3. Push updated appcast: `git push origin main`
4. Users will no longer see the problematic update

```bash
# Rollback appcast
git checkout HEAD~1 appcast.xml
git add appcast.xml
git commit -m "Rollback appcast to previous version"
git push origin main
```

## Resources

- [BUILD_RELEASE.md](../BUILD_RELEASE.md) - Detailed build guide
- [RELEASE_SETUP.md](RELEASE_SETUP.md) - Automated release setup
- [Apple Notarization Guide](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [Sparkle Documentation](https://sparkle-project.org/documentation/)
