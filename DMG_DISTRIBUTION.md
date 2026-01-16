# DMG Distribution Guide

Complete guide for creating and distributing GitBar DMG installers with professional drag-to-Applications UX.

## Overview

GitBar uses `create-dmg` to create beautiful, user-friendly DMG installers that provide:
- Custom background with installation instructions
- Drag-to-Applications folder layout
- App icon and Applications folder shortcut
- Code signing and notarization support
- Proper filename format: `GitBar-v1.0.0.dmg`

## Prerequisites

### Install create-dmg

```bash
brew install create-dmg
```

### Dependencies

- macOS 13.0 or later
- Xcode with command-line tools
- Developer ID certificate (for signed releases)
- Notarization credentials (for distribution)

## DMG Creation Workflow

### 1. Build the App

Build a release version of GitBar:

```bash
# Development build (no signing)
xcodebuild -project GitBar.xcodeproj \
  -scheme GitBar \
  -configuration Release \
  -derivedDataPath build/DerivedData \
  clean build \
  CONFIGURATION_BUILD_DIR=build/Release \
  CODE_SIGN_IDENTITY="-"

# Or use the full release script
./scripts/build-release.sh --skip-notarization
```

### 2. Create DMG

Use the dedicated DMG creation script:

```bash
./scripts/create-dmg.sh build/Release/GitBar.app build
```

This will:
1. Generate DMG background image (if not exists)
2. Extract version from app's Info.plist
3. Create DMG with filename: `GitBar-v{VERSION}.dmg`
4. Add Applications folder symlink
5. Configure window size and icon positions
6. Verify DMG integrity

**Output:** `build/GitBar-v1.0.0.dmg` (typically ~500KB)

### 3. Sign and Notarize DMG (Production)

For production releases, the DMG must be signed and notarized:

```bash
# Sign the DMG
codesign --sign "Developer ID Application" \
  --timestamp \
  build/GitBar-v1.0.0.dmg

# Notarize the DMG
cd build
zip GitBar-dmg-notarize.zip GitBar-v1.0.0.dmg

xcrun notarytool submit GitBar-dmg-notarize.zip \
  --keychain-profile "gitbar-notarytool" \
  --wait

# Staple notarization ticket
xcrun stapler staple GitBar-v1.0.0.dmg

# Verify
spctl -a -vv -t install GitBar-v1.0.0.dmg
```

### 4. Complete Release Script

For a fully automated release (build + sign + notarize + DMG):

```bash
./scripts/build-release.sh
```

This script:
1. Builds the app in Release mode
2. Signs with Developer ID
3. Notarizes the app bundle
4. Creates signed DMG
5. Notarizes the DMG
6. Staples notarization tickets

## DMG Customization

### Background Image

The DMG background is generated programmatically at `dmg-resources/background.png` (660x400px):

```bash
./generate_dmg_background.swift
```

Features:
- Installation instruction text
- Arrow showing drag direction
- Icon placeholders for app and Applications folder
- Professional gradient background

To customize, edit `generate_dmg_background.swift` and regenerate.

### Layout Configuration

Edit `scripts/create-dmg.sh` to adjust DMG appearance:

```bash
create-dmg \
  --volname "GitBar" \
  --background "dmg-resources/background.png" \
  --window-pos 200 120 \
  --window-size 660 400 \
  --icon-size 100 \
  --icon "GitBar.app" 130 185 \        # App icon position
  --app-drop-link 530 185 \            # Applications folder position
  --hide-extension "GitBar.app" \
  --skip-jenkins \                      # Avoid AppleScript hanging
  "$DMG_PATH" \
  "$APP_PATH"
```

### Version Filename

DMG filename automatically includes version from `Info.plist`:

- Version 1.0.0 → `GitBar-v1.0.0.dmg`
- Version 1.2.3 → `GitBar-v1.2.3.dmg`

## Testing DMG Installation

### Local Testing

1. Mount the DMG:
   ```bash
   open build/GitBar-v1.0.0.dmg
   ```

2. Verify:
   - DMG window opens with background image
   - GitBar app icon is visible
   - Applications folder shortcut is present
   - Arrow indicates drag direction
   - Window is properly sized (660x400)

3. Test installation:
   - Drag GitBar.app to Applications folder
   - Launch from Applications
   - Verify app runs correctly

