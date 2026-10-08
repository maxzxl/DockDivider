#!/usr/bin/env swift
import AppKit
import ImageIO
import UniformTypeIdentifiers

// Reproducible geometric artwork. The native .icon keeps its layers unflattened;
// ICNS is the fallback for macOS 14/15 and builds with Command Line Tools only.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resources = root.appendingPathComponent("Resources")
let assets = resources.appendingPathComponent("AppIcon.icon/Assets")
try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
let space = CGColorSpace(name: CGColorSpace.sRGB)!
func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: space, components: [r, g, b, a])!
}
func rounded(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}
func gradient(_ c: CGContext, _ path: CGPath, _ colors: [CGColor], _ start: CGPoint, _ end: CGPoint) {
    c.saveGState(); c.addPath(path); c.clip()
    c.drawLinearGradient(CGGradient(colorsSpace: space, colors: colors as CFArray, locations: nil)!,
                         start: start, end: end, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    c.restoreGState()
}
func dockPath() -> CGPath { rounded(CGRect(x: 130, y: 322, width: 764, height: 380), 114) }
func tilesPath() -> CGPath {
    let path = CGMutablePath()
    for x: CGFloat in [207, 349, 563, 705] {
        path.addPath(rounded(CGRect(x: x, y: 452, width: 112, height: 120), 29))
    }
    return path
}
func dividerPath() -> CGPath { rounded(CGRect(x: 497, y: 382, width: 30, height: 260), 15) }
func drawArtwork(_ c: CGContext) {
    // Translucent Dock plate, bright app tiles and a crisp raised divider.
    c.saveGState()
    c.setShadow(offset: CGSize(width: 0, height: -18), blur: 28, color: color(0.02, 0.09, 0.30, 0.32))
    c.addPath(dockPath()); c.setFillColor(color(0.85, 0.96, 1, 0.18)); c.fillPath()
    c.restoreGState()
    gradient(c, dockPath(), [color(0.90, 0.99, 1, 0.38), color(0.68, 0.85, 1, 0.13)], CGPoint(x: 260, y: 700), CGPoint(x: 770, y: 320))
    c.addPath(dockPath()); c.setLineWidth(2.5); c.setStrokeColor(color(1, 1, 1, 0.44)); c.strokePath()
    c.saveGState(); c.setShadow(offset: CGSize(width: 0, height: -7), blur: 10, color: color(0.03, 0.14, 0.39, 0.22))
    c.addPath(tilesPath()); c.setFillColor(color(0.84, 0.94, 1, 0.80)); c.fillPath(); c.restoreGState()
    gradient(c, tilesPath(), [color(1, 1, 1, 0.95), color(0.73, 0.88, 1, 0.80)], CGPoint(x: 400, y: 590), CGPoint(x: 620, y: 430))
    c.saveGState(); c.setShadow(offset: CGSize(width: 0, height: -6), blur: 14, color: color(0.03, 0.13, 0.36, 0.34))
    c.addPath(dividerPath()); c.setFillColor(color(1, 1, 1)); c.fillPath(); c.restoreGState()
}
func png(pixels: Int, layer: String? = nil) -> Data {
    let c = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: pixels * 4,
                      space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    c.clear(CGRect(x: 0, y: 0, width: pixels, height: pixels))
    c.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    if let layer {
        let path = layer == "Dock" ? dockPath() : layer == "Tiles" ? tilesPath() : dividerPath()
        c.addPath(path); c.setFillColor(color(1, 1, 1)); c.fillPath()
    } else {
        let enclosure = rounded(CGRect(x: 88, y: 88, width: 848, height: 848), 190)
        c.saveGState(); c.setShadow(offset: CGSize(width: 0, height: -10), blur: 18, color: color(0.02, 0.08, 0.24, 0.18))
        c.addPath(enclosure); c.setFillColor(color(0.16, 0.33, 0.75)); c.fillPath(); c.restoreGState()
        gradient(c, enclosure, [color(0.20, 0.79, 0.91), color(0.17, 0.39, 0.87), color(0.34, 0.27, 0.74)],
                 CGPoint(x: 150, y: 940), CGPoint(x: 820, y: 100))
        c.saveGState(); c.addPath(enclosure); c.clip()
        c.translateBy(x: 88, y: 88); c.scaleBy(x: 848 / 1024, y: 848 / 1024)
        drawArtwork(c); c.restoreGState()
        c.addPath(enclosure); c.setLineWidth(2); c.setStrokeColor(color(1, 1, 1, 0.22)); c.strokePath()
    }
    let output = NSMutableData()
    let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, c.makeImage()!, nil)
    precondition(CGImageDestinationFinalize(destination))
    return output as Data
}
for name in ["Dock", "Tiles", "Divider"] {
    try png(pixels: 1024, layer: name).write(to: assets.appendingPathComponent("\(name).png"))
}
try png(pixels: 1024).write(to: resources.appendingPathComponent("AppIcon-preview.png"))
func bytes(_ value: UInt32) -> Data {
    var big = value.bigEndian
    return withUnsafeBytes(of: &big) { Data($0) }
}
var body = Data()
for (slot, size) in [("icp4", 16), ("icp5", 32), ("icp6", 64), ("ic07", 128), ("ic08", 256), ("ic09", 512),
                     ("ic10", 1024), ("ic11", 32), ("ic12", 64), ("ic13", 256), ("ic14", 512)] {
    let image = png(pixels: size)
    body.append(Data(slot.utf8)); body.append(bytes(UInt32(image.count + 8))); body.append(image)
}
var icon = Data("icns".utf8); icon.append(bytes(UInt32(body.count + 8))); icon.append(body)
try icon.write(to: resources.appendingPathComponent("DockDivider.icns"))
print("Generated DockDivider.icns, preview and three Icon Composer layers.")
