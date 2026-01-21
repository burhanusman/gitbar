#!/usr/bin/env swift

import AppKit
import Foundation

// MARK: - Icon Generation

func generateAppIcon(pixelSize: Int) -> NSImage {
    let size = CGFloat(pixelSize)

    // Create bitmap representation with explicit pixel dimensions
    guard let bitmapRep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fatalError("Failed to create bitmap representation")
    }

    // Set up the graphics context
    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: bitmapRep)
    NSGraphicsContext.current = context

    let rect = CGRect(x: 0, y: 0, width: size, height: size)

    // Create rounded rect path for macOS icon shape
    let cornerRadius = size * 0.22 // macOS Big Sur+ icon corner radius ratio
    let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)

    // Create gradient background
    // Using #0A84FF (primary blue from design context) with a subtle gradient
    let topColor = NSColor(red: 0.04, green: 0.52, blue: 1.0, alpha: 1.0) // #0A84FF
    let bottomColor = NSColor(red: 0.02, green: 0.40, blue: 0.85, alpha: 1.0) // Slightly darker blue

    let gradient = NSGradient(starting: topColor, ending: bottomColor)
    gradient?.draw(in: path, angle: -90) // Top to bottom gradient

    // Draw SF Symbol
    let symbolName = "arrow.triangle.branch"
    let symbolPointSize = size * 0.50

    let config = NSImage.SymbolConfiguration(pointSize: symbolPointSize, weight: .semibold)

    if let symbolImage = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {

        // Create a white-tinted version
        let tintedImage = NSImage(size: symbolImage.size)
        tintedImage.lockFocus()

        symbolImage.draw(in: NSRect(origin: .zero, size: symbolImage.size))
        NSColor.white.set()
        NSRect(origin: .zero, size: symbolImage.size).fill(using: .sourceAtop)

        tintedImage.unlockFocus()

        // Calculate centered position
        let symbolSize = tintedImage.size
        let x = (size - symbolSize.width) / 2
        let y = (size - symbolSize.height) / 2

        tintedImage.draw(
            in: NSRect(x: x, y: y, width: symbolSize.width, height: symbolSize.height),
            from: .zero,
            operation: .sourceOver,
            fraction: 1.0
        )
    }

    NSGraphicsContext.restoreGraphicsState()

    // Create NSImage from bitmap rep
    let image = NSImage(size: NSSize(width: pixelSize, height: pixelSize))
    image.addRepresentation(bitmapRep)

    return image
}

func savePNG(_ image: NSImage, to path: String, pixelSize: Int) {
    // Get the bitmap representation directly from the image
    guard let tiffData = image.tiffRepresentation,
          let bitmapRep = NSBitmapImageRep(data: tiffData) else {
        print("Failed to create bitmap representation for \(path)")
        return
    }

    guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
        print("Failed to create PNG data for \(path)")
        return
    }

    do {
        try pngData.write(to: URL(fileURLWithPath: path))
        print("Saved: \(path) (\(pixelSize)x\(pixelSize))")
    } catch {
        print("Failed to save \(path): \(error)")
    }
}

// MARK: - Main

let args = CommandLine.arguments
guard args.count > 1 else {
    print("Usage: generate-app-icon.swift <output-directory>")
    exit(1)
}

let outputDir = args[1]

// Create output directory if needed
let fileManager = FileManager.default
if !fileManager.fileExists(atPath: outputDir) {
    try? fileManager.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
}

// Define all required sizes
let iconSizes: [(name: String, pixelSize: Int)] = [
    ("icon_16x16@1x.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32@1x.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128@1x.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256@1x.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512@1x.png", 512),
    ("icon_512x512@2x.png", 1024),
    ("icon_1024x1024.png", 1024)
]

print("Generating app icons with SF Symbol 'arrow.triangle.branch'...")

for (name, pixelSize) in iconSizes {
    let icon = generateAppIcon(pixelSize: pixelSize)
    let path = (outputDir as NSString).appendingPathComponent(name)
    savePNG(icon, to: path, pixelSize: pixelSize)
}

print("\nDone! Icons generated in: \(outputDir)")
