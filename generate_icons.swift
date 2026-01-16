#!/usr/bin/env swift

import AppKit
import Foundation

// Icon generator for GitBar
// Creates a minimalist git branch icon with gradient background

func createIcon(size: CGSize, isMenuBar: Bool = false) -> NSImage {
    let image = NSImage(size: size)

    image.lockFocus()

    guard let context = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    let rect = CGRect(origin: .zero, size: size)

    if isMenuBar {
        // Template image for menu bar (monochrome)
        context.setFillColor(NSColor.black.cgColor)

        // Draw simplified branch icon for menubar
        let lineWidth = size.width * 0.12
        let radius = size.width * 0.15
        let spacing = size.width * 0.25

        // Main vertical line
        let mainLine = CGRect(
            x: size.width * 0.44,
            y: size.height * 0.15,
            width: lineWidth,
            height: size.height * 0.7
        )
        context.fillEllipse(in: mainLine)

        // Top circle
        let topCircle = CGRect(
            x: size.width * 0.5 - radius,
            y: size.height * 0.75 - radius,
            width: radius * 2,
            height: radius * 2
        )
        context.fillEllipse(in: topCircle)

        // Branch line
        let branchPath = CGMutablePath()
        branchPath.move(to: CGPoint(x: size.width * 0.5, y: size.height * 0.6))
        branchPath.addQuadCurve(
            to: CGPoint(x: size.width * 0.75, y: size.height * 0.45),
            control: CGPoint(x: size.width * 0.7, y: size.height * 0.55)
        )
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        context.addPath(branchPath)
        context.strokePath()

        // Branch circle
        let branchCircle = CGRect(
            x: size.width * 0.75 - radius,
            y: size.height * 0.45 - radius,
            width: radius * 2,
            height: radius * 2
        )
        context.fillEllipse(in: branchCircle)

        // Bottom circle
        let bottomCircle = CGRect(
            x: size.width * 0.5 - radius,
            y: size.height * 0.15 - radius,
            width: radius * 2,
            height: radius * 2
        )
        context.fillEllipse(in: bottomCircle)

    } else {
        // Full app icon with gradient background

        // Modern gradient background (dark purple to blue)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let colors = [
            NSColor(red: 0.4, green: 0.3, blue: 0.8, alpha: 1.0).cgColor,  // Purple
            NSColor(red: 0.2, green: 0.4, blue: 0.9, alpha: 1.0).cgColor   // Blue
        ]

        if let gradient = CGGradient(
            colorsSpace: colorSpace,
            colors: colors as CFArray,
            locations: [0.0, 1.0]
        ) {
            // Rounded rectangle for macOS Big Sur+ style
            let cornerRadius = size.width * 0.225 // 22.5% matches macOS standard
            let path = CGPath(
                roundedRect: rect,
                cornerWidth: cornerRadius,
                cornerHeight: cornerRadius,
                transform: nil
            )
            context.addPath(path)
            context.clip()

            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: size.height),
                end: CGPoint(x: size.width, y: 0),
                options: []
            )
        }

        // Draw white git branch symbol
        context.setFillColor(NSColor.white.cgColor)

        let scale = size.width / 512.0
        let lineWidth = 24.0 * scale
        let circleRadius = 32.0 * scale

        // Main vertical branch line
        let mainLine = CGRect(
            x: size.width * 0.35 - lineWidth / 2,
            y: size.height * 0.2,
            width: lineWidth,
            height: size.height * 0.6
        )

        let mainPath = CGPath(
            roundedRect: mainLine,
            cornerWidth: lineWidth / 2,
            cornerHeight: lineWidth / 2,
            transform: nil
        )
        context.addPath(mainPath)
        context.fillPath()

        // Top commit circle
        let topCircle = CGRect(
            x: size.width * 0.35 - circleRadius,
            y: size.height * 0.75 - circleRadius,
            width: circleRadius * 2,
            height: circleRadius * 2
        )
        context.fillEllipse(in: topCircle)

        // Branch curve
        let branchPath = CGMutablePath()
        branchPath.move(to: CGPoint(x: size.width * 0.35, y: size.height * 0.55))
        branchPath.addQuadCurve(
            to: CGPoint(x: size.width * 0.65, y: size.height * 0.4),
            control: CGPoint(x: size.width * 0.55, y: size.height * 0.5)
        )

        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        context.addPath(branchPath)
        context.strokePath()

        // Branch commit circle
        let branchCircle = CGRect(
            x: size.width * 0.65 - circleRadius,
            y: size.height * 0.4 - circleRadius,
            width: circleRadius * 2,
            height: circleRadius * 2
        )
        context.fillEllipse(in: branchCircle)

        // Bottom commit circle
        let bottomCircle = CGRect(
            x: size.width * 0.35 - circleRadius,
            y: size.height * 0.2 - circleRadius,
            width: circleRadius * 2,
            height: circleRadius * 2
        )
        context.fillEllipse(in: bottomCircle)
    }

    image.unlockFocus()
    return image
}

