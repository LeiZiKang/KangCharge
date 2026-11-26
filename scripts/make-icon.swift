import AppKit
import CoreGraphics

/// Generates the minimalist SugarWatt app icon:
/// a warm ceramic-white square with a crisp, hardware-inspired vermilion-orange lightning bolt.
/// Outputs macOS iconset PNGs, a 1024px preview, and full-bleed 1024px PNG for iOS/watchOS.

func renderIcon(size px: Int, macOSGrid: Bool) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: px,
        pixelsHigh: px,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: px, height: px)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    let s = CGFloat(px)
    let colorSpace = CGColorSpaceCreateDeviceRGB()

    ctx.clear(CGRect(x: 0, y: 0, width: s, height: s))

    // Card bounds: macOS uses ~82.4% squircle with drop shadow; iOS/watchOS uses full-bleed 100%.
    let inset: CGFloat = macOSGrid ? s * 0.088 : 0
    let cardRect = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let cornerRadius: CGFloat = macOSGrid ? cardRect.width * 0.2237 : 0
    let cardPath = CGPath(roundedRect: cardRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

    // Soft macOS elevation shadow
    if macOSGrid {
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.018), blur: s * 0.035, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.22))
        ctx.addPath(cardPath)
        ctx.setFillColor(CGColor(red: 0.97, green: 0.965, blue: 0.953, alpha: 1))
        ctx.fillPath()
        ctx.restoreGState()
    }

    // Warm ceramic off-white surface (#FCFBF8 -> #ECEAE3)
    ctx.saveGState()
    ctx.addPath(cardPath)
    ctx.clip()

    let bgColors = [
        CGColor(red: 0.992, green: 0.988, blue: 0.978, alpha: 1.0),
        CGColor(red: 0.935, green: 0.927, blue: 0.908, alpha: 1.0)
    ] as CFArray
    let bgGrad = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 1.0])!
    ctx.drawLinearGradient(
        bgGrad,
        start: CGPoint(x: cardRect.midX, y: cardRect.maxY),
        end: CGPoint(x: cardRect.midX, y: cardRect.minY),
        options: []
    )

    // Subtle top ceramic sheen highlight
    let sheenColors = [
        CGColor(red: 1, green: 1, blue: 1, alpha: 0.55),
        CGColor(red: 1, green: 1, blue: 1, alpha: 0.0)
    ] as CFArray
    let sheenGrad = CGGradient(colorsSpace: colorSpace, colors: sheenColors, locations: [0.0, 1.0])!
    ctx.drawLinearGradient(
        sheenGrad,
        start: CGPoint(x: cardRect.midX, y: cardRect.maxY),
        end: CGPoint(x: cardRect.midX, y: cardRect.minY + cardRect.height * 0.52),
        options: []
    )

    // Razor-fine anodized inner rim
    if macOSGrid {
        ctx.addPath(cardPath)
        ctx.setStrokeColor(CGColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 0.07))
        ctx.setLineWidth(max(1.0, s * 0.004))
        ctx.strokePath()
    }

    // Centered genuine Apple SF Symbol `bolt.fill` in hardware vermilion-orange (#E84C24)
    let pointSize = cardRect.height * 0.50
    let symConfig = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
    if let symImage = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(symConfig)
    {
        // Rasterize the SF Symbol into an alpha mask at exact target pixel resolution
        let symSize = symImage.size
        let targetH = cardRect.height * 0.56
        let aspect = symSize.width / max(symSize.height, 1)
        let drawW = targetH * aspect
        let drawH = targetH
        let drawRect = CGRect(
            x: cardRect.midX - drawW / 2.0,
            y: cardRect.midY - drawH / 2.0,
            width: drawW,
            height: drawH
        )

        let maskRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: px,
            pixelsHigh: px,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        maskRep.size = NSSize(width: px, height: px)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: maskRep)
        NSColor.black.set()
        symImage.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1.0)
        NSGraphicsContext.restoreGraphicsState()

        if let maskCG = maskRep.cgImage {
            let fullRect = CGRect(x: 0, y: 0, width: s, height: s)

            // Subtle warm ambient drop shadow under bolt
            ctx.saveGState()
            ctx.setShadow(
                offset: CGSize(width: 0, height: -s * 0.012),
                blur: s * 0.026,
                color: CGColor(red: 0.85, green: 0.24, blue: 0.08, alpha: 0.24)
            )
            ctx.beginTransparencyLayer(auxiliaryInfo: nil)
            ctx.clip(to: fullRect, mask: maskCG)
            ctx.setFillColor(CGColor(red: 0.91, green: 0.30, blue: 0.14, alpha: 1.0))
            ctx.fill(drawRect.insetBy(dx: -4, dy: -4))
            ctx.endTransparencyLayer()
            ctx.restoreGState()

            // Crisp hardware vermilion-orange gradient clipped to SF Symbol bolt
            ctx.saveGState()
            ctx.clip(to: fullRect, mask: maskCG)
            let boltColors = [
                CGColor(red: 0.96, green: 0.37, blue: 0.19, alpha: 1.0),
                CGColor(red: 0.86, green: 0.24, blue: 0.09, alpha: 1.0)
            ] as CFArray
            let boltGrad = CGGradient(colorsSpace: colorSpace, colors: boltColors, locations: [0.0, 1.0])!
            ctx.drawLinearGradient(
                boltGrad,
                start: CGPoint(x: cardRect.midX, y: drawRect.maxY),
                end: CGPoint(x: cardRect.midX, y: drawRect.minY),
                options: []
            )
            ctx.restoreGState()
        }
    }

    ctx.restoreGState()
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func savePNG(_ rep: NSBitmapImageRep, to path: String) {
    let data = rep.representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: path))
}

let root = FileManager.default.currentDirectoryPath
let macIconset = "\(root)/App/Assets.xcassets/AppIcon.appiconset"

let macSizes: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for (name, px) in macSizes {
    savePNG(renderIcon(size: px, macOSGrid: true), to: "\(macIconset)/\(name)")
}

// Preview image & full-bleed iOS/watchOS master icon
savePNG(renderIcon(size: 1024, macOSGrid: true), to: "\(root)/scripts/icon-preview.png")

let iosRoot = "\(root)/../KangCharge-iOS"
if FileManager.default.fileExists(atPath: iosRoot) {
    let fullBleed = renderIcon(size: 1024, macOSGrid: false)
    savePNG(fullBleed, to: "\(iosRoot)/iOS/App/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
    savePNG(fullBleed, to: "\(iosRoot)/watchOS/App/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
}

print("SugarWatt icons generated successfully.")
