# Homebrew Cask Distribution Guide

Complete guide for distributing GitBar through Homebrew Cask.

## Overview

GitBar can be installed via Homebrew Cask, making it easy for users to install and keep updated:

```bash
brew install --cask gitbar
```

## Cask Formula

The Homebrew cask formula is located at `Casks/gitbar.rb` and includes:

- Download URL pointing to GitHub Releases DMG
- SHA256 checksum for integrity verification
- Sparkle appcast integration for livecheck
- Auto-update support via Sparkle framework
- Installation caveats explaining menubar-only behavior

## Prerequisites

Before submitting to Homebrew:

1. **GitHub Release**: Published release with DMG asset
2. **DMG File**: Signed and notarized DMG (see [DMG_DISTRIBUTION.md](DMG_DISTRIBUTION.md))
3. **Appcast**: Published appcast.xml for auto-updates (see [SPARKLE_SETUP.md](SPARKLE_SETUP.md))
4. **Version Tag**: Git tag matching the release (e.g., v1.0.0)

## Local Testing

Test the cask formula locally before submitting:

### 1. Update Formula for Testing

Edit `Casks/gitbar.rb`:

```ruby
cask "gitbar" do
  version "1.0.0"
  sha256 "abc123..." # Calculate with: shasum -a 256 GitBar-v1.0.0.dmg

  url "https://github.com/yourusername/gitbar/releases/download/v#{version}/GitBar-v#{version}.dmg"
  # ... rest of formula
end
```

### 2. Calculate SHA256

After creating a release with the DMG:

```bash
# Download the DMG from GitHub Releases
curl -L -o GitBar-v1.0.0.dmg \
  https://github.com/yourusername/gitbar/releases/download/v1.0.0/GitBar-v1.0.0.dmg

# Calculate SHA256
shasum -a 256 GitBar-v1.0.0.dmg

# Update the sha256 value in gitbar.rb
```

### 3. Test Installation

```bash
# Install from local cask
brew install --cask Casks/gitbar.rb

# Verify installation
ls -la /Applications/GitBar.app

# Test the app
open /Applications/GitBar.app

# Uninstall for further testing
brew uninstall --cask gitbar
```

### 4. Audit the Formula

```bash
# Run Homebrew audit
brew audit --cask Casks/gitbar.rb

# Check for style issues
brew style Casks/gitbar.rb
```

## Submitting to Homebrew Cask

Once you've tested the formula locally:

### 1. Fork homebrew-cask

```bash
# Fork on GitHub
# Navigate to: https://github.com/Homebrew/homebrew-cask
# Click "Fork"

# Clone your fork
git clone https://github.com/YOUR_USERNAME/homebrew-cask.git
cd homebrew-cask
```

### 2. Create Branch

```bash
# Create a new branch for your cask
git checkout -b gitbar-1.0.0
```

### 3. Add the Cask

```bash
# Copy the formula to the correct location
# Casks are organized alphabetically by first letter
mkdir -p Casks/g
cp /path/to/gitbar/Casks/gitbar.rb Casks/g/gitbar.rb
```

### 4. Update Formula for Production

Edit `Casks/g/gitbar.rb` and update placeholders:

```ruby
cask "gitbar" do
  version "1.0.0"
  sha256 "your-calculated-sha256-hash"

  url "https://github.com/ACTUAL_USERNAME/gitbar/releases/download/v#{version}/GitBar-v#{version}.dmg"
  name "GitBar"
  desc "macOS menubar app displaying git status for Claude Code and Codex projects"
  homepage "https://github.com/ACTUAL_USERNAME/gitbar"

  livecheck do
    url "https://github.com/ACTUAL_USERNAME/gitbar/releases/latest/download/appcast.xml"
    strategy :sparkle
  end

  auto_updates true

  app "GitBar.app"

  zap trash: [
    "~/Library/Application Support/com.yourcompany.GitBar",
    "~/Library/Caches/com.yourcompany.GitBar",
    "~/Library/Preferences/com.yourcompany.GitBar.plist",
  ]

  caveats <<~EOS
    GitBar is a menubar-only application with no Dock icon.

    After installation:
    1. Launch GitBar from Applications or Spotlight
    2. Look for the git branch icon in your menubar (top-right)
    3. Click the icon to view your projects

    The app runs in the background and can be accessed from the menubar.
  EOS
end
```

### 5. Test in Fork

```bash
# Test installation from your fork
brew install --cask gitbar

# Verify
brew info gitbar

# Uninstall
brew uninstall --cask gitbar
```

### 6. Commit and Push

```bash
# Add the cask file
git add Casks/g/gitbar.rb

# Commit with conventional message format
git commit -m "gitbar 1.0.0 (new formula)"

# Push to your fork
git push origin gitbar-1.0.0
```

### 7. Create Pull Request