func savePNG(image: NSImage, path: String) {
    guard let tiffData = image.tiffRepresentation,
          let bitmapImage = NSBitmapImageRep(data: tiffData),
          let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
        print("Failed to create PNG for \(path)")
        return
    }

    do {
        try pngData.write(to: URL(fileURLWithPath: path))
        print("✓ Created: \(path)")
    } catch {
        print("✗ Failed to save \(path): \(error)")
    }
}

func generateAppIcons() {
    let assetsPath = "GitBar/Assets.xcassets/AppIcon.appiconset"

    // Create directory if it doesn't exist
    try? FileManager.default.createDirectory(
        atPath: assetsPath,
        withIntermediateDirectories: true,
        attributes: nil
    )

    // App icon sizes for macOS
    let sizes: [(size: Int, scale: Int)] = [
        (16, 1), (16, 2),
        (32, 1), (32, 2),
        (128, 1), (128, 2),
        (256, 1), (256, 2),
        (512, 1), (512, 2)
    ]

    print("Generating app icons...")
    for (size, scale) in sizes {
        let pixelSize = size * scale
        let image = createIcon(size: CGSize(width: pixelSize, height: pixelSize))
        let filename = "icon_\(size)x\(size)@\(scale)x.png"
        savePNG(image: image, path: "\(assetsPath)/\(filename)")
    }

    // Generate 1024x1024 master icon
    let masterIcon = createIcon(size: CGSize(width: 1024, height: 1024))
    savePNG(image: masterIcon, path: "\(assetsPath)/icon_1024x1024.png")

    // Update Contents.json
    updateContentsJSON(assetsPath: assetsPath)
}

func generateMenuBarIcons() {
    let assetsPath = "GitBar/Assets.xcassets/MenuBarIcon.imageset"

    // Create directory
    try? FileManager.default.createDirectory(
        atPath: assetsPath,
        withIntermediateDirectories: true,
        attributes: nil
    )

    print("\nGenerating menu bar icons...")

    // Menu bar icon sizes
    let sizes = [16, 32]
    for size in sizes {
        let image = createIcon(size: CGSize(width: size, height: size), isMenuBar: true)
        image.isTemplate = true
        let filename = "menubar_\(size)x\(size).png"
        savePNG(image: image, path: "\(assetsPath)/\(filename)")
    }

    // Create Contents.json for menu bar icon
    let menuBarContents = """
    {
      "images" : [
        {
          "filename" : "menubar_16x16.png",
          "idiom" : "universal",
          "scale" : "1x"
        },
        {
          "filename" : "menubar_32x32.png",
          "idiom" : "universal",
          "scale" : "2x"
        }
      ],
      "info" : {
        "author" : "xcode",
        "version" : 1
      },
      "properties" : {
        "template-rendering-intent" : "template"
      }
    }
    """

    do {
        try menuBarContents.write(
            toFile: "\(assetsPath)/Contents.json",
            atomically: true,
            encoding: .utf8
        )
        print("✓ Created menu bar Contents.json")
    } catch {
        print("✗ Failed to create menu bar Contents.json: \(error)")
    }
}

