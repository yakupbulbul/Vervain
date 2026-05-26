#!/usr/bin/env swift
import AppKit

let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size, flipped: false) { rect in
    // Rounded-rect background with blue-purple gradient
    let inset = rect.insetBy(dx: 80, dy: 80)
    let path = NSBezierPath(roundedRect: inset, xRadius: 180, yRadius: 180)

    let gradient = NSGradient(colorsAndLocations:
        (NSColor(red: 0.15, green: 0.15, blue: 0.85, alpha: 1.0), 0.0),
        (NSColor(red: 0.45, green: 0.15, blue: 0.75, alpha: 1.0), 0.5),
        (NSColor(red: 0.60, green: 0.20, blue: 0.90, alpha: 1.0), 1.0)
    )!
    gradient.draw(in: path, angle: -45)

    // Subtle inner shadow / border
    let borderPath = NSBezierPath(roundedRect: inset.insetBy(dx: 2, dy: 2), xRadius: 178, yRadius: 178)
    NSColor.white.withAlphaComponent(0.12).setStroke()
    borderPath.lineWidth = 3
    borderPath.stroke()

    // Draw the sparkles symbol centered
    let symbolConfig = NSImage.SymbolConfiguration(pointSize: 420, weight: .bold)
        .applying(.init(paletteColors: [.white]))
    if let sparkle = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)?
        .withSymbolConfiguration(symbolConfig) {
        let symbolSize = sparkle.size
        let origin = NSPoint(
            x: (rect.width - symbolSize.width) / 2,
            y: (rect.height - symbolSize.height) / 2
        )
        sparkle.draw(at: origin, from: .zero, operation: .sourceOver, fraction: 0.95)
    }

    return true
}

// Write PNG
guard let tiffData = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffData),
      let pngData = bitmap.representation(using: .png, properties: [:]) else {
    print("Failed to create PNG data")
    exit(1)
}

let outputDir = URL(fileURLWithPath: CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : ".")
let outputPath = outputDir.appendingPathComponent("AppIcon.png")
try pngData.write(to: outputPath)
print("Generated icon at \(outputPath.path)")
