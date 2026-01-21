#!/usr/bin/env swift

import AppKit
import Foundation

// Icon sizes needed for macOS app
let iconSizes: [(name: String, size: Int, scale: Int)] = [
    ("icon_16x16@1x", 16, 1),
    ("icon_16x16@2x", 16, 2),
    ("icon_32x32@1x", 32, 1),
    ("icon_32x32@2x", 32, 2),
    ("icon_128x128@1x", 128, 1),
    ("icon_128x128@2x", 128, 2),
    ("icon_256x256@1x", 256, 1),
    ("icon_256x256@2x", 256, 2),
    ("icon_512x512@1x", 512, 1),
    ("icon_512x512@2x", 512, 2),
    ("icon_1024x1024", 1024, 1),
]

// Press kit sizes
let pressKitSizes = [1024, 512, 256, 128]

func createAppIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))

    image.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: size, height: size)

    // Create rounded rectangle path (macOS app icon shape)
    let cornerRadius = size * 0.22 // Standard macOS icon corner radius ratio
    let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)

    // Create gradient background (purple to blue, matching current style)
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.38, green: 0.29, blue: 0.85, alpha: 1.0), // Purple top-left
        NSColor(calibratedRed: 0.24, green: 0.47, blue: 0.96, alpha: 1.0), // Blue middle
        NSColor(calibratedRed: 0.04, green: 0.52, blue: 1.0, alpha: 1.0),  // Bright blue bottom-right
    ])!

    // Draw gradient at 45 degree angle
    path.addClip()
    gradient.draw(in: rect, angle: -45)

    // Draw the branch symbol (arrow.triangle.branch style - Y shape)
    let symbolColor = NSColor.white
    symbolColor.setFill()
    symbolColor.setStroke()

    // Calculate symbol dimensions
    let padding = size * 0.18
    let symbolWidth = size - (padding * 2)
    let symbolHeight = size - (padding * 2)
    let centerX = size / 2
    let topY = size - padding
    let bottomY = padding
    let branchY = size * 0.55

    // Line width proportional to icon size
    let lineWidth = max(size * 0.08, 2.0)
    let circleRadius = max(size * 0.08, 3.0)

    // Draw main vertical line (from bottom to branch point)
    let mainLine = NSBezierPath()
    mainLine.lineWidth = lineWidth
    mainLine.lineCapStyle = .round
    mainLine.move(to: NSPoint(x: centerX, y: bottomY + circleRadius))
    mainLine.line(to: NSPoint(x: centerX, y: topY - circleRadius))
    mainLine.stroke()

    // Draw branch line going to upper right
    let branchEndX = centerX + symbolWidth * 0.35
    let branchEndY = branchY + symbolHeight * 0.25

    let branchLine = NSBezierPath()
    branchLine.lineWidth = lineWidth
    branchLine.lineCapStyle = .round
    branchLine.move(to: NSPoint(x: centerX, y: branchY))
    branchLine.line(to: NSPoint(x: branchEndX - circleRadius * 0.7, y: branchEndY - circleRadius * 0.7))
    branchLine.stroke()

    // Draw circles at endpoints
    // Top circle
    let topCircle = NSBezierPath(ovalIn: NSRect(
        x: centerX - circleRadius,
        y: topY - circleRadius * 2,
        width: circleRadius * 2,
        height: circleRadius * 2
    ))
    topCircle.fill()

    // Bottom circle
    let bottomCircle = NSBezierPath(ovalIn: NSRect(
        x: centerX - circleRadius,
        y: bottomY,
        width: circleRadius * 2,
        height: circleRadius * 2
    ))
    bottomCircle.fill()

    // Branch end circle
    let branchCircle = NSBezierPath(ovalIn: NSRect(
        x: branchEndX - circleRadius,
        y: branchEndY - circleRadius,
        width: circleRadius * 2,
        height: circleRadius * 2
    ))
    branchCircle.fill()

    image.unlockFocus()

    return image
}

