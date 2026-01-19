#!/usr/bin/swift

import AppKit
import Foundation

// DMG background image generator for GitBar
// Creates a 660x400 background with app icon placeholder and installation arrow

let width: CGFloat = 660
let height: CGFloat = 400
let size = NSSize(width: width, height: height)

// Create image
let image = NSImage(size: size)
image.lockFocus()

// Background gradient (light to slightly darker)
let gradient = NSGradient(colors: [
    NSColor(white: 0.98, alpha: 1.0),
    NSColor(white: 0.95, alpha: 1.0)
])
gradient?.draw(in: NSRect(origin: .zero, size: size), angle: 90)

// Helper function to draw text
func drawText(_ text: String, at point: CGPoint, fontSize: CGFloat, color: NSColor, centered: Bool = false) {
    let font = NSFont.systemFont(ofSize: fontSize, weight: .medium)
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

// Draw title
drawText("Install GitBar", at: CGPoint(x: width/2, y: height - 60), fontSize: 32, color: NSColor(white: 0.2, alpha: 1.0), centered: true)

// Draw instruction text
drawText("Drag GitBar to your Applications folder", at: CGPoint(x: width/2, y: height - 100), fontSize: 16, color: NSColor(white: 0.4, alpha: 1.0), centered: true)

// Draw arrow from left (app icon location) to right (Applications folder)
let arrowPath = NSBezierPath()
let arrowStart = CGPoint(x: 215, y: height/2)
let arrowEnd = CGPoint(x: 445, y: height/2)

arrowPath.move(to: arrowStart)
arrowPath.line(to: arrowEnd)

// Arrow head
arrowPath.move(to: arrowEnd)
arrowPath.line(to: CGPoint(x: arrowEnd.x - 15, y: arrowEnd.y - 10))
arrowPath.move(to: arrowEnd)
arrowPath.line(to: CGPoint(x: arrowEnd.x - 15, y: arrowEnd.y + 10))

NSColor(red: 0.5, green: 0.4, blue: 0.8, alpha: 0.6).setStroke()
arrowPath.lineWidth = 3
arrowPath.lineCapStyle = .round
arrowPath.stroke()

// Draw placeholder circles for icons
let iconSize: CGFloat = 100
let leftIconCenter = CGPoint(x: 165, y: height/2)
let rightIconCenter = CGPoint(x: 495, y: height/2)

// Left circle (App icon placeholder)
let leftCircle = NSBezierPath(ovalIn: NSRect(
    x: leftIconCenter.x - iconSize/2,
    y: leftIconCenter.y - iconSize/2,
    width: iconSize,
    height: iconSize
))
NSColor(white: 0.9, alpha: 1.0).setFill()
leftCircle.fill()
NSColor(white: 0.8, alpha: 1.0).setStroke()
leftCircle.lineWidth = 2
leftCircle.stroke()

// Right circle (Applications folder placeholder)
let rightCircle = NSBezierPath(ovalIn: NSRect(
    x: rightIconCenter.x - iconSize/2,
    y: rightIconCenter.y - iconSize/2,
    width: iconSize,
    height: iconSize
))
NSColor(white: 0.9, alpha: 1.0).setFill()
rightCircle.fill()
NSColor(white: 0.8, alpha: 1.0).setStroke()
rightCircle.lineWidth = 2
rightCircle.stroke()

// Draw labels
drawText("GitBar", at: CGPoint(x: leftIconCenter.x, y: leftIconCenter.y - iconSize/2 - 25), fontSize: 14, color: NSColor(white: 0.3, alpha: 1.0), centered: true)
drawText("Applications", at: CGPoint(x: rightIconCenter.x, y: rightIconCenter.y - iconSize/2 - 25), fontSize: 14, color: NSColor(white: 0.3, alpha: 1.0), centered: true)

image.unlockFocus()

// Save image
let outputPath = "dmg-resources/background.png"
if let tiffData = image.tiffRepresentation,
   let bitmap = NSBitmapImageRep(data: tiffData),
   let pngData = bitmap.representation(using: .png, properties: [:]) {

    let url = URL(fileURLWithPath: outputPath)
    try? pngData.write(to: url)
    print("✅ DMG background image created: \(outputPath)")
} else {
    print("❌ Failed to create DMG background image")
    exit(1)
}
