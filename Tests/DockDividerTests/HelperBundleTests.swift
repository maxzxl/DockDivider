import Testing
import Foundation
import AppKit
@testable import DockDividerApp

@Suite("Helper bundles", .serialized)
final class HelperBundleTests {
    let paths = AppPaths(root: FileManager.default.temporaryDirectory.appendingPathComponent("DockDividerHelperTests-\(UUID().uuidString)"))
    deinit { try? FileManager.default.removeItem(at: paths.root) }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["DOCK_DIVIDER_TEST_LAUNCHER"] != nil))
    func signedBundlesLaunchAndRestoreTheirActualAppearance() throws {
        let launcherPath = try #require(ProcessInfo.processInfo.environment["DOCK_DIVIDER_TEST_LAUNCHER"])
        let manager = DividerBundleManager(paths: paths, launcher: URL(fileURLWithPath: launcherPath))
        let registry = try DividerRegistry(paths: paths)
        for (index, style) in [DividerStyle.system, .thin, .standard].enumerated() {
            let record = DividerRecord(id: UUID(), guid: UInt32(index + 100), style: style, position: index,
                                       variant: RenderVariant(dark: false, orientation: .bottom))
            try registry.register([record])
            let dark = RenderVariant(dark: true, orientation: .left)
            let raw = try manager.tile(for: record, variant: dark, existing: [:])
            let url = try #require(DockItem.fileURL(in: raw))
            let info = try Plist.dictionary(at: url.appendingPathComponent("Contents/Info.plist"))
            #expect(info["LSUIElement"] as? Bool == true)
            #expect(info["LSBackgroundOnly"] as? Bool == true)
            #expect(registry.record(for: raw)?.variant == dark)
            try ProcessRunner.run("/usr/bin/codesign", ["--verify", url.path])
            try ProcessRunner.run(url.appendingPathComponent("Contents/MacOS/DividerLauncher").path, [])
            #expect(NSImage(contentsOf: url.appendingPathComponent("Contents/Resources/Divider.icns")) != nil)
            let iconBefore = try Data(contentsOf: url.appendingPathComponent("Contents/Resources/Divider.icns"))
            let sameURL = try manager.ensureBundle(for: record, variant: dark)
            #expect(sameURL == url)
            #expect(try Data(contentsOf: sameURL.appendingPathComponent("Contents/Resources/Divider.icns")) == iconBefore)
            let lightURL = try manager.ensureBundle(for: record, variant: RenderVariant(dark: false, orientation: .bottom))
            #expect(lightURL != url)
            #expect(FileManager.default.fileExists(atPath: url.path))
            var foreign = raw
            foreign["tile-data"] = ["file-data": ["_CFURLString": "file:///Applications/Safari.app"]]
            #expect(registry.record(for: foreign) == nil)
        }
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["DOCK_DIVIDER_TEST_LAUNCHER"] != nil))
    func legacyBundlesRemainOwnedAndNewIconsStayTransparentInIconServices() throws {
        let launcherPath = try #require(ProcessInfo.processInfo.environment["DOCK_DIVIDER_TEST_LAUNCHER"])
        let manager = DividerBundleManager(paths: paths, launcher: URL(fileURLWithPath: launcherPath))
        let registry = try DividerRegistry(paths: paths)
        let legacy = RenderVariant(dark: true, orientation: .bottom, iconVersion: 1)
        let current = RenderVariant(dark: true, orientation: .bottom)
        let record = DividerRecord(id: UUID(), guid: 101, style: .system, position: 1, variant: legacy)
        try registry.register([record])
        let oldTile = try manager.tile(for: record, variant: legacy, existing: [:])
        let oldURL = try #require(DockItem.fileURL(in: oldTile))
        #expect(registry.record(for: oldTile)?.variant == legacy)

        let tile = try manager.tile(for: record, variant: current, existing: oldTile)
        let url = try #require(DockItem.fileURL(in: tile))
        #expect(url != oldURL)
        #expect(registry.record(for: tile)?.variant == current)
        #expect(FileManager.default.fileExists(atPath: oldURL.path))
        try ProcessRunner.run("/usr/bin/codesign", ["--verify", url.path])
        // Observe the image supplied by the OS icon service, not just our PNG.
        let image = NSWorkspace.shared.icon(forFile: url.path)
        let bitmap = try #require(image.cgImage(forProposedRect: nil, context: nil, hints: nil))
        let context = try #require(CGContext(data: nil, width: 128, height: 128, bitsPerComponent: 8,
                                            bytesPerRow: 512, space: CGColorSpaceCreateDeviceRGB(),
                                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.clear(CGRect(x: 0, y: 0, width: 128, height: 128))
        context.draw(bitmap, in: CGRect(x: 0, y: 0, width: 128, height: 128))
        let pixels = try #require(context.data).assumingMemoryBound(to: UInt8.self)
        let nontransparent = (0..<(128 * 128)).filter { pixels[$0 * 4 + 3] != 0 }.count
        #expect(nontransparent > 0)
        #expect(nontransparent < 128 * 128 / 10)
        #expect(pixels[(64 * 128 + 20) * 4 + 3] == 0)
    }
}
