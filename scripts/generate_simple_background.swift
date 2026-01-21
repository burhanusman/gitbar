#!/usr/bin/env swift

import Cocoa
import Foundation

// DMG background dimensions (2x for retina)
let width: CGFloat = 1320
let height: CGFloat = 800

// Create image
let image = NSImage(size: NSSize(width: width, height: height))
image.lockFocus()

// Fill with a medium gray gradient (not too dark so icons are visible)
let bgGradient = NSGradient(colors: [
    NSColor(red: 0.18, green: 0.18, blue: 0.20, alpha: 1.0),  // Lighter gray
    NSColor(red: 0.14, green: 0.14, blue: 0.16, alpha: 1.0)
])
bgGradient?.draw(in: NSRect(x: 0, y: 0, width: width, height: height), angle: -45)

// Draw subtle isometric grid
let gridColor = NSColor(red: 0.22, green: 0.22, blue: 0.25, alpha: 1.0)
let gridSpacing: CGFloat = 80
gridColor.setStroke()

// Vertical lines
for x in stride(from: CGFloat(0), through: width, by: gridSpacing) {
    let path = NSBezierPath()
    path.move(to: NSPoint(x: x, y: 0))
    path.line(to: NSPoint(x: x, y: height))
    path.lineWidth = 0.5
    path.stroke()
}

// Horizontal lines
for y in stride(from: CGFloat(0), through: height, by: gridSpacing) {
    let path = NSBezierPath()
    path.move(to: NSPoint(x: 0, y: y))
    path.line(to: NSPoint(x: width, y: y))
    path.lineWidth = 0.5
    path.stroke()
}

image.unlockFocus()

// Save to file
let scriptDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let projectDir = scriptDir.deletingLastPathComponent()
let outputPath = projectDir.appendingPathComponent("dmg-resources/background.png")

guard let tiffData = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffData),
      let pngData = bitmap.representation(using: .png, properties: [:]) else {
    print("❌ Failed to create PNG data")
    exit(1)
}

do {
    try pngData.write(to: outputPath)
    print("✅ Background saved to: \(outputPath.path)")
} catch {
    print("❌ Failed to save image: \(error)")
    exit(1)
}
