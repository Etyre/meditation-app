// Generates the app icon: a partially opened lotus on a dark teal ground,
// drawn with CoreGraphics so it needs nothing beyond Xcode's toolchain.
//
//   swift tool/gen_icon.swift
//
// Writes every size in ios/Runner/Assets.xcassets/AppIcon.appiconset/ and
// the Android mipmap ic_launcher.png files. The 1024 px marketing icon must
// be opaque, so the background fills the whole square (iOS rounds the
// corners itself; Android gets the same square, which launchers mask).
import AppKit
import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments[0])
    .deletingLastPathComponent().deletingLastPathComponent()

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xff) / 255,
            green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: alpha)
}

/// One petal: a leaf shape from the base point, bulging out to `width` and
/// tapering to a tip, rotated by `angle` (radians, 0 = straight up) and
/// scaled to `length`. Coordinates are in a 1000-unit square, y up.
func petal(ctx: CGContext, base: CGPoint, angle: CGFloat, length: CGFloat,
           width: CGFloat, fill: CGColor, edge: CGColor) {
    ctx.saveGState()
    ctx.translateBy(x: base.x, y: base.y)
    ctx.rotate(by: angle)
    let path = CGMutablePath()
    path.move(to: .zero)
    path.addCurve(to: CGPoint(x: 0, y: length),
                  control1: CGPoint(x: -width, y: length * 0.25),
                  control2: CGPoint(x: -width * 0.55, y: length * 0.95))
    path.addCurve(to: .zero,
                  control1: CGPoint(x: width * 0.55, y: length * 0.95),
                  control2: CGPoint(x: width, y: length * 0.25))
    path.closeSubpath()
    ctx.addPath(path)
    ctx.setFillColor(fill)
    ctx.fillPath()
    ctx.addPath(path)
    ctx.setStrokeColor(edge)
    ctx.setLineWidth(6)
    ctx.strokePath()
    ctx.restoreGState()
}

/// Draws the icon at `size` px into an opaque (no alpha channel) bitmap:
/// App Store Connect rejects a 1024 px icon with alpha, and every other
/// size is fully covered by the background anyway.
func draw(size: Int) -> CGImage {
    let space = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(data: nil, width: size, height: size,
                        bitsPerComponent: 8, bytesPerRow: 0, space: space,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)
    let s = CGFloat(size) / 1000
    ctx.scaleBy(x: s, y: s)

    // Ground: a vertical gradient around the app's seed colour.
    let gradient = CGGradient(colorsSpace: space,
                              colors: [color(0x1C2B27), color(0x3A5A50)] as CFArray,
                              locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 1000),
                           end: CGPoint(x: 0, y: 0), options: [])

    // Still water: a faint horizon and two ripples under the flower.
    ctx.setStrokeColor(color(0xFFFFFF, 0.10))
    ctx.setLineWidth(5)
    for (i, w) in [(0, 300.0), (1, 420.0)] {
        let y = 265.0 - CGFloat(i) * 42
        let rect = CGRect(x: 500 - w / 2, y: y - 14, width: w, height: 28)
        ctx.strokeEllipse(in: rect)
    }

    let base = CGPoint(x: 500, y: 300)
    let outer = color(0xD98FA6)   // dusky pink, outer petals
    let mid = color(0xEAB0C0)
    let inner = color(0xF6D3DC)   // pale centre bud
    let edge = color(0x8E4F63, 0.55)
    let deg = CGFloat.pi / 180

    // Outer petals, well open (partially opened lotus: these have spread
    // while the centre is still a bud).
    for a in [-78.0, 78.0] {
        petal(ctx: ctx, base: base, angle: a * deg, length: 330, width: 95,
              fill: outer, edge: edge)
    }
    for a in [-52.0, 52.0] {
        petal(ctx: ctx, base: base, angle: a * deg, length: 400, width: 105,
              fill: outer, edge: edge)
    }
    // Middle ring, half open.
    for a in [-28.0, 28.0] {
        petal(ctx: ctx, base: base, angle: a * deg, length: 460, width: 115,
              fill: mid, edge: edge)
    }
    // Centre bud: three nearly upright petals still closed around each
    // other.
    for a in [-9.0, 9.0] {
        petal(ctx: ctx, base: base, angle: a * deg, length: 500, width: 110,
              fill: inner, edge: edge)
    }
    petal(ctx: ctx, base: base, angle: 0, length: 540, width: 95,
          fill: color(0xFBE6EC), edge: edge)

    return ctx.makeImage()!
}

func write(_ image: CGImage, to url: URL) {
    let png = NSBitmapImageRep(cgImage: image)
        .representation(using: .png, properties: [:])!
    try! FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try! png.write(to: url)
    print("wrote", url.path.replacingOccurrences(of: root.path + "/", with: ""))
}

let iosDir = root.appendingPathComponent("ios/Runner/Assets.xcassets/AppIcon.appiconset")
let iosSizes: [(String, Int)] = [
    ("Icon-App-20x20@1x.png", 20), ("Icon-App-20x20@2x.png", 40),
    ("Icon-App-20x20@3x.png", 60), ("Icon-App-29x29@1x.png", 29),
    ("Icon-App-29x29@2x.png", 58), ("Icon-App-29x29@3x.png", 87),
    ("Icon-App-40x40@1x.png", 40), ("Icon-App-40x40@2x.png", 80),
    ("Icon-App-40x40@3x.png", 120), ("Icon-App-60x60@2x.png", 120),
    ("Icon-App-60x60@3x.png", 180), ("Icon-App-76x76@1x.png", 76),
    ("Icon-App-76x76@2x.png", 152), ("Icon-App-83.5x83.5@2x.png", 167),
    ("Icon-App-1024x1024@1x.png", 1024),
]
for (name, size) in iosSizes {
    write(draw(size: size), to: iosDir.appendingPathComponent(name))
}

let androidSizes: [(String, Int)] = [
    ("mipmap-mdpi", 48), ("mipmap-hdpi", 72), ("mipmap-xhdpi", 96),
    ("mipmap-xxhdpi", 144), ("mipmap-xxxhdpi", 192),
]
for (dir, size) in androidSizes {
    write(draw(size: size), to: root.appendingPathComponent(
        "android/app/src/main/res/\(dir)/ic_launcher.png"))
}
