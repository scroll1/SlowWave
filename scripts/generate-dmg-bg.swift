import AppKit
import CoreGraphics
import Foundation

let outPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "/Users/brennanlabs/Documents/Coding/MacApps/AudioSlowDown/Resources/dmg-background.png"

let width = 640
let height = 430

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: width,
    pixelsHigh: height,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!
rep.size = NSSize(width: width, height: height)

NSGraphicsContext.saveGraphicsState()
let baseCtx = NSGraphicsContext(bitmapImageRep: rep)!.cgContext
// Flip coordinate system to top-left origin AND inform NSGraphicsContext so text renders right-side-up
baseCtx.translateBy(x: 0, y: CGFloat(height))
baseCtx.scaleBy(x: 1, y: -1)
let flippedNS = NSGraphicsContext(cgContext: baseCtx, flipped: true)
NSGraphicsContext.current = flippedNS
let ctx = baseCtx

// Background deep midnight gradient
let bgColors = [
    CGColor(red: 0.06, green: 0.08, blue: 0.16, alpha: 1.0),
    CGColor(red: 0.09, green: 0.10, blue: 0.22, alpha: 1.0),
    CGColor(red: 0.05, green: 0.07, blue: 0.14, alpha: 1.0)
] as CFArray
let bgGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: bgColors, locations: [0.0, 0.5, 1.0])!
ctx.drawLinearGradient(bgGradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: CGFloat(width), y: CGFloat(height)), options: [])

// Subtle cyan & indigo ambient glow blobs
func drawGlow(center: CGPoint, radius: CGFloat, color: CGColor) {
    let colors = [color, CGColor(red: 0, green: 0, blue: 0, alpha: 0)] as CFArray
    let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
    ctx.drawRadialGradient(grad, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
}
drawGlow(center: CGPoint(x: 140, y: 120), radius: 240, color: CGColor(red: 0.0, green: 0.78, blue: 0.95, alpha: 0.16))
drawGlow(center: CGPoint(x: 520, y: 310), radius: 260, color: CGColor(red: 0.42, green: 0.30, blue: 0.95, alpha: 0.18))

// Helper for drawing text in flipped context
func drawCenteredText(_ text: String, y: CGFloat, font: NSFont, color: NSColor) {
    let para = NSMutableParagraphStyle()
    para.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: para
    ]
    let str = NSAttributedString(string: text, attributes: attrs)
    str.draw(in: NSRect(x: 24, y: y, width: CGFloat(width - 48), height: 40))
}

func drawLeftText(_ text: String, x: CGFloat, y: CGFloat, maxWidth: CGFloat, font: NSFont, color: NSColor) {
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color
    ]
    let str = NSAttributedString(string: text, attributes: attrs)
    str.draw(in: NSRect(x: x, y: y, width: maxWidth, height: 30))
}

// Header
drawCenteredText(
    "Install SlowWave",
    y: 22,
    font: .systemFont(ofSize: 22, weight: .semibold),
    color: NSColor(white: 1.0, alpha: 0.95)
)
drawCenteredText(
    "Drag SlowWave into Applications to install",
    y: 52,
    font: .systemFont(ofSize: 13, weight: .regular),
    color: NSColor(white: 1.0, alpha: 0.65)
)

// Center arrow between SlowWave.app (x=175) and Applications (x=465) at y=165
let arrowY: CGFloat = 165
ctx.saveGState()
ctx.setShadow(offset: .zero, blur: 10, color: CGColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 0.6))
let arrowPath = CGMutablePath()
arrowPath.move(to: CGPoint(x: 276, y: arrowY))
arrowPath.addLine(to: CGPoint(x: 356, y: arrowY))
arrowPath.move(to: CGPoint(x: 342, y: arrowY - 12))
arrowPath.addLine(to: CGPoint(x: 358, y: arrowY))
arrowPath.addLine(to: CGPoint(x: 342, y: arrowY + 12))
ctx.setStrokeColor(CGColor(red: 0.35, green: 0.88, blue: 1.0, alpha: 0.92))
ctx.setLineWidth(3.5)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)
ctx.addPath(arrowPath)
ctx.strokePath()
ctx.restoreGState()

// Frosted glass notice card at bottom for unsigned / Gatekeeper instructions
let cardRect = CGRect(x: 34, y: 266, width: CGFloat(width - 68), height: 136)
let cardPath = CGPath(roundedRect: cardRect, cornerWidth: 16, cornerHeight: 16, transform: nil)

ctx.saveGState()
ctx.addPath(cardPath)
ctx.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.07))
ctx.fillPath()
ctx.addPath(cardPath)
ctx.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.22))
ctx.setLineWidth(1.0)
ctx.strokePath()
ctx.restoreGState()

let textX: CGFloat = cardRect.minX + 18
let textW: CGFloat = cardRect.width - 36

drawLeftText(
    "Important: Unsigned Free Software (BrennanLabs · MIT License)",
    x: textX,
    y: cardRect.minY + 14,
    maxWidth: textW,
    font: .systemFont(ofSize: 12.5, weight: .semibold),
    color: NSColor(red: 0.45, green: 0.90, blue: 1.0, alpha: 1.0)
)

drawLeftText(
    "macOS will block SlowWave on first launch because it is not Apple-notarized:",
    x: textX,
    y: cardRect.minY + 37,
    maxWidth: textW,
    font: .systemFont(ofSize: 11.5, weight: .regular),
    color: NSColor(white: 1.0, alpha: 0.85)
)

drawLeftText(
    "1. Try opening SlowWave once from Applications (click Done on the macOS warning).",
    x: textX + 6,
    y: cardRect.minY + 60,
    maxWidth: textW - 6,
    font: .systemFont(ofSize: 11.5, weight: .medium),
    color: NSColor(white: 1.0, alpha: 0.92)
)

drawLeftText(
    "2. Open System Settings → Privacy & Security → scroll down → click \"Open Anyway\".",
    x: textX + 6,
    y: cardRect.minY + 80,
    maxWidth: textW - 6,
    font: .systemFont(ofSize: 11.5, weight: .medium),
    color: NSColor(white: 1.0, alpha: 0.92)
)

drawLeftText(
    "Or run in Terminal:   xattr -cr /Applications/SlowWave.app",
    x: textX + 6,
    y: cardRect.minY + 104,
    maxWidth: textW - 6,
    font: .monospacedSystemFont(ofSize: 11, weight: .regular),
    color: NSColor(white: 1.0, alpha: 0.72)
)

NSGraphicsContext.restoreGraphicsState()

guard let pngData = rep.representation(using: .png, properties: [:]) else {
    fputs("Failed to encode PNG\n", stderr)
    exit(1)
}
try pngData.write(to: URL(fileURLWithPath: outPath))
print("Generated DMG background at \(outPath)")
