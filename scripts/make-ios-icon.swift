// Run: swift scripts/make-ios-icon.swift
import AppKit
import CoreGraphics

let size = 1024
let cg = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
                   space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
let context = NSGraphicsContext(cgContext: cg, flipped: false)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
let colors = [CGColor(red: 1, green: 154.0/255, blue: 60.0/255, alpha: 1),
              CGColor(red: 1, green: 78.0/255, blue: 26.0/255, alpha: 1)]
let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])!
cg.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 1024), end: CGPoint(x: 1024, y: 0), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
let symbol = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: nil)!
    .withSymbolConfiguration(.init(pointSize: 560, weight: .semibold))!
let ratio = symbol.size.width / symbol.size.height
let height: CGFloat = 564
let rect = CGRect(x: (1024 - height * ratio) / 2, y: 1024 * 0.45 - height / 2, width: height * ratio, height: height)
let white = NSImage(size: symbol.size)
white.lockFocus()
NSColor.white.setFill()
NSRect(origin: .zero, size: symbol.size).fill()
symbol.draw(in: NSRect(origin: .zero, size: symbol.size), from: .zero, operation: .destinationIn, fraction: 1)
white.unlockFocus()
white.draw(in: rect)
NSGraphicsContext.restoreGraphicsState()
let destination = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("iOS/App/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
let bitmap = NSBitmapImageRep(cgImage: cg.makeImage()!)
try bitmap.representation(using: .png, properties: [:])!.write(to: destination)
