# GitBar Icon Design

## Overview
GitBar features a professional, minimalist icon design that combines a git branch symbol with modern macOS aesthetics.

## Design Elements

### App Icon (1024x1024 master)
- **Shape**: Rounded square following macOS Big Sur+ design language (22.5% corner radius)
- **Background**: Modern gradient from dark purple (#664DCC) to blue (#3366E6)
- **Symbol**: White git branch diagram showing three commits with a branch
- **Style**: Clean, minimalist, professional

### Menu Bar Icon (16x16, 32x32 @2x)
- **Format**: Template image (adapts to light/dark menu bar)
- **Design**: Simplified git branch symbol optimized for small sizes
- **Visibility**: Clear and recognizable at 16x16 pixels

## Generated Assets

### App Icon Sizes
All sizes generated and exported to `GitBar/Assets.xcassets/AppIcon.appiconset/`:
- 16x16 @1x and @2x
- 32x32 @1x and @2x
- 128x128 @1x and @2x
- 256x256 @1x and @2x
- 512x512 @1x and @2x
- 1024x1024 master

### Menu Bar Icon
Exported to `GitBar/Assets.xcassets/MenuBarIcon.imageset/`:
- 16x16 @1x (standard display)
- 32x32 @2x (retina display)
- Template rendering enabled for automatic dark/light mode adaptation

### SVG Logo
Website-ready vector logo exported as `gitbar-logo.svg`:
- Scalable vector format
- Same design as app icon
- Suitable for marketing materials and website

## Implementation

The icon design is fully programmatic, generated using Swift/AppKit in `generate_icons.swift`. This ensures:
- Consistency across all sizes
- Easy modifications if needed
- No dependency on external design tools
- Reproducible build process

## Design Principles

1. **Minimalist**: Clean lines, no unnecessary details
2. **Recognizable**: Git branch metaphor is immediately clear
3. **Professional**: Gradient and rounded corners match modern macOS apps
4. **Scalable**: Works perfectly from 16x16 to 1024x1024
5. **Adaptive**: Menu bar icon works in both light and dark modes

## Regenerating Icons

To regenerate the icons (if design changes are needed):

```bash
./generate_icons.swift
```

This will:
1. Generate all app icon sizes
2. Create menu bar icon variants
3. Export SVG logo
4. Update Contents.json files automatically

## Technical Details

- **Color Space**: RGB
- **Format**: PNG (app icons), Template PNG (menu bar), SVG (logo)
- **Bit Depth**: 32-bit RGBA
- **Compression**: PNG standard compression
- **Template Mode**: Menu bar icon uses template rendering for system tinting
