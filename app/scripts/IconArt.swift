#!/usr/bin/env swift
// Renders the iEnvs app icon (1024x1024 PNG) to the path given as argv[1].
// Visual language matches the menu bar mark in Sources/iEnvs/StatusIcon.swift:
// a circular badge with a negative-space "E" cut out of it. The cutout is
// done as a single even-odd fill of (circle path + glyph path) so it does not
// depend on text-compositing blend modes, which CoreText silently ignores
// for font-smoothed glyphs when there's no live window server connection
// (e.g. running this file via the `swift` CLI).

import AppKit
import CoreText

let size: CGFloat = 1024
let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "AppIcon.png"

func squirclePath(in rect: NSRect, cornerRadius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
}

/// CGPath for a single glyph, sized and centered within `rect`.
func glyphPath(_ character: Character, fontName: String, pointSize: CGFloat, centeredIn rect: CGRect, yOffset: CGFloat = 0) -> CGPath? {
    guard let ctFont = CTFontCreateWithName(fontName as CFString, pointSize, nil) as CTFont? else { return nil }
    var unichar = Array(String(character).utf16)
    var glyph = [CGGlyph](repeating: 0, count: unichar.count)
    guard CTFontGetGlyphsForCharacters(ctFont, &unichar, &glyph, unichar.count), let g = glyph.first else { return nil }
    guard let path = CTFontCreatePathForGlyph(ctFont, g, nil) else { return nil }

    let box = path.boundingBoxOfPath
    let dx = rect.midX - box.midX
    let dy = rect.midY - box.midY + yOffset
    var transform = CGAffineTransform(translationX: dx, y: dy)
    return path.copy(using: &transform)
}

func roundedFontName(weight: NSFont.Weight, size: CGFloat) -> String {
    let base = NSFont.systemFont(ofSize: size, weight: weight)
    if let descriptor = base.fontDescriptor.withDesign(.rounded),
       let rounded = NSFont(descriptor: descriptor, size: size) {
        return rounded.fontName
    }
    return base.fontName
}

let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
    let context = NSGraphicsContext.current?.cgContext

    // Background squircle with a diagonal indigo -> blue gradient.
    let cornerRadius = size * 0.2231
    let bgPath = squirclePath(in: rect, cornerRadius: cornerRadius)
    bgPath.addClip()

    let colors = [
        NSColor(calibratedRed: 0.09, green: 0.09, blue: 0.32, alpha: 1).cgColor,
        NSColor(calibratedRed: 0.15, green: 0.32, blue: 0.90, alpha: 1).cgColor,
        NSColor(calibratedRed: 0.35, green: 0.55, blue: 0.98, alpha: 1).cgColor,
    ] as CFArray
    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: colors,
        locations: [0, 0.55, 1]
    )!
    context?.drawLinearGradient(
        gradient,
        start: CGPoint(x: rect.minX, y: rect.maxY),
        end: CGPoint(x: rect.maxX, y: rect.minY),
        options: []
    )

    // Soft top-left gloss highlight for depth.
    context?.saveGState()
    let glossGradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            NSColor.white.withAlphaComponent(0.22).cgColor,
            NSColor.white.withAlphaComponent(0.0).cgColor,
        ] as CFArray,
        locations: [0, 1]
    )!
    context?.drawRadialGradient(
        glossGradient,
        startCenter: CGPoint(x: rect.midX - 120, y: rect.maxY - 120),
        startRadius: 0,
        endCenter: CGPoint(x: rect.midX - 120, y: rect.maxY - 120),
        endRadius: size * 0.65,
        options: []
    )
    context?.restoreGState()

    // White badge circle, sized to feel full-bleed per Apple icon guidance,
    // with a negative-space "E" punched out in a single even-odd fill.
    let badgeInset = size * 0.135
    let badgeRect = rect.insetBy(dx: badgeInset, dy: badgeInset)
    let badgeCirclePath = CGPath(ellipseIn: badgeRect, transform: nil)

    let fontName = roundedFontName(weight: .bold, size: size * 0.44)
    guard let ePath = glyphPath(
        "E",
        fontName: fontName,
        pointSize: size * 0.44,
        centeredIn: badgeRect,
        yOffset: -size * 0.012
    ) else {
        FileHandle.standardError.write("Failed to build glyph path\n".data(using: .utf8)!)
        exit(1)
    }

    let stencil = CGMutablePath()
    stencil.addPath(badgeCirclePath)
    stencil.addPath(ePath)

    context?.saveGState()
    context?.setFillColor(NSColor.white.withAlphaComponent(0.97).cgColor)
    context?.addPath(stencil)
    context?.fillPath(using: .evenOdd)
    context?.restoreGState()

    return true
}

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:])
else {
    FileHandle.standardError.write("Failed to render icon\n".data(using: .utf8)!)
    exit(1)
}

try png.write(to: URL(fileURLWithPath: outputPath))
print("wrote \(outputPath)")
