# Release Quick Start

Quick reference for creating GitBar releases using GitHub Actions.

## Prerequisites (One-Time Setup)

1. Configure GitHub Secrets: [RELEASE_SETUP.md](RELEASE_SETUP.md)
2. Verify secrets are configured in GitHub Settings → Secrets and variables → Actions

## Creating a Release

### 1. Choose Version Number

Follow [semantic versioning](https://semver.org/):
- **Patch** (1.0.X) - Bug fixes only
- **Minor** (1.X.0) - New features, backwards compatible
- **Major** (X.0.0) - Breaking changes

Examples:
- Stable release: `1.0.0`, `1.1.0`, `2.0.0`
- Pre-release: `1.0.0-beta1`, `2.0.0-rc1`, `1.5.0-alpha2`

### 2. Create and Push Tag

```bash
# Set your version
VERSION="1.0.0"

# Create annotated tag
git tag -a "v${VERSION}" -m "Release version ${VERSION}"

# Push tag to trigger workflow
git push origin "v${VERSION}"
```

### 3. Monitor Workflow

1. Go to GitHub → Actions tab
2. Watch "Release GitBar" workflow
3. Wait ~15-20 minutes for completion

The workflow will:
- ✅ Build and sign app
- ✅ Notarize with Apple
- ✅ Create DMG installer
- ✅ Generate appcast.xml
- ✅ Create GitHub Release
- ✅ Upload artifacts

### 4. Verify Release

Once complete:

1. **Check GitHub Release**
   - Go to Releases tab
   - Verify release has 3 files:
     - `GitBar-v1.0.0.dmg`
     - `GitBar-v1.0.0.zip`
     - `appcast.xml`

2. **Test DMG**
   - Download DMG
   - Open and install
   - Launch app (should open without Gatekeeper warnings)
   - Check version in About menu

3. **Verify Appcast**
   - Check `appcast.xml` was committed to main branch
   - URL should work: `https://github.com/yourusername/gitbar/releases/latest/download/appcast.xml`

### 5. Announce Release

Update relevant channels:
- Twitter/social media
- Product Hunt (for major releases)
- Homebrew Cask (if new major version)
- Website/blog post

## Quick Commands

```bash
# List recent tags
git tag -l --sort=-version:refname | head -5

# View tag details
git show v1.0.0

# Delete tag (if needed)
git tag -d v1.0.0
git push origin :refs/tags/v1.0.0

# Check workflow status (using gh CLI)
gh run list --workflow=release.yml --limit 5

# View workflow logs
gh run view --log
```

## Common Issues

### Workflow Fails - "Invalid Certificate"
→ Re-export and update `CERTIFICATE_BASE64` secret

### Workflow Fails - "Notarization Failed"
→ Check `APPLE_ID` and `APPLE_APP_SPECIFIC_PASSWORD`

### Appcast Not Updating
→ Verify `SPARKLE_PRIVATE_KEY` matches public key in Info.plist

### Release Shows as "Pre-release"
→ This is automatic for tags containing `beta`, `alpha`, or `rc`

## Testing with Beta Releases

Before your first production release, test with a beta:

```bash
# Create beta release
git tag -a v1.0.0-beta1 -m "Beta release for testing"
git push origin v1.0.0-beta1

# Test entire workflow
# Then clean up if needed
gh release delete v1.0.0-beta1 --yes
git tag -d v1.0.0-beta1
git push origin :refs/tags/v1.0.0-beta1
```

## Workflow Summary

```
Push Tag (v1.0.0)
    ↓
GitHub Actions Triggered
    ↓
Build App
    ↓
Sign with Developer ID
    ↓
Notarize with Apple
    ↓
Create DMG Installer
    ↓
Sign & Notarize DMG
    ↓
Generate Appcast (Sparkle)
    ↓
Create GitHub Release
    ↓
Update appcast.xml in repo
    ↓
✅ Release Complete!
```

## Manual Fallback

If GitHub Actions fails or is unavailable:
→ Follow [MANUAL_RELEASE.md](MANUAL_RELEASE.md) for step-by-step manual process

## Full Documentation

- [RELEASE_SETUP.md](RELEASE_SETUP.md) - Complete setup guide
- [MANUAL_RELEASE.md](MANUAL_RELEASE.md) - Manual release process
- [BUILD_RELEASE.md](../BUILD_RELEASE.md) - Build and release details