### Clean Installation Test

Test on a fresh macOS 13+ installation:

1. Copy DMG to test machine
2. Double-click to mount
3. Drag to Applications
4. Launch app
5. Verify Gatekeeper acceptance (for signed DMG)

### Automated Verification

```bash
# Verify DMG integrity
hdiutil verify build/GitBar-v1.0.0.dmg

# Check DMG signature (if signed)
codesign -dv --verbose=4 build/GitBar-v1.0.0.dmg

# Test Gatekeeper (for notarized DMG)
spctl -a -vv -t install build/GitBar-v1.0.0.dmg
```

## Distribution Workflow

### GitHub Releases

1. Create and push version tag:
   ```bash
   git tag -a v1.0.0 -m "Release version 1.0.0"
   git push origin v1.0.0
   ```

2. Create GitHub release:
   ```bash
   gh release create v1.0.0 \
     --title "GitBar v1.0.0" \
     --notes "Release notes..." \
     build/GitBar-v1.0.0.dmg \
     appcast.xml
   ```

3. Users download DMG from GitHub Releases page

### Direct Distribution

For direct downloads:

1. Upload DMG to hosting service
2. Provide download link on website
3. Include installation instructions
4. Mention macOS version requirements

### Auto-Update via Sparkle

DMG is used for Sparkle auto-updates:

1. Generate appcast with Sparkle tools:
   ```bash
   ./Sparkle-2.5.2/bin/generate_appcast \
     --ed-key-file sparkle_private_key \
     build/
   ```

2. Upload DMG and appcast.xml to GitHub Releases

3. Update `SUFeedURL` in Info.plist to point to appcast.xml

4. App checks for updates automatically

## File Size Requirements

- **Target:** < 10MB
- **Current:** ~500KB (well under target)
- **Components:**
  - App bundle: ~400KB
  - DMG overhead: ~100KB

## Troubleshooting

### DMG Creation Hangs

If `create-dmg` hangs on AppleScript:

- **Solution:** Use `--skip-jenkins` flag (already in script)
- **Trade-off:** Background positioning uses mount-time settings instead of AppleScript

### DMG Too Large

If DMG exceeds size limits:

1. Check for unnecessary resources in app bundle
2. Strip debug symbols: `strip -x GitBar.app/Contents/MacOS/GitBar`
3. Use UDZO compression (default)
4. Remove unused assets from asset catalog

### DMG Won't Mount

If DMG won't mount on user machines:

1. Verify DMG integrity: `hdiutil verify GitBar-v1.0.0.dmg`
2. Check for corruption during upload/download
3. Ensure proper compression format (UDZO)
4. Test on multiple macOS versions

### Gatekeeper Blocks Installation

If macOS blocks the app:

1. Verify app is signed: `codesign -dv GitBar.app`
2. Verify notarization: `xcrun stapler validate GitBar.app`
3. Check notarization status online
4. Ensure hardened runtime is enabled
5. Verify entitlements are correct

### DMG Background Not Showing

The `--skip-jenkins` flag means:

- Background image is included in DMG
- Icon positions are set correctly
- But AppleScript doesn't run to apply aesthetics
- Users see background when they open DMG on their machine

This is a necessary trade-off to avoid hanging during build.

## Best Practices

1. **Version Naming:** Always use semantic versioning (1.0.0, 1.1.0, 2.0.0)
2. **Testing:** Test DMG on clean macOS installation before release
3. **Signing:** Always sign and notarize for production distribution
4. **File Size:** Keep DMG under 10MB for fast downloads
5. **Documentation:** Include README or installation guide
6. **Updates:** Keep appcast.xml updated for Sparkle auto-updates
7. **Checksums:** Provide SHA256 checksums for verification

## Resources

- [create-dmg GitHub](https://github.com/create-dmg/create-dmg)
- [Apple Code Signing Guide](https://developer.apple.com/support/code-signing/)
- [Apple Notarization Guide](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [Sparkle Framework](https://sparkle-project.org/)

## See Also

- [BUILD_RELEASE.md](BUILD_RELEASE.md) - Complete release build workflow
- [SPARKLE_SETUP.md](SPARKLE_SETUP.md) - Auto-update configuration
- [BUILD.md](BUILD.md) - Development build instructions
