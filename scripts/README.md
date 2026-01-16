# GitBar Build Scripts

This directory contains automated scripts for building, signing, and distributing GitBar.

## Scripts Overview

### build-release.sh

Complete release build workflow including signing and notarization.

**Usage:**
```bash
./scripts/build-release.sh [options]
```

**Options:**
- `--skip-notarization` - Skip Apple notarization step
- `--skip-build` - Skip Xcode build (use existing app)

**What it does:**
1. Cleans and builds app in Release configuration
2. Signs app with Developer ID certificate
3. Notarizes app bundle with Apple
4. Creates DMG installer
5. Signs and notarizes DMG
6. Verifies signatures and Gatekeeper assessment

**Output:**
- `build/GitBar.app` - Signed and notarized app
- `build/GitBar-v{VERSION}.dmg` - Signed and notarized DMG

**Example:**
```bash
# Full production release
./scripts/build-release.sh

# Build only, skip notarization (for testing)
./scripts/build-release.sh --skip-notarization
```

---

### create-dmg.sh

Creates beautiful DMG installer with drag-to-Applications UX.

**Usage:**
```bash
./scripts/create-dmg.sh [app-path] [output-dir]
```

**Parameters:**
- `app-path` - Path to GitBar.app (default: `build/GitBar.app`)
- `output-dir` - Output directory for DMG (default: `build`)

**What it does:**
1. Generates DMG background image if needed
2. Extracts version from app's Info.plist
3. Creates DMG with filename: `GitBar-v{VERSION}.dmg`
4. Configures window size and icon positions
5. Adds Applications folder symlink
6. Verifies DMG integrity

**Output:**
- `{output-dir}/GitBar-v{VERSION}.dmg` (~500KB)

**Example:**
```bash
# Create DMG from built app
./scripts/create-dmg.sh build/Release/GitBar.app build

# Output: build/GitBar-v1.0.0.dmg
```

---

### notarize.sh

Notarizes an app bundle with Apple using notarytool.

**Usage:**
```bash
./scripts/notarize.sh <path-to-app> [keychain-profile]
```

**Parameters:**
- `path-to-app` - Path to GitBar.app bundle
- `keychain-profile` - Keychain profile name (default: `gitbar-notarytool`)

**What it does:**
1. Creates ZIP archive of app
2. Submits to Apple notarization service
3. Waits for notarization to complete
4. Staples notarization ticket to app
5. Cleans up temporary files

**Prerequisites:**
Store notarization credentials in keychain first:
```bash
xcrun notarytool store-credentials "gitbar-notarytool" \
  --apple-id "your@email.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "app-specific-password"
```

**Example:**
```bash
# Notarize app with default profile
./scripts/notarize.sh build/GitBar.app

# Notarize with custom profile
./scripts/notarize.sh build/GitBar.app my-custom-profile
```

---

## Workflow Examples

### Development Testing

```bash
# Build without signing
xcodebuild -project GitBar.xcodeproj \
  -scheme GitBar \
  -configuration Release \
  clean build \
  CONFIGURATION_BUILD_DIR=build/Release \
  CODE_SIGN_IDENTITY="-"

# Create DMG for testing
./scripts/create-dmg.sh build/Release/GitBar.app build
```

### Production Release

```bash
# Complete automated release
./scripts/build-release.sh

# Output:
# - build/GitBar.app (signed & notarized)
# - build/GitBar-v1.0.0.dmg (signed & notarized)
```

### Manual Step-by-Step Release

```bash
# 1. Build app
xcodebuild -project GitBar.xcodeproj \
  -scheme GitBar \
  -configuration Release \
  -archivePath build/GitBar.xcarchive \
  archive

# 2. Export with signing
xcodebuild -exportArchive \
  -archivePath build/GitBar.xcarchive \
  -exportPath build \
  -exportOptionsPlist ExportOptions.plist

# 3. Notarize app
./scripts/notarize.sh build/GitBar.app

# 4. Create DMG
./scripts/create-dmg.sh build/GitBar.app build

# 5. Sign DMG
codesign --sign "Developer ID Application" \
  --timestamp \
  build/GitBar-v1.0.0.dmg

# 6. Notarize DMG
zip build/dmg.zip build/GitBar-v1.0.0.dmg
xcrun notarytool submit build/dmg.zip \
  --keychain-profile "gitbar-notarytool" \
  --wait
xcrun stapler staple build/GitBar-v1.0.0.dmg
```

## Environment Variables

### KEYCHAIN_PROFILE

Keychain profile name for notarization credentials.

- **Default:** `gitbar-notarytool`
- **Usage:** `KEYCHAIN_PROFILE=my-profile ./scripts/build-release.sh`

## Troubleshooting

### Build Fails

```bash
# Clean Xcode derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/GitBar-*

# Clean build directory
rm -rf build/

# Try again
./scripts/build-release.sh
```

### Notarization Fails

```bash
# Check credentials
xcrun notarytool history \
  --keychain-profile "gitbar-notarytool"

# View detailed logs
xcrun notarytool log SUBMISSION_ID \
  --keychain-profile "gitbar-notarytool"
```

### DMG Creation Hangs

The scripts use `--skip-jenkins` flag to avoid AppleScript hanging. If you still experience issues:

```bash
# Kill any hanging disk images
hdiutil detach /Volumes/dmg.* -force

# Clean up temporary DMG files
rm -f build/rw.*.dmg
```

## See Also

- [BUILD_RELEASE.md](../BUILD_RELEASE.md) - Complete release guide
- [DMG_DISTRIBUTION.md](../DMG_DISTRIBUTION.md) - DMG creation details
- [SPARKLE_SETUP.md](../SPARKLE_SETUP.md) - Auto-update setup
