# GitBar Logo Assets

This directory contains logo files for press, marketing, and distribution purposes.

## Generating Logo Assets

The project includes existing icon assets in `GitBar/Assets.xcassets/AppIcon.appiconset/`.

### Copy Existing Icons to Press Kit

```bash
# From the gitbar root directory
cd launch-assets/press-kit/logos

# Copy existing icon sizes
cp ../../../GitBar/Assets.xcassets/AppIcon.appiconset/icon_1024x1024.png gitbar-icon-1024.png
cp ../../../GitBar/Assets.xcassets/AppIcon.appiconset/icon_512x512@1x.png gitbar-icon-512.png
cp ../../../GitBar/Assets.xcassets/AppIcon.appiconset/icon_256x256@1x.png gitbar-icon-256.png
cp ../../../GitBar/Assets.xcassets/AppIcon.appiconset/icon_128x128@1x.png gitbar-icon-128.png

# Copy SVG logo
cp ../../../gitbar-logo.svg gitbar-logo.svg
```

## Logo Sizes

### Icon PNG Files
- **gitbar-icon-1024.png** - 1024x1024 (High resolution, app store, press)
- **gitbar-icon-512.png** - 512x512 (Standard press, web)
- **gitbar-icon-256.png** - 256x256 (Medium, README headers)
- **gitbar-icon-128.png** - 128x128 (Small, thumbnails)

### Vector Format
- **gitbar-logo.svg** - Scalable vector format (preferred for print)

## Usage Guidelines

### App Icon
The GitBar app icon features a stylized git branch symbol in the signature Git orange color (#F05032) on a rounded square background.

### Color Palette
- **Primary**: Git Orange `#F05032`
- **Background**: Dark Gray `#24292E`
- **Accent**: macOS System Blue (context-dependent)

### Clear Space
Maintain clear space around the logo equal to 10% of the icon size on all sides.

### Minimum Size
- Digital: 32x32px minimum
- Print: 0.5 inches minimum

## File Formats

### When to Use Each Format

**PNG (Raster)**
- Web and digital use
- Social media
- When exact size is known
- Screenshots and documentation

**SVG (Vector)**
- Print materials
- Scalable web graphics
- When size flexibility is needed
- Professional publications

## License

All logo assets are part of the GitBar project and are available under the same MIT license.

For editorial use, see the press kit guidelines in `PRESS_KIT.md`.
