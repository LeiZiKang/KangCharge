import AppKit

// Renders the Kang Charge app icon: candy gradient squircle, a stylised
// CoCan charger body with five ports, and a glowing bolt.
let out = URL(fileURLWithPath: CommandLine.arguments[1])
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

func color(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255, blue: CGFloat(hex & 0xff) / 255, alpha: a)
}

func render(_ pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)

    // Background squircle with drop shadow (macOS icon grid: 824pt body inset 100).
    let body = NSRect(x: 100, y: 100, width: 824, height: 824)
    let squircle = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: NSColor.black.withAlphaComponent(0.35).cgColor)
    color(0xFF4719).setFill()
    squircle.fill()
    ctx.restoreGState()
    NSGradient(colors: [color(0xFFB23F), color(0xFF4719), color(0xF0266A)], atLocations: [0, 0.5, 1], colorSpace: .sRGB)!
        .draw(in: squircle, angle: -60)
    // Soft top highlight.
    ctx.saveGState()
    squircle.addClip()
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.28), NSColor.white.withAlphaComponent(0)])!
        .draw(fromCenter: NSPoint(x: 330, y: 900), radius: 0, toCenter: NSPoint(x: 330, y: 900), radius: 620, options: [])
    ctx.restoreGState()

    // Charger body (the "can").
    let can = NSRect(x: 262, y: 222, width: 500, height: 580)
    let canPath = NSBezierPath(roundedRect: can, xRadius: 120, yRadius: 120)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 40, color: NSColor(srgbRed: 0.45, green: 0.05, blue: 0.1, alpha: 0.45).cgColor)
    NSColor.white.setFill()
    canPath.fill()
    ctx.restoreGState()
    NSGradient(colors: [NSColor.white, color(0xFFEDE6)])!.draw(in: canPath, angle: -90)

    // Screen.
    let screen = NSBezierPath(roundedRect: NSRect(x: 322, y: 470, width: 380, height: 270), xRadius: 58, yRadius: 58)
    NSGradient(colors: [color(0x2A1B1F), color(0x16161C)])!.draw(in: screen, angle: -90)

    // Bolt on screen.
    let bolt = NSBezierPath()
    bolt.move(to: NSPoint(x: 540, y: 712))
    bolt.line(to: NSPoint(x: 440, y: 590))
    bolt.line(to: NSPoint(x: 512, y: 590))
    bolt.line(to: NSPoint(x: 478, y: 498))
    bolt.line(to: NSPoint(x: 590, y: 626))
    bolt.line(to: NSPoint(x: 516, y: 626))
    bolt.close()
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 30, color: color(0xFF7A2F).cgColor)
    NSGradient(colors: [color(0xFFD04A), color(0xFF5A1F)])!.draw(in: bolt, angle: -90)
    ctx.restoreGState()

    // Five ports: A (wide) + C1–C4 (pills), coloured like the app.
    let portColors: [UInt32] = [0x29C7A3, 0xFF7329, 0xFF4D80, 0x9E66FF, 0x3D8FFF]
    let slots: [NSRect] = [
        NSRect(x: 330, y: 380, width: 150, height: 44),
        NSRect(x: 520, y: 380, width: 64, height: 44),
        NSRect(x: 612, y: 380, width: 64, height: 44),
        NSRect(x: 420, y: 300, width: 64, height: 44),
        NSRect(x: 540, y: 300, width: 64, height: 44),
    ]
    for (i, slot) in slots.enumerated() {
        let pill = NSBezierPath(roundedRect: slot, xRadius: 22, yRadius: i == 0 ? 10 : 22)
        color(0x2A1B1F).setFill()
        pill.fill()
        let dot = NSBezierPath(roundedRect: slot.insetBy(dx: 14, dy: 15), xRadius: 8, yRadius: 8)
        color(portColors[i]).setFill()
        dot.fill()
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

var images: [[String: String]] = []
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try! render(size * scale).write(to: out.appendingPathComponent(name))
        images.append(["idiom": "mac", "size": "\(size)x\(size)", "scale": "\(scale)x", "filename": name])
    }
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
try! JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys]).write(to: out.appendingPathComponent("Contents.json"))
try! render(1024).write(to: out.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("../scripts/icon-preview.png").standardizedFileURL)
