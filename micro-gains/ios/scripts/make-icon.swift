#!/usr/bin/env swift
// Generates the 1024x1024 App Store icon: a green upward staircase on black.
// Run from the ios/ directory:
//
//     swift scripts/make-icon.swift MicroGains/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png
//
// No external tools. CoreGraphics + ImageIO only.
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024.0
let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "icon-1024.png"

guard let space = CGColorSpace(name: CGColorSpace.sRGB),
      let ctx = CGContext(
          data: nil,
          width: Int(size),
          height: Int(size),
          bitsPerComponent: 8,
          bytesPerRow: 0,
          space: space,
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      )
else {
    fatalError("could not create a bitmap context")
}

func color(_ hex: UInt32) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: 1
    )
}

// Black field.
ctx.setFillColor(color(0x000000))
ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

// A staircase climbing to the right: one thick stroked polyline with round
// joins, plus a dimmer slab underneath so the mark still has mass at 40pt.
// CoreGraphics origin is bottom-left.
let steps: [CGPoint] = [
    CGPoint(x: 200, y: 352),
    CGPoint(x: 408, y: 352),
    CGPoint(x: 408, y: 512),
    CGPoint(x: 616, y: 512),
    CGPoint(x: 616, y: 672),
    CGPoint(x: 824, y: 672)
]

// Slab: the staircase profile closed down to the baseline.
let slab = CGMutablePath()
slab.move(to: CGPoint(x: 200, y: 312))
for point in steps { slab.addLine(to: point) }
slab.addLine(to: CGPoint(x: 824, y: 312))
slab.closeSubpath()
ctx.setFillColor(color(0x1F7A3A))
ctx.addPath(slab)
ctx.fillPath()

// Tread line.
ctx.setStrokeColor(color(0x3DDC6A))
ctx.setLineWidth(84)
ctx.setLineJoin(.round)
ctx.setLineCap(.round)
ctx.move(to: steps[0])
for point in steps.dropFirst() { ctx.addLine(to: point) }
ctx.strokePath()

guard let image = ctx.makeImage() else { fatalError("could not render the image") }
let url = URL(fileURLWithPath: outputPath)
guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    fatalError("could not open \(outputPath) for writing")
}
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("could not write \(outputPath)") }
print("wrote \(outputPath)")
