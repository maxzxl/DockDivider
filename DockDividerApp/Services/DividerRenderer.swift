import AppKit
import ImageIO
import UniformTypeIdentifiers

enum DividerRenderer {
    static func png(style: DividerStyle, variant: RenderVariant, pixels: Int) throws -> Data {
        guard style.isLine, pixels > 0,
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8,
                                      bytesPerRow: pixels * 4, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw DockError.invalid(L10n.string("error.render"))
        }
        let size = Double(pixels)
        // Clear the full bitmap explicitly: only the line contributes alpha.
        context.clear(CGRect(x: 0, y: 0, width: pixels, height: pixels))
        let thickness = max(size * style.lineWidth / 64, 0.5)
        let length = size * style.lineHeight
        let horizontal = variant.orientation.isVertical
        let rect = CGRect(x: (size - (horizontal ? length : thickness)) / 2,
                          y: (size - (horizontal ? thickness : length)) / 2,
                          width: horizontal ? length : thickness,
                          height: horizontal ? thickness : length)
        let brightness: CGFloat = variant.dark ? 1 : 0
        context.setFillColor(CGColor(gray: brightness, alpha: style.opacity))
        context.fill(rect)
        guard let image = context.makeImage() else { throw DockError.io(L10n.string("error.empty_image")) }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            throw DockError.io(L10n.string("error.png_encoder"))
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw DockError.io(L10n.string("error.png_save")) }
        return data as Data
    }
    static func icon(style: DividerStyle, variant: RenderVariant) throws -> Data {
        // PNG-backed modern ICNS representations, including Retina slots.
        let slots = [("icp4", 16), ("icp5", 32), ("icp6", 64), ("ic07", 128),
                     ("ic08", 256), ("ic09", 512), ("ic10", 1024),
                     ("ic11", 32), ("ic12", 64), ("ic13", 256), ("ic14", 512)]
        var body = Data()
        for (type, pixels) in slots {
            let png = try png(style: style, variant: variant, pixels: pixels)
            body.append(contentsOf: type.utf8)
            body.append(bigEndian: UInt32(png.count + 8))
            body.append(png)
        }
        var result = Data("icns".utf8)
        result.append(bigEndian: UInt32(body.count + 8))
        result.append(body)
        return result
    }
}

private extension Data {
    mutating func append(bigEndian value: UInt32) {
        var encoded = value.bigEndian
        Swift.withUnsafeBytes(of: &encoded) { append(contentsOf: $0) }
    }
}
