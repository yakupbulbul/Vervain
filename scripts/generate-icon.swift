#!/usr/bin/env swift
import AppKit

// Matches the app's visual identity:
//   Background: dark navy  Color(red:0.09, green:0.09, blue:0.14)
//   Symbol:     sparkles with blue→purple gradient (topLeading→bottomTrailing)
//               same as SidebarView.appHeader & OnboardingView.header
//   SwiftUI .blue   ≈ #007AFF  (0.00, 0.478, 1.00)
//   SwiftUI .purple ≈ #AF52DE  (0.686, 0.322, 0.871)

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

// ── 1. Dark navy background ───────────────────────────────────────────────────
ctx.setFillColor(CGColor(red: 0.09, green: 0.09, blue: 0.14, alpha: 1.0))
ctx.fill(CGRect(x: 0, y: 0, width: W, height: W))

// ── 2. White sparkles symbol ──────────────────────────────────────────────────
let symCfg = NSImage.SymbolConfiguration(pointSize: 520, weight: .semibold)
    .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
if let sym = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)?
    .withSymbolConfiguration(symCfg) {
    let sz = sym.size
    sym.draw(at: NSPoint(x: (CGFloat(W) - sz.width)  / 2,
                         y: (CGFloat(W) - sz.height) / 2),
             from: .zero, operation: .sourceOver, fraction: 1.0)
}

// ── 3. Blue→Purple gradient via .multiply blend (tints white sparkles) ────────
// multiply: result = src × dest
//   • white sparkle pixels (1,1,1) × gradient = gradient colour  ✓
//   • dark bg (~0.09)              × gradient ≈ near-black        ✓
// angle 135° in AppKit y-up coords → blue at top-left, purple at bottom-right
// matching SwiftUI startPoint:.topLeading / endPoint:.bottomTrailing
let blue   = NSColor(red: 0.00,  green: 0.478, blue: 1.00,  alpha: 1.0)
let purple = NSColor(red: 0.686, green: 0.322, blue: 0.871, alpha: 1.0)
let grad   = NSGradient(starting: blue, ending: purple)!
ctx.setBlendMode(.multiply)
grad.draw(in: NSRect(x: 0, y: 0, width: W, height: W), angle: 135)
ctx.setBlendMode(.normal)

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
