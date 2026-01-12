#!/usr/bin/swift

import Cocoa
import Foundation

// Icon sizes needed for macOS
let iconSizes: [(size: Int, scale: String)] = [
    (16, "1x"),
    (32, "2x"),   // 16pt @2x
    (32, "1x"),
    (64, "2x"),   // 32pt @2x
    (128, "1x"),
    (256, "2x"),  // 128pt @2x
    (256, "1x"),
    (512, "2x"),  // 256pt @2x
    (512, "1x"),
    (1024, "2x")  // 512pt @2x
]

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))

    image.lockFocus()

    guard let context = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let scale = size / 1024.0  // Base design at 1024x1024

    // Background - Dark gradient (Apple-style)
    let backgroundPath = NSBezierPath(roundedRect: rect, xRadius: size * 0.22, yRadius: size * 0.22)

    // Gradient background
    let gradientColors = [
        NSColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1.0).cgColor,
        NSColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0).cgColor
    ]
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                               colors: gradientColors as CFArray,
                               locations: [0.0, 1.0])!

    context.saveGState()
    backgroundPath.addClip()
    context.drawLinearGradient(gradient,
                                start: CGPoint(x: 0, y: size),
                                end: CGPoint(x: 0, y: 0),
                                options: [])
    context.restoreGState()

    // Motion trails (cloud/speed effect) - three curved trails
    let trailColor1 = NSColor(red: 0.6, green: 0.6, blue: 0.65, alpha: 0.4)
    let trailColor2 = NSColor(red: 0.5, green: 0.5, blue: 0.55, alpha: 0.3)
    let trailColor3 = NSColor(red: 0.4, green: 0.4, blue: 0.45, alpha: 0.2)

    // Trail 1 (top)
    let trail1 = NSBezierPath()
    trail1.move(to: CGPoint(x: 180 * scale, y: 680 * scale))
    trail1.curve(to: CGPoint(x: 420 * scale, y: 700 * scale),
                 controlPoint1: CGPoint(x: 250 * scale, y: 720 * scale),
                 controlPoint2: CGPoint(x: 340 * scale, y: 730 * scale))
    trail1.curve(to: CGPoint(x: 500 * scale, y: 650 * scale),
                 controlPoint1: CGPoint(x: 460 * scale, y: 690 * scale),
                 controlPoint2: CGPoint(x: 490 * scale, y: 670 * scale))
    trail1.lineWidth = 40 * scale
    trail1.lineCapStyle = .round
    trailColor1.setStroke()
    trail1.stroke()

    // Trail 2 (middle)
    let trail2 = NSBezierPath()
    trail2.move(to: CGPoint(x: 140 * scale, y: 520 * scale))
    trail2.curve(to: CGPoint(x: 380 * scale, y: 530 * scale),
                 controlPoint1: CGPoint(x: 220 * scale, y: 560 * scale),
                 controlPoint2: CGPoint(x: 300 * scale, y: 560 * scale))
    trail2.curve(to: CGPoint(x: 480 * scale, y: 500 * scale),
                 controlPoint1: CGPoint(x: 420 * scale, y: 520 * scale),
                 controlPoint2: CGPoint(x: 460 * scale, y: 510 * scale))
    trail2.lineWidth = 50 * scale
    trail2.lineCapStyle = .round
    trailColor2.setStroke()
    trail2.stroke()

    // Trail 3 (bottom)
    let trail3 = NSBezierPath()
    trail3.move(to: CGPoint(x: 160 * scale, y: 360 * scale))
    trail3.curve(to: CGPoint(x: 400 * scale, y: 380 * scale),
                 controlPoint1: CGPoint(x: 240 * scale, y: 400 * scale),
                 controlPoint2: CGPoint(x: 320 * scale, y: 410 * scale))
    trail3.curve(to: CGPoint(x: 500 * scale, y: 350 * scale),
                 controlPoint1: CGPoint(x: 450 * scale, y: 370 * scale),
                 controlPoint2: CGPoint(x: 480 * scale, y: 360 * scale))
    trail3.lineWidth = 35 * scale
    trail3.lineCapStyle = .round
    trailColor3.setStroke()
    trail3.stroke()

    // Main recording button - red circle with subtle gradient
    let buttonCenter = CGPoint(x: 620 * scale, y: 512 * scale)
    let buttonRadius: CGFloat = 220 * scale

    // Button shadow
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -8 * scale), blur: 30 * scale,
                      color: NSColor.black.withAlphaComponent(0.5).cgColor)
    let shadowCircle = NSBezierPath(ovalIn: CGRect(x: buttonCenter.x - buttonRadius,
                                                     y: buttonCenter.y - buttonRadius,
                                                     width: buttonRadius * 2,
                                                     height: buttonRadius * 2))
    NSColor(red: 0.9, green: 0.2, blue: 0.25, alpha: 1.0).setFill()
    shadowCircle.fill()
    context.restoreGState()

    // Button gradient (red)
    let buttonRect = CGRect(x: buttonCenter.x - buttonRadius,
                            y: buttonCenter.y - buttonRadius,
                            width: buttonRadius * 2,
                            height: buttonRadius * 2)
    let buttonPath = NSBezierPath(ovalIn: buttonRect)

    let redGradientColors = [
        NSColor(red: 1.0, green: 0.32, blue: 0.32, alpha: 1.0).cgColor,
        NSColor(red: 0.85, green: 0.18, blue: 0.22, alpha: 1.0).cgColor
    ]
    let redGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: redGradientColors as CFArray,
                                  locations: [0.0, 1.0])!

    context.saveGState()
    buttonPath.addClip()
    context.drawLinearGradient(redGradient,
                                start: CGPoint(x: buttonCenter.x, y: buttonCenter.y + buttonRadius),
                                end: CGPoint(x: buttonCenter.x, y: buttonCenter.y - buttonRadius),
                                options: [])
    context.restoreGState()

    // Inner highlight on button
    let highlightCenter = CGPoint(x: buttonCenter.x - 40 * scale, y: buttonCenter.y + 50 * scale)
    let highlightRadius: CGFloat = 80 * scale
    let highlightPath = NSBezierPath(ovalIn: CGRect(x: highlightCenter.x - highlightRadius,
                                                      y: highlightCenter.y - highlightRadius,
                                                      width: highlightRadius * 2,
                                                      height: highlightRadius * 2))

    let highlightGradientColors = [
        NSColor.white.withAlphaComponent(0.3).cgColor,
        NSColor.white.withAlphaComponent(0.0).cgColor
    ]
    let highlightGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                        colors: highlightGradientColors as CFArray,
                                        locations: [0.0, 1.0])!

    context.saveGState()
    highlightPath.addClip()
    context.drawRadialGradient(highlightGradient,
                                startCenter: highlightCenter,
                                startRadius: 0,
                                endCenter: highlightCenter,
                                endRadius: highlightRadius,
                                options: [])
    context.restoreGState()

    // Inner circle (white dot) on recording button
    let innerDotRadius: CGFloat = 50 * scale
    let innerDot = NSBezierPath(ovalIn: CGRect(x: buttonCenter.x - innerDotRadius,
                                                 y: buttonCenter.y - innerDotRadius,
                                                 width: innerDotRadius * 2,
                                                 height: innerDotRadius * 2))
    NSColor.white.withAlphaComponent(0.95).setFill()
    innerDot.fill()

    image.unlockFocus()
    return image
}

