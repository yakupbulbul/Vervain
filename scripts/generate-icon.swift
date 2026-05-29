#!/usr/bin/env swift
import AppKit

// Matches the app's organic visual identity:
//   Background: Forest Green → Warm Amber gradient (full-bleed)
//   Symbol:     white leaf.fill — nature, care, purity
//   Theme.brandPrimary  = (0.22, 0.56, 0.35)  forest green
//   Theme.brandSecondary = (0.78, 0.55, 0.18)  warm amber

let W = 1024

// ── Opaque CGContext (no alpha channel) ───────────────────────────────────────
let space   = CGColorSpaceCreateDeviceRGB()
let bmpInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)
guard let ctx = CGContext(
    data: nil, width: W, height: W,
    bitsPerComponent: 8, bytesPerRow: 0,
    space: space, bitmapInfo: bmpInfo.rawValue
) else { print("CGContext init failed"); exit(1) }

// Wrap in NSGraphicsContext so AppKit calls (NSImage, NSGradient) draw into ctx
let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = nsCtx

// ── 1. Full-bleed Forest Green → Warm Amber gradient ─────────────────────────
let forestGreen = NSColor(red: 0.15, green: 0.45, blue: 0.28, alpha: 1.0)
let warmAmber   = NSColor(red: 0.78, green: 0.55, blue: 0.18, alpha: 1.0)
let grad = NSGradient(starting: forestGreen, ending: warmAmber)!
// angle 135° in AppKit y-up coords → green at top-left, amber at bottom-right
grad.draw(in: NSRect(x: 0, y: 0, width: W, height: W), angle: 135)

// ── 2. Subtle radial glow in center for depth ────────────────────────────────
let glow = NSGradient(colors: [
    NSColor.white.withAlphaComponent(0.12),
    NSColor.clear
])!
let glowRect = NSRect(x: 0, y: 0, width: W, height: W).insetBy(dx: 100, dy: 100)
glow.draw(in: glowRect, relativeCenterPosition: NSPoint(x: 0, y: 0))

// ── 3. White leaf symbol, centered ───────────────────────────────────────────
let symCfg = NSImage.SymbolConfiguration(pointSize: 480, weight: .semibold)
    .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
if let sym = NSImage(systemSymbolName: "leaf.fill", accessibilityDescription: nil)?
    .withSymbolConfiguration(symCfg) {
    let sz = sym.size
    sym.draw(at: NSPoint(x: (CGFloat(W) - sz.width)  / 2,
                         y: (CGFloat(W) - sz.height) / 2),
             from: .zero, operation: .sourceOver, fraction: 1.0)
}

NSGraphicsContext.restoreGraphicsState()

// ── Write opaque PNG ──────────────────────────────────────────────────────────
guard let finalImg = ctx.makeImage() else { print("makeImage failed"); exit(1) }

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let outURL = URL(fileURLWithPath: outDir).appendingPathComponent("AppIcon.png")
guard let dest = CGImageDestinationCreateWithURL(
        outURL as CFURL, "public.png" as CFString, 1, nil) else {
    print("Destination create failed"); exit(1)
}
CGImageDestinationAddImage(dest, finalImg, nil)
guard CGImageDestinationFinalize(dest) else { print("Finalize failed"); exit(1) }
print("✅ Generated opaque icon at \(outURL.path)")