1. Go to your fork on GitHub
2. Click "Pull Request"
3. Base repository: `Homebrew/homebrew-cask` base: `master`
4. Head repository: `YOUR_USERNAME/homebrew-cask` compare: `gitbar-1.0.0`
5. Title: `gitbar 1.0.0 (new formula)`
6. Description: Brief description of the app
7. Submit the PR

### 8. PR Review Process

The Homebrew maintainers will:
- Run automated checks
- Verify the formula works
- Check that the app is properly signed/notarized
- Test installation on clean macOS systems

Be responsive to feedback and make requested changes.

## Updating Existing Cask

For subsequent releases:

### 1. Fork and Update

```bash
# Ensure fork is up to date
cd homebrew-cask
git checkout master
git pull upstream master

# Create update branch
git checkout -b gitbar-1.0.1
```

### 2. Update Version and SHA256

Edit `Casks/g/gitbar.rb`:

```ruby
cask "gitbar" do
  version "1.0.1"  # Update version
  sha256 "new-sha256-hash"  # Update SHA256
  # ... rest remains the same
end
```

### 3. Calculate New SHA256

```bash
# Download new release
curl -L -o GitBar-v1.0.1.dmg \
  https://github.com/yourusername/gitbar/releases/download/v1.0.1/GitBar-v1.0.1.dmg

# Calculate SHA256
shasum -a 256 GitBar-v1.0.1.dmg
```

### 4. Test and Submit

```bash
# Test locally
brew reinstall --cask Casks/g/gitbar.rb

# Commit and push
git add Casks/g/gitbar.rb
git commit -m "gitbar 1.0.1"
git push origin gitbar-1.0.1

# Create PR with title: "gitbar 1.0.1"
```

## Formula Structure Explained

### Required Fields

```ruby
version "1.0.0"           # App version
sha256 "abc123..."        # DMG checksum
url "https://..."         # Download URL
name "GitBar"             # Human-readable name
desc "Description..."     # Short description
homepage "https://..."    # Project homepage
app "GitBar.app"          # App to install
```

### Optional Fields

```ruby
livecheck do              # For brew upgrade detection
  url "..."               # Appcast or release feed
  strategy :sparkle       # Detection strategy
end

auto_updates true         # App has built-in updater

zap trash: [...]          # Files to remove with brew uninstall --zap

caveats <<~EOS           # Installation notes for users
  Custom message...
EOS
```

## Livecheck with Sparkle

GitBar uses Sparkle for auto-updates. The livecheck block tells Homebrew to check the appcast for new versions:

```ruby
livecheck do
  url "https://github.com/yourusername/gitbar/releases/latest/download/appcast.xml"
  strategy :sparkle
end
```

This enables:
- `brew upgrade --cask` to detect new versions
- `brew livecheck --cask gitbar` to check for updates

## Auto-Updates Flag

Since GitBar has built-in Sparkle auto-updates:

```ruby
auto_updates true
```

This tells users that the app will update itself and they don't need to rely solely on Homebrew for updates.

## Troubleshooting

### SHA256 Mismatch

If users report SHA256 errors:

1. Verify the DMG wasn't modified after calculating SHA256
2. Re-download from GitHub Releases and recalculate
3. Update the formula with correct SHA256
4. Submit update PR

### Livecheck Not Working

If `brew livecheck` doesn't detect updates:

1. Verify appcast.xml is accessible at the URL
2. Check appcast follows Sparkle format
3. Ensure version numbers in appcast match releases
4. Test with: `brew livecheck --debug --cask gitbar`

### Installation Fails

If installation fails:

1. Check DMG is properly signed and notarized
2. Verify app bundle structure is correct
3. Test manual download and installation
4. Check Console.app for Gatekeeper errors

## Best Practices

1. **Release Process**: Create GitHub release → Generate DMG → Calculate SHA256 → Update formula
2. **Version Numbers**: Follow semantic versioning (1.0.0, 1.0.1, 1.1.0, etc.)
3. **Testing**: Always test formula locally before submitting PR
4. **Appcast**: Keep appcast.xml up to date with each release
5. **Documentation**: Keep README and formula desc in sync

## Resources

- [Homebrew Cask Documentation](https://docs.brew.sh/Cask-Cookbook)
- [Acceptable Casks](https://docs.brew.sh/Acceptable-Casks)
- [Homebrew Cask Pull Request Guide](https://docs.brew.sh/How-To-Open-a-Homebrew-Pull-Request)
- [Sparkle Documentation](https://sparkle-project.org/documentation/)

## Maintenance Schedule

After each release:

1. Create and upload DMG to GitHub Releases
2. Update appcast.xml with new version
3. Calculate SHA256 of new DMG
4. Update Casks/gitbar.rb locally
5. Test installation locally
6. Submit PR to homebrew-cask
7. Respond to PR feedback
8. Verify formula works after merge

## Support

For Homebrew-related issues:
- Homebrew Cask issues: https://github.com/Homebrew/homebrew-cask/issues
- GitBar issues: https://github.com/yourusername/gitbar/issues
