#!/usr/bin/env swift

import Cocoa
import Foundation

// DMG background dimensions (2x for retina)
let width: CGFloat = 1320
let height: CGFloat = 800

// Colors matching website
let bgColor = NSColor(red: 0.04, green: 0.04, blue: 0.05, alpha: 1.0)  // #0a0a0c
let accentColor = NSColor(red: 0, green: 0.96, blue: 0.83, alpha: 1.0)  // #00f5d4
let textColor = NSColor(red: 0.91, green: 0.90, blue: 0.89, alpha: 1.0)  // #e8e6e3
let subtleColor = NSColor(red: 0.35, green: 0.35, blue: 0.4, alpha: 1.0)  // #5a5a66
let gridColor = NSColor(red: 0.15, green: 0.15, blue: 0.18, alpha: 1.0)

// Create image
let image = NSImage(size: NSSize(width: width, height: height))
image.lockFocus()

// Fill background
bgColor.setFill()
NSRect(x: 0, y: 0, width: width, height: height).fill()

// Draw retro grid
let gridSpacing: CGFloat = 40
gridColor.setStroke()

// Vertical lines
for x in stride(from: 0, to: width, by: gridSpacing) {
    let path = NSBezierPath()
    path.move(to: NSPoint(x: x, y: 0))
    path.line(to: NSPoint(x: x, y: height))
    path.lineWidth = 0.5
    path.stroke()
}

// Horizontal lines
for y in stride(from: 0, to: height, by: gridSpacing) {
    let path = NSBezierPath()
    path.move(to: NSPoint(x: 0, y: y))
    path.line(to: NSPoint(x: width, y: y))
    path.lineWidth = 0.5
    path.stroke()
}

// Draw scanlines effect
for y in stride(from: 0, to: height, by: 4) {
    let scanline = NSBezierPath()
    scanline.move(to: NSPoint(x: 0, y: y))
    scanline.line(to: NSPoint(x: width, y: y))
    scanline.lineWidth = 1
    NSColor(white: 0, alpha: 0.05).setStroke()
    scanline.stroke()
}

// Draw wireframe decoration on right side
let wireframeColor = accentColor.withAlphaComponent(0.3)
wireframeColor.setStroke()

// Create abstract wireframe lines
let random = { (min: CGFloat, max: CGFloat) -> CGFloat in
    CGFloat.random(in: min...max)
}

// Draw connected wireframe nodes (centered behind the icon area)
var nodes: [(CGFloat, CGFloat)] = []
for _ in 0..<25 {
    let x = random(width * 0.6, width - 80)
    let y = random(150, height - 150)
    nodes.append((x, y))
}

// Connect nearby nodes
for i in 0..<nodes.count {
    for j in (i+1)..<nodes.count {
        let dx = nodes[j].0 - nodes[i].0
        let dy = nodes[j].1 - nodes[i].1
        let dist = sqrt(dx*dx + dy*dy)
        if dist < 200 {
            let path = NSBezierPath()
            path.move(to: NSPoint(x: nodes[i].0, y: nodes[i].1))
            path.line(to: NSPoint(x: nodes[j].0, y: nodes[j].1))
            path.lineWidth = 1
            accentColor.withAlphaComponent(0.2 * (1 - dist/200)).setStroke()
            path.stroke()
        }
    }
}

// Draw nodes
for node in nodes {
    let nodeSize: CGFloat = 4
    let nodePath = NSBezierPath(ovalIn: NSRect(
        x: node.0 - nodeSize/2,
        y: node.1 - nodeSize/2,
        width: nodeSize,
        height: nodeSize
    ))
    accentColor.withAlphaComponent(0.4).setFill()
    nodePath.fill()
}

// Draw subtle glow effect behind Applications icon area
let gradient = NSGradient(colors: [
    accentColor.withAlphaComponent(0.08),
    accentColor.withAlphaComponent(0.0)
])
let glowPath = NSBezierPath(ovalIn: NSRect(x: width * 0.45, y: -height * 0.2, width: width * 0.8, height: height * 1.4))
gradient?.draw(in: glowPath, angle: 0)

