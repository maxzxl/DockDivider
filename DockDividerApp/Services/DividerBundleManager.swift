import AppKit
import Foundation

final class DividerBundleManager {
    let paths: AppPaths
    let launcher: URL?
    init(paths: AppPaths, launcher: URL? = nil) {
        self.paths = paths
        self.launcher = launcher ?? Bundle.main.url(forResource: "DividerLauncher", withExtension: nil)
    }
    func tile(for record: DividerRecord, variant: RenderVariant, existing: [String: Any]) throws -> [String: Any] {
        var raw = existing
        raw["GUID"] = NSNumber(value: record.guid)
        raw["tile-type"] = record.style.tileType
        raw["dock-divider-id"] = record.id.uuidString
        if !record.style.isLine {
            raw["tile-data"] = [String: Any]()
            return raw
        }
        let url = try ensureBundle(for: record, variant: variant)
        var data = raw["tile-data"] as? [String: Any] ?? [:]
        // A zero-width display name reduces hover clutter. Dock can still show
        // a tooltip or context menu; public APIs cannot suppress those entirely.
        data["file-label"] = "\u{200B}"
        data["file-type"] = 41
        data["bundle-identifier"] = "app.dockdivider.element.\(record.id.uuidString.lowercased())"
        data["file-data"] = ["_CFURLString": url.absoluteString, "_CFURLStringType": 15]
        // Old bookmark/alias bytes refer to the old variant and must not survive.
        data.removeValue(forKey: "book")
        raw["tile-data"] = data
        return raw
    }
    func ensureBundle(for record: DividerRecord, variant: RenderVariant) throws -> URL {
        let fm = FileManager.default
        let parent = paths.bundles.appendingPathComponent(record.id.uuidString, isDirectory: true)
        let destination = parent.appendingPathComponent("\(record.style.rawValue)-\(variant.key).app", isDirectory: true)
        if fm.fileExists(atPath: destination.path) {
            let info = try Plist.dictionary(at: destination.appendingPathComponent("Contents/Info.plist"))
            guard info["DockDividerID"] as? String == record.id.uuidString,
                  fm.isExecutableFile(atPath: destination.appendingPathComponent("Contents/MacOS/DividerLauncher").path),
                  fm.fileExists(atPath: destination.appendingPathComponent("Contents/Resources/Divider.icns").path) else {
                throw DockError.invalid(L10n.string("error.bundle_incomplete"))
            }
            return destination
        }
        guard let launcher, fm.isExecutableFile(atPath: launcher.path) else {
            throw DockError.io(L10n.string("error.launcher_missing"))
        }
        try fm.createDirectory(at: parent, withIntermediateDirectories: true)
        let staging = parent.appendingPathComponent(".staging-\(UUID().uuidString).app", isDirectory: true)
        defer { try? fm.removeItem(at: staging) }
        let contents = staging.appendingPathComponent("Contents", isDirectory: true)
        let resources = contents.appendingPathComponent("Resources", isDirectory: true)
        let executable = contents.appendingPathComponent("MacOS/DividerLauncher")
        try fm.createDirectory(at: resources, withIntermediateDirectories: true)
        try fm.createDirectory(at: executable.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fm.copyItem(at: launcher, to: executable)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
        let info: [String: Any] = [
            "CFBundleIdentifier": "app.dockdivider.element.\(record.id.uuidString.lowercased())",
            "CFBundleName": "\u{200B}", "CFBundleDisplayName": "\u{200B}",
            "CFBundleExecutable": "DividerLauncher", "CFBundlePackageType": "APPL",
            "CFBundleVersion": String(variant.iconVersion), "CFBundleShortVersionString": "1.0",
            "CFBundleIconFile": "Divider.icns", "LSMinimumSystemVersion": "14.0",
            "LSUIElement": true, "LSBackgroundOnly": true,
            "DockDividerID": record.id.uuidString, "DockDividerStyle": record.style.rawValue,
            "DockDividerIconVersion": variant.iconVersion
        ]
        try Plist.data(info).write(to: contents.appendingPathComponent("Info.plist"), options: .atomic)
        let icon = try DividerRenderer.icon(style: record.style, variant: variant)
        try icon.write(to: resources.appendingPathComponent("Divider.icns"), options: .atomic)
        try ProcessRunner.run("/usr/bin/codesign", ["--force", "--sign", "-", "--timestamp=none", staging.path])
        try ProcessRunner.run("/usr/bin/codesign", ["--verify", "--strict", staging.path])
        if variant.iconVersion >= 2 {
            // Tahoe wraps legacy app icons in a gray squircle. A standard Finder
            // custom icon preserves the original transparency instead. Sign and
            // strictly verify first; Finder then adds its normal icon metadata.
            guard let image = NSImage(data: icon),
                  NSWorkspace.shared.setIcon(image, forFile: staging.path, options: []) else {
                throw DockError.io(L10n.string("error.custom_icon"))
            }
            // The executable and sealed Contents remain signed. --strict rejects
            // Finder's custom-icon metadata; normal verification includes all
            // sealed resources and succeeds with that supported file metadata.
            try ProcessRunner.run("/usr/bin/codesign", ["--verify", staging.path])
        }
        try fm.moveItem(at: staging, to: destination)
        // Immutable, appearance-specific paths avoid rewriting signed bundles
        // and let Dock load a fresh icon without deleting its global caches.
        return destination
    }
}