func saveIcon(_ image: NSImage, size: Int, scale: String, to directory: URL) {
    let filename: String
    if scale == "1x" {
        filename = "icon_\(size)x\(size).png"
    } else {
        filename = "icon_\(size/2)x\(size/2)@2x.png"
    }

    let url = directory.appendingPathComponent(filename)

    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        print("Failed to create PNG for \(filename)")
        return
    }

    do {
        try pngData.write(to: url)
        print("Created: \(filename)")
    } catch {
        print("Failed to write \(filename): \(error)")
    }
}

// Main
let outputDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("FastRec/Resources/Assets.xcassets/AppIcon.appiconset")

// Create directory if needed
try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

print("Generating app icons...")

for (size, scale) in iconSizes {
    let image = drawIcon(size: CGFloat(size))
    saveIcon(image, size: size, scale: scale, to: outputDir)
}

// Update Contents.json
let contentsJson = """
{
  "images" : [
    {
      "filename" : "icon_16x16.png",
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
      "filename" : "icon_32x32.png",
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
      "filename" : "icon_128x128.png",
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
      "filename" : "icon_256x256.png",
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
      "filename" : "icon_512x512.png",
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

let contentsURL = outputDir.appendingPathComponent("Contents.json")
try? contentsJson.write(to: contentsURL, atomically: true, encoding: .utf8)
print("Updated Contents.json")

print("\nDone! App icons generated in: \(outputDir.path)")
