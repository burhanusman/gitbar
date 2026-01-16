# GitBar

<div align="center">
  <img src="GitBar/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" width="256" alt="GitBar Icon">

  <p><strong>Git repository status at a glance. Lives in your menu bar.</strong></p>

  [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
  [![macOS](https://img.shields.io/badge/macOS-13.0+-blue.svg)](https://www.apple.com/macos)
  [![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)

  [**Website**](https://gitbar.app) • [**Download**](https://github.com/burhanusman/gitbar/releases/latest) • [**Documentation**](#documentation)
</div>

## Overview

GitBar lives in your macOS menubar and provides instant visibility into the git status of your development projects. Whether you're working with Claude Code, Codex, or any git repository, GitBar keeps you informed about uncommitted changes, branch status, and sync state with your remote repositories.

## Screenshots

<!-- TODO: Add screenshots/GIF showing:
- Menubar icon with git status
- Project list with multiple repositories
- Settings panel
- Auto-update functionality
Record with Kap (https://getkap.co/) or LICEcap (https://www.cockos.com/licecap/)
-->

![GitBar Demo](docs/images/demo.gif)
*Coming soon: animated demo*

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

## Contributing

While GitBar is not actively seeking contributions at this time, bug reports and feature requests are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for details on the process for submitting pull requests and reporting issues.

By participating in this project, you agree to abide by our [Code of Conduct](CODE_OF_CONDUCT.md)

## Documentation

### For Users
- [Website](https://gitbar.app) - Marketing website and overview

### For Developers
- [Build Guide](BUILD.md) - Development setup
- [Release Guide](BUILD_RELEASE.md) - Creating releases (automated & manual)
- [GitHub Actions Setup](.github/RELEASE_SETUP.md) - Automated release configuration
- [Manual Release Process](.github/MANUAL_RELEASE.md) - Step-by-step manual release
- [DMG Distribution](DMG_DISTRIBUTION.md) - DMG creation details
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
