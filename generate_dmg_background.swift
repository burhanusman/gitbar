#!/usr/bin/swift

import AppKit
import Foundation

// DMG background image generator for GitBar
// Creates multi-resolution background for Retina display support
// - 1x: 660x400 (for non-Retina)
// - 2x: 1320x800 (for Retina)
// - Bundled into TIFF for automatic selection by Finder

let baseWidth: CGFloat = 660
let baseHeight: CGFloat = 400

// Brand colors from CLAUDE.md
let darkBg = NSColor(red: 0x1a/255.0, green: 0x1a/255.0, blue: 0x1a/255.0, alpha: 1.0)
let lighterBg = NSColor(red: 0x2a/255.0, green: 0x2a/255.0, blue: 0x2a/255.0, alpha: 1.0)
let primaryBlue = NSColor(red: 0x0A/255.0, green: 0x84/255.0, blue: 0xFF/255.0, alpha: 1.0)

// Helper function to draw text
func drawText(_ text: String, at point: CGPoint, fontSize: CGFloat, weight: NSFont.Weight, color: NSColor, centered: Bool = false) {
    let font = NSFont.systemFont(ofSize: fontSize, weight: weight)
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.alignment = centered ? .center : .left

    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraphStyle
    ]

    let attributedString = NSAttributedString(string: text, attributes: attributes)
    let textSize = attributedString.size()

    var drawPoint = point
    if centered {
        drawPoint.x -= textSize.width / 2
    }

    attributedString.draw(at: drawPoint)
}

// Generate background at specified scale factor
func generateBackground(scale: Int) -> NSBitmapImageRep? {
    let s = CGFloat(scale)
    let width = baseWidth * s
    let height = baseHeight * s

    // Create bitmap at exact pixel dimensions
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(width),
        pixelsHigh: Int(height),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { return nil }

    // Set the logical size for proper DPI
    // 1x = 72 DPI, 2x = 144 DPI
    rep.size = NSSize(width: baseWidth, height: baseHeight)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // Scale the context for Retina
    if let context = NSGraphicsContext.current?.cgContext {
        context.scaleBy(x: s, y: s)
    }

    // Dark gradient background (top darker, bottom lighter for depth)
    let gradient = NSGradient(colors: [lighterBg, darkBg])
    gradient?.draw(in: NSRect(origin: .zero, size: NSSize(width: baseWidth, height: baseHeight)), angle: 90)

    // Icon positions from create-dmg.sh (y is from bottom in create-dmg, same in CoreGraphics)
    let leftIconX: CGFloat = 165
    let rightIconX: CGFloat = 495
    let iconY: CGFloat = 200

    // Draw title "Install GitBar" at top
    drawText(
        "Install GitBar",
        at: CGPoint(x: baseWidth/2, y: baseHeight - 70),
        fontSize: 28,
        weight: .semibold,
        color: NSColor.white,
        centered: true
    )

    // Draw subtitle instruction
    drawText(
        "Drag to Applications",
        at: CGPoint(x: baseWidth/2, y: baseHeight - 105),
        fontSize: 14,
        weight: .regular,
        color: NSColor(white: 0.6, alpha: 1.0),
        centered: true
    )

    // Draw subtle arrow between icon positions
    let arrowY = iconY
    let arrowStartX = leftIconX + 60  // After app icon
    let arrowEndX = rightIconX - 60    // Before Applications icon

    // Arrow line
    let arrowPath = NSBezierPath()
    arrowPath.move(to: CGPoint(x: arrowStartX, y: arrowY))
    arrowPath.line(to: CGPoint(x: arrowEndX, y: arrowY))

    // Arrow head (chevron style)
    let headSize: CGFloat = 12
    arrowPath.move(to: CGPoint(x: arrowEndX - headSize, y: arrowY + headSize))
    arrowPath.line(to: CGPoint(x: arrowEndX, y: arrowY))
    arrowPath.line(to: CGPoint(x: arrowEndX - headSize, y: arrowY - headSize))

    // Style the arrow - subtle blue with transparency
    primaryBlue.withAlphaComponent(0.4).setStroke()
    arrowPath.lineWidth = 2.5
    arrowPath.lineCapStyle = .round
    arrowPath.lineJoinStyle = .round
    arrowPath.stroke()

    NSGraphicsContext.restoreGraphicsState()

    return rep
}

// Generate both 1x and 2x versions
print("🎨 Generating DMG background images...")

guard let rep1x = generateBackground(scale: 1) else {
    print("❌ Failed to create 1x background")
    exit(1)
}

guard let rep2x = generateBackground(scale: 2) else {
    print("❌ Failed to create 2x background")
    exit(1)
}

// Save 1x PNG
let path1x = "dmg-resources/background.png"
if let pngData1x = rep1x.representation(using: .png, properties: [:]) {
    try? pngData1x.write(to: URL(fileURLWithPath: path1x))
    print("✅ Created: \(path1x) (660x400 @ 72 DPI)")
} else {
    print("❌ Failed to save 1x background")
    exit(1)
}

// Save 2x PNG
let path2x = "dmg-resources/background@2x.png"
if let pngData2x = rep2x.representation(using: .png, properties: [:]) {
    try? pngData2x.write(to: URL(fileURLWithPath: path2x))
    print("✅ Created: \(path2x) (1320x800 @ 144 DPI)")
} else {
    print("❌ Failed to save 2x background")
    exit(1)
}

// Bundle into multi-resolution TIFF using tiffutil
print("📦 Bundling into multi-resolution TIFF...")
let tiffPath = "dmg-resources/background.tiff"

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/tiffutil")
process.arguments = ["-cathidpicheck", path1x, path2x, "-out", tiffPath]

do {
    try process.run()
    process.waitUntilExit()

    if process.terminationStatus == 0 {
        print("✅ Created: \(tiffPath) (multi-resolution for Retina)")
        print("")
        print("🎉 DMG background ready for Retina displays!")
    } else {
        print("❌ tiffutil failed with exit code \(process.terminationStatus)")
        exit(1)
    }
} catch {
    print("❌ Failed to run tiffutil: \(error)")
    exit(1)
}