func savePNG(image: NSImage, to path: String, pixelSize: Int) {
    // Create a bitmap representation at the exact pixel size
    guard let bitmapRep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .calibratedRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        print("Failed to create bitmap rep")
        return
    }

    bitmapRep.size = NSSize(width: pixelSize, height: pixelSize)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)

    // Draw the image
    image.draw(in: NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize),
               from: .zero,
               operation: .copy,
               fraction: 1.0)

    NSGraphicsContext.restoreGraphicsState()

    // Save as PNG
    guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
        print("Failed to create PNG data")
        return
    }

    do {
        try pngData.write(to: URL(fileURLWithPath: path))
        print("✓ Saved: \(path)")
    } catch {
        print("Failed to save \(path): \(error)")
    }
}

// Get script directory and project paths
let scriptPath = CommandLine.arguments[0]
let scriptDir = (scriptPath as NSString).deletingLastPathComponent
let projectDir = (scriptDir as NSString).deletingLastPathComponent
let appIconDir = "\(projectDir)/GitBar/Assets.xcassets/AppIcon.appiconset"
let dmgResourcesDir = "\(projectDir)/dmg-resources"
let pressKitDir = "\(projectDir)/launch-assets/press-kit/logos"

print("🎨 Generating GitBar App Icons...")
print("📍 Project: \(projectDir)")
print("")

// Generate app icons for Assets.xcassets
print("📱 Generating app icons...")
for iconSpec in iconSizes {
    let pixelSize = iconSpec.size * iconSpec.scale
    let image = createAppIcon(size: CGFloat(pixelSize))
    let outputPath = "\(appIconDir)/\(iconSpec.name).png"
    savePNG(image: image, to: outputPath, pixelSize: pixelSize)
}

// Generate press kit icons
print("")
print("📦 Generating press kit icons...")
for size in pressKitSizes {
    let image = createAppIcon(size: CGFloat(size))
    let outputPath = "\(pressKitDir)/gitbar-icon-\(size).png"
    savePNG(image: image, to: outputPath, pixelSize: size)
}

// Generate 1024px PNG for iconutil
print("")
print("💿 Generating DMG icon...")
let masterIcon = createAppIcon(size: 1024)

// Create iconset folder for iconutil
let iconsetDir = "\(dmgResourcesDir)/AppIcon.iconset"
let fm = FileManager.default

// Remove old iconset if exists
try? fm.removeItem(atPath: iconsetDir)
try? fm.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

// Generate all sizes needed for icns
let icnsSpecs: [(name: String, size: Int)] = [
    ("icon_16x16", 16),
    ("icon_16x16@2x", 32),
    ("icon_32x32", 32),
    ("icon_32x32@2x", 64),
    ("icon_128x128", 128),
    ("icon_128x128@2x", 256),
    ("icon_256x256", 256),
    ("icon_256x256@2x", 512),
    ("icon_512x512", 512),
    ("icon_512x512@2x", 1024),
]

for spec in icnsSpecs {
    let image = createAppIcon(size: CGFloat(spec.size))
    let outputPath = "\(iconsetDir)/\(spec.name).png"
    savePNG(image: image, to: outputPath, pixelSize: spec.size)
}

print("")
print("🔧 Converting to icns...")

// Run iconutil to create icns
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconsetDir, "-o", "\(dmgResourcesDir)/AppIcon.icns"]

do {
    try task.run()
    task.waitUntilExit()

    if task.terminationStatus == 0 {
        print("✓ Created: \(dmgResourcesDir)/AppIcon.icns")
        // Clean up iconset folder
        try? fm.removeItem(atPath: iconsetDir)
    } else {
        print("✗ iconutil failed with status \(task.terminationStatus)")
    }
} catch {
    print("✗ Failed to run iconutil: \(error)")
}

print("")
print("✅ Icon generation complete!")