func updateContentsJSON(assetsPath: String) {
    let contents = """
    {
      "images" : [
        {
          "filename" : "icon_16x16@1x.png",
          "idiom" : "mac",
          "scale" : "1x",
          "size" : "16x16"
        },
        {
          "filename" : "icon_16x16@2x.png",
          "idiom" : "mac",
          "scale" : "2x",
          "size" : "16x16"
        },
        {
          "filename" : "icon_32x32@1x.png",
          "idiom" : "mac",
          "scale" : "1x",
          "size" : "32x32"
        },
        {
          "filename" : "icon_32x32@2x.png",
          "idiom" : "mac",
          "scale" : "2x",
          "size" : "32x32"
        },
        {
          "filename" : "icon_128x128@1x.png",
          "idiom" : "mac",
          "scale" : "1x",
          "size" : "128x128"
        },
        {
          "filename" : "icon_128x128@2x.png",
          "idiom" : "mac",
          "scale" : "2x",
          "size" : "128x128"
        },
        {
          "filename" : "icon_256x256@1x.png",
          "idiom" : "mac",
          "scale" : "1x",
          "size" : "256x256"
        },
        {
          "filename" : "icon_256x256@2x.png",
          "idiom" : "mac",
          "scale" : "2x",
          "size" : "256x256"
        },
        {
          "filename" : "icon_512x512@1x.png",
          "idiom" : "mac",
          "scale" : "1x",
          "size" : "512x512"
        },
        {
          "filename" : "icon_512x512@2x.png",
          "idiom" : "mac",
          "scale" : "2x",
          "size" : "512x512"
        }
      ],
      "info" : {
        "author" : "xcode",
        "version" : 1
      }
    }
    """

    do {
        try contents.write(
            toFile: "\(assetsPath)/Contents.json",
            atomically: true,
            encoding: .utf8
        )
        print("✓ Updated Contents.json")
    } catch {
        print("✗ Failed to update Contents.json: \(error)")
    }
}

func generateSVGLogo() {
    let svg = """
    <?xml version="1.0" encoding="UTF-8"?>
    <svg width="512" height="512" viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg">
      <defs>
        <linearGradient id="bgGradient" x1="0%" y1="100%" x2="100%" y2="0%">
          <stop offset="0%" style="stop-color:rgb(102,77,204);stop-opacity:1" />
          <stop offset="100%" style="stop-color:rgb(51,102,230);stop-opacity:1" />
        </linearGradient>
      </defs>

      <!-- Rounded square background -->
      <rect width="512" height="512" rx="115" ry="115" fill="url(#bgGradient)"/>

      <!-- Git branch icon in white -->
      <g fill="white">
        <!-- Main vertical line -->
        <rect x="167" y="102" width="24" height="307" rx="12" ry="12"/>

        <!-- Top commit circle -->
        <circle cx="179" cy="384" r="32"/>

        <!-- Branch curve -->
        <path d="M 179 281 Q 230 256 333 205" stroke="white" stroke-width="24"
              stroke-linecap="round" fill="none"/>

        <!-- Branch commit circle -->
        <circle cx="333" cy="205" r="32"/>

        <!-- Bottom commit circle -->
        <circle cx="179" cy="102" r="32"/>
      </g>
    </svg>
    """

    do {
        try svg.write(toFile: "gitbar-logo.svg", atomically: true, encoding: .utf8)
        print("\n✓ Created gitbar-logo.svg")
    } catch {
        print("\n✗ Failed to create SVG: \(error)")
    }
}

// Main execution
print("GitBar Icon Generator")
print("====================\n")

generateAppIcons()
generateMenuBarIcons()
generateSVGLogo()

print("\n✓ Icon generation complete!")
print("\nNext steps:")
print("1. Review the generated icons in GitBar/Assets.xcassets/")
print("2. Update GitBarApp.swift to use the custom menu bar icon")
print("3. Build and test the app")
