# GitBar

A macOS menubar app that displays git status for Claude Code and Codex projects.

![GitBar Icon](GitBar/Assets.xcassets/AppIcon.appiconset/icon_256x256.png)

## Features

- **Menubar Integration**: Lightweight menubar app with no Dock icon
- **Project Auto-Discovery**: Automatically finds Claude Code and Codex projects
- **Real-time Git Status**: Shows branch name, ahead/behind commits, and working directory status
- **Manual Folder Support**: Add any git repository folder for monitoring
- **Auto-Updates**: Built-in Sparkle framework for seamless updates
- **Native macOS**: Written in SwiftUI for optimal performance

## Installation

### Homebrew (Recommended)

```bash
brew install --cask gitbar
```

After installation, launch GitBar from Applications or Spotlight. Look for the git branch icon in your menubar.

### Manual Installation

1. Download the latest DMG from [Releases](https://github.com/yourusername/gitbar/releases)
2. Open the DMG file
3. Drag GitBar.app to your Applications folder
4. Launch GitBar from Applications or Spotlight

## Usage

GitBar is a menubar-only application with no Dock icon.

### Getting Started

1. Launch GitBar (it will appear in your menubar)
2. Click the menubar icon to open the project list
3. Projects from Claude Code and Codex are automatically discovered
4. Add custom folders using the "Add Folder" button

### Menubar Icon

The menubar icon displays the git status of your currently selected project:
- Branch name
- Commits ahead/behind remote
- Working directory status (clean/dirty)

### Project List

The project list shows all discovered and manually added projects:
- **Claude Projects**: Discovered from Claude Code
- **Codex Projects**: Discovered from Codex
- **Folder Projects**: Manually added git repositories

## Configuration

### Auto-Updates

GitBar uses Sparkle for automatic updates. Configure update preferences in Settings:
- Enable/disable automatic update checks
- Manual "Check for Updates" button
- View release notes before installing

### Customization

- Add custom git repositories via "Add Folder"
- Remove projects you don't want to monitor
- Toggle automatic update checks

## Building from Source

See [BUILD.md](BUILD.md) for development setup and [BUILD_RELEASE.md](BUILD_RELEASE.md) for release instructions.

### Quick Start

```bash
# Clone the repository
git clone https://github.com/yourusername/gitbar.git
cd gitbar

# Open in Xcode
open GitBar.xcodeproj

# Build and run
xcodebuild -project GitBar.xcodeproj -scheme GitBar build
```

## Requirements

- macOS 13.0 (Ventura) or later
- Git installed on your system

## Contributing to Homebrew

To update the Homebrew cask formula after a new release:

1. Fork the [homebrew-cask](https://github.com/Homebrew/homebrew-cask) repository
2. Update `Casks/g/gitbar.rb` with the new version and SHA256:

```bash
# Calculate SHA256 of the DMG
shasum -a 256 GitBar-v1.0.0.dmg

# Update the cask formula
version "1.0.0"
sha256 "your-calculated-sha256-hash"
```

3. Test the formula locally:

```bash
brew install --cask gitbar
brew uninstall --cask gitbar
```

4. Submit a pull request to homebrew-cask

## Documentation

- [Build Guide](BUILD.md) - Development setup
- [Release Guide](BUILD_RELEASE.md) - Creating releases
- [DMG Distribution](DMG_DISTRIBUTION.md) - DMG creation
- [Sparkle Setup](SPARKLE_SETUP.md) - Auto-update configuration
- [Homebrew Distribution](HOMEBREW.md) - Homebrew cask setup and submission
- [Icon Design](ICON_DESIGN.md) - App icon details

## License

MIT License - See LICENSE file for details

## Support

- Report issues at [GitHub Issues](https://github.com/yourusername/gitbar/issues)
- View releases at [GitHub Releases](https://github.com/yourusername/gitbar/releases)

## Credits

Built with:
- [SwiftUI](https://developer.apple.com/xcode/swiftui/) - UI framework
- [Sparkle](https://sparkle-project.org/) - Auto-update framework
- [create-dmg](https://github.com/create-dmg/create-dmg) - DMG installer creation
