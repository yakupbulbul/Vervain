#!/usr/bin/env swift
import AppKit

let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size, flipped: false) { rect in
    // 1. Full-bleed opaque gradient background — fills entire canvas, no inset
    let gradient = NSGradient(colorsAndLocations:
        (NSColor(red: 0.10, green: 0.12, blue: 0.80, alpha: 1.0), 0.0),   // deep blue
        (NSColor(red: 0.35, green: 0.12, blue: 0.78, alpha: 1.0), 0.55),  // indigo
        (NSColor(red: 0.58, green: 0.18, blue: 0.88, alpha: 1.0), 1.0)    // purple
    )!
    gradient.draw(in: rect, angle: -50)

    // 2. Soft radial glow in center for depth
    let glow = NSGradient(colors: [
        NSColor.white.withAlphaComponent(0.15),
        NSColor.clear
    ])!
    let glowRect = rect.insetBy(dx: 80, dy: 80)
    glow.draw(in: glowRect, relativeCenterPosition: NSPoint(x: 0, y: 0))

    // 3. White sparkles symbol, centered, medium weight
    let symbolConfig = NSImage.SymbolConfiguration(pointSize: 440, weight: .medium)
        .applying(.init(paletteColors: [.white]))
    if let symbol = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)?
        .withSymbolConfiguration(symbolConfig) {
        let sz = symbol.size
        let origin = NSPoint(
            x: (rect.width - sz.width) / 2,
            y: (rect.height - sz.height) / 2
        )
        symbol.draw(at: origin, from: .zero, operation: .sourceOver, fraction: 1.0)
    }
    return true
}

// Write opaque PNG — samplesPerPixel: 3, hasAlpha: false ensures no alpha channel
let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: 1024,
    pixelsHigh: 1024,
    bitsPerSample: 8,
    samplesPerPixel: 3,
    hasAlpha: false,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
image.draw(in: NSRect(x: 0, y: 0, width: 1024, height: 1024))
NSGraphicsContext.restoreGraphicsState()

guard let pngData = rep.representation(using: .png, properties: [:]) else {
    print("Failed to create PNG data")
    exit(1)
}

let outputDir = URL(fileURLWithPath: CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : ".")
let outputPath = outputDir.appendingPathComponent("AppIcon.png")
try pngData.write(to: outputPath)
print("✅ Generated opaque icon at \(outputPath.path)")