// Draw title text
let titleFont = NSFont.systemFont(ofSize: 48, weight: .bold)
let titleAttributes: [NSAttributedString.Key: Any] = [
    .font: titleFont,
    .foregroundColor: textColor
]
let title = "Install GitBar"
let titleSize = title.size(withAttributes: titleAttributes)
title.draw(at: NSPoint(x: (width - titleSize.width) / 2, y: height - 120), withAttributes: titleAttributes)

// Draw subtitle
let subtitleFont = NSFont.systemFont(ofSize: 24, weight: .medium)
let subtitleAttributes: [NSAttributedString.Key: Any] = [
    .font: subtitleFont,
    .foregroundColor: subtleColor
]
let subtitle = "Drag to Applications folder"
let subtitleSize = subtitle.size(withAttributes: subtitleAttributes)
subtitle.draw(at: NSPoint(x: (width - subtitleSize.width) / 2, y: height - 170), withAttributes: subtitleAttributes)

// Draw arrow from app position to Applications position
// Icons are at display coords (165, 200) and (495, 200), icon size 100px
// In retina: GitBar center at (330, 400), Applications center at (990, 400)
// Y from bottom: 800 - 400 = 400
// Arrow should go from right edge of GitBar icon to left edge of Applications icon
let arrowY: CGFloat = 400
let arrowStartX: CGFloat = 430  // 165*2 + 100 (right edge of GitBar icon)
let arrowEndX: CGFloat = 890    // 495*2 - 100 (left edge of Applications icon)

let arrowPath = NSBezierPath()
arrowPath.move(to: NSPoint(x: arrowStartX, y: arrowY))
arrowPath.line(to: NSPoint(x: arrowEndX - 20, y: arrowY))
arrowPath.lineWidth = 3
accentColor.withAlphaComponent(0.6).setStroke()
arrowPath.stroke()

// Arrow head
let arrowHead = NSBezierPath()
arrowHead.move(to: NSPoint(x: arrowEndX, y: arrowY))
arrowHead.line(to: NSPoint(x: arrowEndX - 25, y: arrowY + 15))
arrowHead.line(to: NSPoint(x: arrowEndX - 25, y: arrowY - 15))
arrowHead.close()
accentColor.withAlphaComponent(0.6).setFill()
arrowHead.fill()

// Draw decorative brackets around title
let bracketFont = NSFont.monospacedSystemFont(ofSize: 36, weight: .light)
let bracketAttributes: [NSAttributedString.Key: Any] = [
    .font: bracketFont,
    .foregroundColor: accentColor
]
"[".draw(at: NSPoint(x: (width - titleSize.width) / 2 - 50, y: height - 125), withAttributes: bracketAttributes)
"]".draw(at: NSPoint(x: (width + titleSize.width) / 2 + 30, y: height - 125), withAttributes: bracketAttributes)

// Add version badge style decoration
let badgePath = NSBezierPath(roundedRect: NSRect(x: width/2 - 100, y: 50, width: 200, height: 40), xRadius: 4, yRadius: 4)
accentColor.withAlphaComponent(0.1).setFill()
badgePath.fill()
accentColor.withAlphaComponent(0.3).setStroke()
badgePath.lineWidth = 1
badgePath.stroke()

let badgeFont = NSFont.monospacedSystemFont(ofSize: 14, weight: .medium)
let badgeAttributes: [NSAttributedString.Key: Any] = [
    .font: badgeFont,
    .foregroundColor: accentColor
]
let badgeText = "FREE & OPEN SOURCE"
let badgeSize = badgeText.size(withAttributes: badgeAttributes)
badgeText.draw(at: NSPoint(x: width/2 - badgeSize.width/2, y: 60), withAttributes: badgeAttributes)

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
    print("✅ Background image saved to: \(outputPath.path)")
    print("   Size: \(Int(width))x\(Int(height)) (retina)")
} catch {
    print("❌ Failed to save image: \(error)")
    exit(1)
}
