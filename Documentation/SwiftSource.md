# Vollständiger Swift-Code

Dieses Dokument ist ein Quellcode-Snapshot von DockDivider. Die ausführbaren Originaldateien stehen unter den jeweils angegebenen Pfaden. Für Änderungen die Originaldateien bearbeiten. Die deutschen und englischen Texte befinden sich separat in `DockDividerApp/Resources/{de,en}.lproj/Localizable.strings`.

## Package.swift

```swift
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "DockDivider",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "DockDivider", targets: ["DockDividerApp"])],
    targets: [
        .executableTarget(name: "DockDividerApp", path: "DockDividerApp", resources: [.process("Resources")]),
        .executableTarget(name: "DividerLauncher", path: "DividerLauncher"),
        .testTarget(name: "DockDividerTests", dependencies: ["DockDividerApp"], path: "Tests/DockDividerTests")
    ]
)
```

## DockDividerApp/DockDividerApp.swift

```swift
import AppKit
import SwiftUI

@main
struct DockDividerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = DockViewModel()
    var body: some Scene {
        Window("DockDivider", id: "main") {
            ContentView(model: model)
        }
        .defaultSize(width: 800, height: 820)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .toolbar) {
                Button(L10n.string("dock.read_menu")) { model.reload() }.disabled(model.hasChanges)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
```

## DockDividerApp/Models/DividerStyle.swift

```swift
import Foundation

enum DividerStyle: String, CaseIterable, Codable, Identifiable {
    case system, thin, standard, spacer, smallSpacer
    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: L10n.string("style.system")
        case .thin: L10n.string("style.thin")
        case .standard: L10n.string("style.standard")
        case .spacer: L10n.string("style.spacer")
        case .smallSpacer: L10n.string("style.small_spacer")
        }
    }
    var detail: String {
        switch self {
        case .system: L10n.string("style.system_detail")
        case .thin: L10n.string("style.thin_detail")
        case .standard: L10n.string("style.standard_detail")
        case .spacer: L10n.string("style.spacer_detail")
        case .smallSpacer: L10n.string("style.small_spacer_detail")
        }
    }
    var isLine: Bool { self != .spacer && self != .smallSpacer }
    var tileType: String {
        switch self {
        case .spacer: "spacer-tile"
        case .smallSpacer: "small-spacer-tile"
        default: "file-tile"
        }
    }
    // Relative to a 64pt icon, not Apple's private separator metrics.
    var lineWidth: Double { self == .standard ? 2 : (self == .thin ? 0.75 : 1) }
    var lineHeight: Double { self == .thin ? 0.64 : 0.82 }
    var opacity: Double { self == .standard ? 0.42 : (self == .thin ? 0.30 : 0.23) }
}

enum DockOrientation: String, Codable {
    case bottom, left, right
    var isVertical: Bool { self != .bottom }
}

struct RenderVariant: Codable, Equatable {
    static let currentIconVersion = 2
    var dark: Bool
    var orientation: DockOrientation
    var iconVersion: Int
    init(dark: Bool, orientation: DockOrientation, iconVersion: Int = currentIconVersion) {
        self.dark = dark
        self.orientation = orientation
        self.iconVersion = iconVersion
    }
    private enum CodingKeys: String, CodingKey { case dark, orientation, iconVersion }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        dark = try values.decode(Bool.self, forKey: .dark)
        orientation = try values.decode(DockOrientation.self, forKey: .orientation)
        // Existing registries predate the explicit custom-icon treatment.
        iconVersion = try values.decodeIfPresent(Int.self, forKey: .iconVersion) ?? 1
    }
    var key: String { "v\(iconVersion)-\(dark ? "dark" : "light")-\(orientation.rawValue)" }
}

struct DividerRecord: Codable, Identifiable, Equatable {
    var id: UUID
    var guid: UInt32
    var style: DividerStyle
    var position: Int
    var variant: RenderVariant?
}
```

## DockDividerApp/Models/DockItem.swift

```swift
import Foundation

struct DockItem: Identifiable {
    let id: String
    var raw: [String: Any]
    var divider: DividerRecord?
    var isFinder = false
    var isManaged: Bool { divider != nil }
    var url: URL? { Self.fileURL(in: raw) }
    var title: String {
        if isFinder { return "Finder" }
        if let divider { return divider.style.title }
        let data = raw["tile-data"] as? [String: Any] ?? [:]
        if let label = data["file-label"] as? String, !label.isEmpty { return label }
        if raw["tile-type"] as? String == "spacer-tile" { return L10n.string("item.spacer") }
        if raw["tile-type"] as? String == "small-spacer-tile" { return L10n.string("item.small_spacer") }
        return url?.deletingPathExtension().lastPathComponent ?? L10n.string("item.fallback")
    }
    static func fileURL(in raw: [String: Any]) -> URL? {
        let data = raw["tile-data"] as? [String: Any]
        let file = data?["file-data"] as? [String: Any]
        guard let value = file?["_CFURLString"] as? String else { return nil }
        if value.hasPrefix("/") { return URL(fileURLWithPath: value) }
        return URL(string: value)
    }
    static func guid(in raw: [String: Any]) -> UInt32? {
        guard let number = raw["GUID"] as? NSNumber,
              number.int64Value > 0, number.uint64Value <= UInt32.max else { return nil }
        return number.uint32Value
    }
}

struct DockSnapshot {
    var domain: [String: Any]
    var apps: [[String: Any]] { domain["persistent-apps"] as? [[String: Any]] ?? [] }
    var orientation: DockOrientation {
        DockOrientation(rawValue: domain["orientation"] as? String ?? "bottom") ?? .bottom
    }
    var tileSize: Double { (domain["tilesize"] as? NSNumber)?.doubleValue ?? 48 }
}
```

## DockDividerApp/Services/BackupStore.swift

```swift
import Foundation

final class BackupStore {
    let paths: AppPaths
    init(paths: AppPaths) { self.paths = paths }
    @discardableResult
    func save(_ snapshot: DockSnapshot) throws -> URL {
        let fm = FileManager.default
        try fm.createDirectory(at: paths.backups, withIntermediateDirectories: true)
        let data = try Plist.data(snapshot.domain)
        let archive = paths.backups.appendingPathComponent("\(Int(Date().timeIntervalSince1970))-\(UUID().uuidString).plist")
        try data.write(to: archive, options: .atomic)
        if !fm.fileExists(atPath: paths.original.path) { try data.write(to: paths.original, options: .atomic) }
        try data.write(to: paths.previous, options: .atomic)
        guard Plist.equal(try Plist.dictionary(at: archive), snapshot.domain) else {
            throw DockError.io(L10n.string("error.backup_verify"))
        }
        return archive
    }
    func load(original: Bool) throws -> DockSnapshot {
        let domain = try Plist.dictionary(at: original ? paths.original : paths.previous)
        guard domain["persistent-apps"] is [[String: Any]] else { throw DockError.invalid(L10n.string("error.backup_apps")) }
        return DockSnapshot(domain: domain)
    }
    var hasPrevious: Bool { FileManager.default.fileExists(atPath: paths.previous.path) }
    var hasOriginal: Bool { FileManager.default.fileExists(atPath: paths.original.path) }
}
```

## DockDividerApp/Services/DemoDockPreferences.swift

```swift
import Foundation

// In-memory mode for UI development; it never touches com.apple.dock.
final class DemoDockPreferences: DockPreferences {
    var isManaged: Bool { false }
    private var snapshot: DockSnapshot
    init() {
        let paths = ["/System/Applications/Calendar.app", "/Applications/Safari.app",
                     "/System/Applications/Mail.app", "/System/Applications/Notes.app", "/System/Applications/Music.app"]
        snapshot = DockSnapshot(domain: ["persistent-apps": paths.enumerated().map { index, path in
            ["GUID": index + 1, "tile-type": "file-tile", "tile-data": [
                "file-label": URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent,
                "file-data": ["_CFURLString": URL(fileURLWithPath: path).absoluteString, "_CFURLStringType": 15]
            ]] as [String: Any]
        }, "persistent-others": [], "orientation": "bottom", "tilesize": 52])
    }
    func read() throws -> DockSnapshot { snapshot }
    func writeApps(_ apps: [[String: Any]]) throws { snapshot.domain["persistent-apps"] = apps }
}
```

## DockDividerApp/Services/DividerBundleManager.swift

```swift
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
```

## DockDividerApp/Services/DividerRegistry.swift

```swift
import Foundation

final class DividerRegistry {
    private let paths: AppPaths
    private(set) var records: [DividerRecord]
    init(paths: AppPaths) throws {
        self.paths = paths
        if FileManager.default.fileExists(atPath: paths.registry.path) {
            records = try JSONDecoder().decode([DividerRecord].self, from: Data(contentsOf: paths.registry))
        } else { records = [] }
        guard Set(records.map(\.id)).count == records.count,
              Set(records.map(\.guid)).count == records.count else {
            throw DockError.invalid(L10n.string("error.registry_duplicates"))
        }
    }
    func register(_ newRecords: [DividerRecord]) throws {
        var merged = records
        for record in newRecords {
            if let index = merged.firstIndex(where: { $0.id == record.id }) { merged[index] = record }
            else { merged.append(record) }
        }
        try FileManager.default.createDirectory(at: paths.root, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(merged).write(to: paths.registry, options: .atomic)
        records = merged
        // Keep historical ownership: old backups can still reference these IDs.
    }
    func record(for raw: [String: Any]) -> DividerRecord? {
        guard let guid = DockItem.guid(in: raw),
              var record = records.first(where: { $0.guid == guid }),
              raw["tile-type"] as? String == record.style.tileType else { return nil }
        if !record.style.isLine {
            // Dock may discard custom metadata. The recorded GUID + exact spacer
            // type remain necessary; unrelated spacers are never matched by type alone.
            guard DockItem.fileURL(in: raw) == nil else { return nil }
            return record
        }
        guard let url = DockItem.fileURL(in: raw), url.isFileURL else { return nil }
        let parent = paths.bundles.appendingPathComponent(record.id.uuidString, isDirectory: true)
        guard url.deletingLastPathComponent().standardizedFileURL == parent.standardizedFileURL,
              let info = try? Plist.dictionary(at: url.appendingPathComponent("Contents/Info.plist")),
              info["DockDividerID"] as? String == record.id.uuidString,
              info["CFBundleIdentifier"] as? String == "app.dockdivider.element.\(record.id.uuidString.lowercased())" else { return nil }
        // A restored backup may point to an older appearance than the manifest.
        // Recover the actual variant from the immutable bundle path.
        let variants = (1...RenderVariant.currentIconVersion).flatMap { version in
            [false, true].flatMap { dark in
                [DockOrientation.bottom, .left, .right].map {
                    RenderVariant(dark: dark, orientation: $0, iconVersion: version)
                }
            }
        }
        guard let variant = variants.first(where: {
            url.lastPathComponent == "\(record.style.rawValue)-\($0.key).app"
        }) else { return nil }
        record.variant = variant
        return record
    }
}
```

## DockDividerApp/Services/DividerRenderer.swift

```swift
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
```

## DockDividerApp/Services/DockConfigurationService.swift

```swift
import Foundation
import CoreFoundation

protocol DockPreferences {
    func read() throws -> DockSnapshot
    func writeApps(_ apps: [[String: Any]]) throws
    var isManaged: Bool { get }
}

final class SystemDockPreferences: DockPreferences {
    private let domain = "com.apple.dock" as CFString
    var isManaged: Bool {
        CFPreferencesAppValueIsForced("persistent-apps" as CFString, domain)
    }
    func read() throws -> DockSnapshot {
        guard CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost),
              let values = CFPreferencesCopyMultiple(nil, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? [String: Any],
              values["persistent-apps"] is [[String: Any]] else {
            throw DockError.io(L10n.string("error.read"))
        }
        return DockSnapshot(domain: values)
    }
    func writeApps(_ apps: [[String: Any]]) throws {
        guard !isManaged else { throw DockError.managed }
        CFPreferencesSetValue("persistent-apps" as CFString, apps as CFArray, domain,
                              kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        guard CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) else {
            throw DockError.io(L10n.string("error.write"))
        }
    }
}

struct DockConfigurationService {
    let preferences: DockPreferences
    let registry: DividerRegistry
    func read() throws -> (DockSnapshot, [DockItem]) {
        let snapshot = try preferences.read()
        var items = snapshot.apps.enumerated().map { index, raw in
            DockItem(id: "\(index)-\(DockItem.guid(in: raw) ?? 0)", raw: raw, divider: registry.record(for: raw))
        }
        // Finder is implicit on modern macOS and is not stored in persistent-apps.
        if !items.contains(where: { $0.url?.path == "/System/Library/CoreServices/Finder.app" }) {
            items.insert(DockItem(id: "finder", raw: [:], divider: nil, isFinder: true), at: 0)
        }
        return (snapshot, items)
    }
}
```

## DockDividerApp/Services/DockViewModel.swift

```swift
import AppKit
import Combine

@MainActor
final class DockViewModel: ObservableObject {
    @Published var items: [DockItem] = []
    @Published var selectedStyle: DividerStyle = .system
    @Published var matchAppearance = true
    @Published var automaticallyReload = true
    @Published private(set) var hasChanges = false
    @Published private(set) var isBusy = false
    @Published var error: String?
    @Published private(set) var status = L10n.string("status.reading")
    @Published private(set) var snapshot: DockSnapshot?
    @Published private(set) var backupAvailable = false
    @Published private(set) var originalAvailable = false
    let isDemo: Bool
    let paths: AppPaths
    private var registry: DividerRegistry?
    private var service: DockConfigurationService?
    private var writer: DockWriter?
    private var bundleManager: DividerBundleManager?
    private var timer: AnyCancellable?
    private var refreshTask: Task<Void, Never>?
    private var dark = false

    init(demo: Bool = ProcessInfo.processInfo.arguments.contains("--demo")) {
        isDemo = demo
        paths = demo ? AppPaths(root: FileManager.default.temporaryDirectory.appendingPathComponent("DockDividerDemo-\(UUID().uuidString)")) : AppPaths()
        matchAppearance = UserDefaults.standard.object(forKey: "matchAppearance") as? Bool ?? true
        automaticallyReload = UserDefaults.standard.object(forKey: "automaticallyReload") as? Bool ?? true
        do {
            let registry = try DividerRegistry(paths: paths)
            let preferences: DockPreferences = demo ? DemoDockPreferences() : SystemDockPreferences()
            let backups = BackupStore(paths: paths)
            self.registry = registry
            service = DockConfigurationService(preferences: preferences, registry: registry)
            writer = DockWriter(preferences: preferences, backups: backups, registry: registry)
            bundleManager = DividerBundleManager(paths: paths)
            reload()
            timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect().sink { [weak self] _ in
                self?.pollDock()
            }
        } catch { self.error = error.localizedDescription; status = L10n.string("status.read_failed") }
    }
    var managedCount: Int { items.filter(\.isManaged).count }
    var canEdit: Bool { snapshot != nil && !isBusy && service?.preferences.isManaged == false }
    var orientation: DockOrientation { snapshot?.orientation ?? .bottom }
    var variant: RenderVariant { RenderVariant(dark: matchAppearance && dark, orientation: orientation) }

    func reload() {
        do {
            guard let service else { return }
            let (snapshot, items) = try service.read()
            self.snapshot = snapshot; self.items = items; hasChanges = false
            backupAvailable = writer?.backups.hasPrevious ?? false
            originalAvailable = writer?.backups.hasOriginal ?? false
            status = L10n.format("status.count", snapshot.apps.count, managedCount)
        } catch { self.error = error.localizedDescription }
    }
    func insert(at index: Int) {
        guard canEdit, index >= 0, index <= items.count else { return }
        var used = Set(items.compactMap { DockItem.guid(in: $0.raw) })
        used.formUnion(registry?.records.map(\.guid) ?? [])
        var guid = UInt32.random(in: 1...UInt32.max)
        while used.contains(guid) { guid = UInt32.random(in: 1...UInt32.max) }
        let record = DividerRecord(id: UUID(), guid: guid, style: selectedStyle, position: index, variant: nil)
        let raw: [String: Any] = ["GUID": NSNumber(value: guid), "tile-type": selectedStyle.tileType, "tile-data": [String: Any]()]
        items.insert(DockItem(id: record.id.uuidString, raw: raw, divider: record), at: index)
        hasChanges = true
        status = L10n.string("status.preview")
    }
    func remove(_ id: String) {
        guard canEdit, items.contains(where: { $0.id == id && $0.isManaged }) else { return }
        items.removeAll { $0.id == id }; hasChanges = true
    }
    func move(_ id: String, to insertionIndex: Int) {
        guard canEdit, let source = items.firstIndex(where: { $0.id == id && $0.isManaged }) else { return }
        let minimum = items.first?.isFinder == true ? 1 : 0
        let destination = max(minimum, min(insertionIndex, items.count))
        let item = items.remove(at: source)
        items.insert(item, at: destination > source ? destination - 1 : destination)
        hasChanges = true
    }
    func shift(_ id: String, by delta: Int) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        move(id, to: index + (delta > 0 ? 2 : -1))
    }
    func settingsChanged() {
        UserDefaults.standard.set(matchAppearance, forKey: "matchAppearance")
        UserDefaults.standard.set(automaticallyReload, forKey: "automaticallyReload")
        scheduleAppearanceRefresh()
    }
    func appearanceChanged(dark: Bool) {
        self.dark = dark
        scheduleAppearanceRefresh()
    }
    private func scheduleAppearanceRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            self?.refreshAppearanceIfNeeded()
        }
    }
    private func pollDock() {
        guard !hasChanges, !isBusy, let service else { return }
        do {
            let current = try service.preferences.read()
            if !Plist.equal(current.apps, snapshot?.apps ?? []) || current.orientation != orientation { reload() }
            refreshAppearanceIfNeeded()
        } catch { self.error = error.localizedDescription }
    }
    private func refreshAppearanceIfNeeded() {
        guard canEdit, !hasChanges,
              items.contains(where: { $0.divider?.style.isLine == true && $0.divider?.variant != variant }) else { return }
        apply(appearanceOnly: true)
    }
    func apply(appearanceOnly: Bool = false) {
        guard canEdit, let expected = snapshot, let registry, let writer, let bundleManager else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            var prepared = items
            var records: [DividerRecord] = []
            for index in prepared.indices {
                guard var record = prepared[index].divider else { continue }
                record.position = prepared[..<index].filter { !$0.isFinder }.count
                record.variant = record.style.isLine ? variant : nil
                prepared[index].raw = try bundleManager.tile(for: record, variant: variant, existing: prepared[index].raw)
                prepared[index].divider = record
                records.append(record)
            }
            // Durable ownership precedes Dock writing, including recovery after a crash.
            try registry.register(records)
            try writer.apply(prepared, expected: expected)
            reload()
            status = appearanceOnly ? L10n.string("status.appearance") : L10n.string("status.saved")
            if automaticallyReload && !isDemo { try ProcessRunner.reloadDock() }
            else if !isDemo { status += L10n.string("status.restart_note") }
        } catch { self.error = error.localizedDescription }
    }
    func removeAll() { perform { try self.writer?.removeAll() } }
    func restore(original: Bool) { perform { try self.writer?.restore(original: original) } }
    private func perform(_ operation: () throws -> Void) {
        guard canEdit else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try operation(); reload()
            if automaticallyReload && !isDemo { try ProcessRunner.reloadDock() }
            status = L10n.string("status.configuration")
        } catch { self.error = error.localizedDescription }
    }
    func restartDock() {
        guard !isDemo else { return }
        do { try ProcessRunner.reloadDock(); status = L10n.string("status.restarted") }
        catch { self.error = error.localizedDescription }
    }
    func showBackups() {
        do {
            try FileManager.default.createDirectory(at: paths.backups, withIntermediateDirectories: true)
            NSWorkspace.shared.open(paths.backups)
        } catch { self.error = error.localizedDescription }
    }
}
```

## DockDividerApp/Services/DockWriter.swift

```swift
import Foundation

final class DockWriter {
    let preferences: DockPreferences
    let backups: BackupStore
    let registry: DividerRegistry
    init(preferences: DockPreferences, backups: BackupStore, registry: DividerRegistry) {
        self.preferences = preferences; self.backups = backups; self.registry = registry
    }
    func apply(_ items: [DockItem], expected: DockSnapshot) throws {
        let proposed = items.filter { !$0.isFinder }.map(\.raw)
        let preservedBefore = expected.apps.filter { registry.record(for: $0) == nil }
        let preservedAfter = items.filter { !$0.isFinder && !$0.isManaged }.map(\.raw)
        guard Plist.equal(preservedBefore, preservedAfter) else {
            throw DockError.invalid(L10n.string("error.app_changed"))
        }
        for item in items where item.isManaged {
            guard registry.record(for: item.raw)?.id == item.divider?.id else {
                throw DockError.invalid(L10n.string("error.ownership"))
            }
        }
        try commit(proposed, expected: expected)
    }
    func removeAll() throws {
        let current = try preferences.read()
        let kept = current.apps.filter { registry.record(for: $0) == nil }
        if kept.count != current.apps.count { try commit(kept, expected: current) }
    }
    func restore(original: Bool) throws {
        // Load the target before save() replaces previous.plist.
        let target = try backups.load(original: original)
        try commit(target.apps, expected: preferences.read())
    }
    func commit(_ apps: [[String: Any]], expected: DockSnapshot) throws {
        guard !preferences.isManaged else { throw DockError.managed }
        guard PropertyListSerialization.propertyList(apps, isValidFor: .binary),
              apps.allSatisfy({ $0["tile-type"] is String }) else {
            throw DockError.invalid(L10n.string("error.configuration"))
        }
        // Existing unusual/duplicate GUIDs must survive verbatim; only newly
        // created GUIDs are guaranteed unique by the editor.
        let current = try preferences.read()
        guard Plist.equal(current.apps, expected.apps) else { throw DockError.conflict }
        if Plist.equal(apps, current.apps) { return }
        try backups.save(current)
        let immediate = try preferences.read()
        guard Plist.equal(immediate.apps, current.apps) else { throw DockError.conflict }
        // Only this key is ever written. persistent-others and all Dock settings
        // remain in their original preference domain, including unknown keys.
        try preferences.writeApps(apps)
        let verified = try preferences.read()
        guard Plist.equal(verified.apps, apps) else {
            throw DockError.io(L10n.string("error.write_confirmation"))
        }
    }
}
```

## DockDividerApp/Utilities/AppPaths.swift

```swift
import Foundation

struct AppPaths {
    let root: URL
    init(root: URL? = nil) {
        self.root = root ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/DockDividerApp", isDirectory: true)
    }
    var registry: URL { root.appendingPathComponent("dividers.json") }
    var bundles: URL { root.appendingPathComponent("Dividers", isDirectory: true) }
    var backups: URL { root.appendingPathComponent("Backups", isDirectory: true) }
    var original: URL { backups.appendingPathComponent("original.plist") }
    var previous: URL { backups.appendingPathComponent("previous.plist") }
}
```

## DockDividerApp/Utilities/DockError.swift

```swift
import Foundation

enum DockError: LocalizedError {
    case invalid(String), conflict, managed, io(String)
    var errorDescription: String? {
        switch self {
        case .invalid(let message), .io(let message): message
        case .conflict: L10n.string("error.conflict")
        case .managed: L10n.string("error.managed")
        }
    }
}

enum Plist {
    static func equal(_ a: Any, _ b: Any) -> Bool {
        // NSObject equality ignores dictionary order and retains unknown keys.
        (a as AnyObject).isEqual(b)
    }
    static func data(_ value: Any) throws -> Data {
        try PropertyListSerialization.data(fromPropertyList: value, format: .binary, options: 0)
    }
    static func dictionary(at url: URL) throws -> [String: Any] {
        guard let value = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), options: [], format: nil) as? [String: Any] else {
            throw DockError.invalid(L10n.format("error.invalid_backup", url.lastPathComponent))
        }
        return value
    }
}
```

## DockDividerApp/Utilities/L10n.swift

```swift
import Foundation

/// Uses the same system-selected language in the app and its SwiftPM resource bundle.
enum L10n {
    static var bundle: Bundle {
        #if SWIFT_PACKAGE
        Bundle.module
        #else
        Bundle.main
        #endif
    }
    static func string(_ key: String) -> String {
        NSLocalizedString(key, bundle: bundle, comment: "")
    }
    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: string(key), locale: Locale.current, arguments: arguments)
    }
}
```

## DockDividerApp/Utilities/ProcessRunner.swift

```swift
import Foundation

enum ProcessRunner {
    @discardableResult
    static func run(_ executable: String, _ arguments: [String]) throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let errors = Pipe()
        process.standardError = errors
        process.standardOutput = FileHandle.nullDevice
        try process.run()
        // Drain before waiting to avoid pipe-buffer deadlocks.
        let output = errors.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw DockError.io("\(URL(fileURLWithPath: executable).lastPathComponent): \(String(data: output, encoding: .utf8) ?? L10n.string("error.process"))")
        }
        return process.terminationStatus
    }
    static func reloadDock() throws {
        // -u limits the operation to this user; no sudo and no cfprefsd restart.
        try run("/usr/bin/killall", ["-u", NSUserName(), "Dock"])
    }
}
```

## DockDividerApp/Views/ContentView.swift

```swift
import AppKit
import SwiftUI

// An explicit type alias uses the compatible property wrapper even when a newer
// SDK also exports a State macro that Command Line Tools cannot load.
private typealias ViewState<Value> = SwiftUI.State<Value>

struct ContentView: View {
    @ObservedObject var model: DockViewModel
    @Environment(\.colorScheme) private var colorScheme
    @ViewState private var recovery: RecoveryAction? = nil
    @ViewState private var discard = false
    @ViewState private var showDockInfo = false
    private let contentWidth: CGFloat = 860
    enum RecoveryAction: String, Identifiable {
        case previous, original, removeAll
        var id: String { rawValue }
        var title: String {
            switch self {
            case .previous: L10n.string("restore.previous_title")
            case .original: L10n.string("restore.original_title")
            case .removeAll: L10n.string("restore.remove_title")
            }
        }
    }
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(spacing: 14) {
                        Image(nsImage: NSApplication.shared.applicationIconImage)
                            .resizable().scaledToFit().frame(width: 54, height: 54)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("DockDivider").font(.system(size: 25, weight: .semibold))
                            Text(L10n.string("app.tagline")).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if model.isDemo { Text(L10n.string("demo.notice")).font(.caption).foregroundStyle(.secondary) }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(L10n.string("dock.current")).font(.headline)
                            Button { showDockInfo.toggle() } label: {
                                Image(systemName: "info.circle").foregroundStyle(.secondary)
                            }
                            .buttonStyle(.borderless)
                            .help(L10n.string("dock.read_info"))
                            .accessibilityLabel(L10n.string("dock.read_info_label"))
                            .popover(isPresented: $showDockInfo, arrowEdge: .bottom) {
                                Text(L10n.string("dock.read_info"))
                                    .font(.callout).fixedSize(horizontal: false, vertical: true)
                                    .frame(width: 310, alignment: .leading).padding(16)
                            }
                            Spacer()
                            Button { if model.hasChanges { discard = true } else { model.reload() } } label: {
                                Label(L10n.string("dock.read"), systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.borderless).disabled(model.isBusy)
                        }
                        DockPreviewView(model: model).disabled(!model.canEdit)
                        Text(L10n.string("dock.edit_help"))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    SettingsView(model: model).disabled(!model.canEdit)
                    HStack(alignment: .top, spacing: 9) {
                        Image(systemName: "info.circle").foregroundStyle(.secondary)
                        Text(L10n.string("dock.line_note"))
                            .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: contentWidth)
                .padding(28)
                .frame(maxWidth: .infinity)
            }
            Divider()
            VStack(spacing: 13) {
                HStack {
                    Menu {
                        Button(L10n.string("restore.previous")) { recovery = .previous }.disabled(!model.backupAvailable)
                        Button(L10n.string("restore.original")) { recovery = .original }.disabled(!model.originalAvailable)
                        Divider()
                        Button(L10n.string("restore.remove_all"), role: .destructive) { recovery = .removeAll }
                            .disabled(model.managedCount == 0)
                        Divider()
                        Button(L10n.string("restore.open_backups")) { model.showBackups() }
                    } label: { Label(L10n.string("restore.menu"), systemImage: "clock.arrow.circlepath") }
                    .menuStyle(.borderlessButton).fixedSize().disabled(!model.canEdit)
                    Spacer()
                    if model.isBusy { ProgressView().controlSize(.small) }
                    Button(L10n.string("dock.restart")) { model.restartDock() }.disabled(model.isBusy || model.isDemo)
                    Button(L10n.string("dock.apply")) { model.apply() }
                        .buttonStyle(.borderedProminent).keyboardShortcut(.return, modifiers: .command)
                        .disabled(!model.hasChanges || !model.canEdit)
                }
                HStack {
                    Circle().fill(model.hasChanges ? Color.orange : Color.secondary.opacity(0.5)).frame(width: 5, height: 5)
                    Text(model.status).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    Spacer()
                }
            }
            .frame(maxWidth: contentWidth)
            .padding(.horizontal, 28).padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(.bar)
        }
        .frame(minWidth: 720, idealWidth: 800, minHeight: 790)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { model.appearanceChanged(dark: colorScheme == .dark) }
        .onChange(of: colorScheme) { _, scheme in model.appearanceChanged(dark: scheme == .dark) }
        .alert("DockDivider", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button(L10n.string("common.ok")) { model.error = nil }
        } message: { Text(model.error ?? "") }
        .alert(L10n.string("discard.title"), isPresented: $discard) {
            Button(L10n.string("common.cancel"), role: .cancel) {}
            Button(L10n.string("dock.read"), role: .destructive) { model.reload() }
        } message: { Text(L10n.string("discard.message")) }
        .alert(item: $recovery) { action in
            Alert(title: Text(action.title),
                  message: Text(action == .removeAll
                    ? L10n.string("restore.remove_message")
                    : L10n.string("restore.message")),
                  primaryButton: .destructive(Text(action == .removeAll ? L10n.string("common.remove") : L10n.string("common.restore"))) {
                      switch action {
                      case .previous: model.restore(original: false)
                      case .original: model.restore(original: true)
                      case .removeAll: model.removeAll()
                      }
                  }, secondaryButton: .cancel(Text(L10n.string("common.cancel"))))
        }
    }
}
```

## DockDividerApp/Views/DividerStylePreview.swift

```swift
import SwiftUI

struct DividerStylePreview: View {
    let style: DividerStyle
    var horizontal = false
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        ZStack {
            if style.isLine {
                Rectangle()
                    .fill((colorScheme == .dark ? Color.white : Color.black).opacity(style.opacity))
                    .frame(width: horizontal ? 34 * style.lineHeight : style.lineWidth,
                           height: horizontal ? style.lineWidth : 34 * style.lineHeight)
            } else {
                HStack(spacing: style == .spacer ? 17 : 7) {
                    RoundedRectangle(cornerRadius: 2).fill(.secondary.opacity(0.35)).frame(width: 5, height: 17)
                    RoundedRectangle(cornerRadius: 2).fill(.secondary.opacity(0.35)).frame(width: 5, height: 17)
                }
            }
        }
        .frame(width: 46, height: 38)
        .accessibilityHidden(true)
    }
}
```

## DockDividerApp/Views/DockPreviewView.swift

```swift
import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct DockPreviewView: View {
    @ObservedObject var model: DockViewModel
    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .center, spacing: 0) {
                if model.items.first?.isFinder != true { insertion(at: 0) }
                ForEach(Array(model.items.enumerated()), id: \.element.id) { index, item in
                    tile(item, at: index)
                    insertion(at: index + 1)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
        }
        .frame(height: 140)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.separator.opacity(0.4)))
    }
    private func tile(_ item: DockItem, at index: Int) -> some View {
        VStack(spacing: 9) {
            if let divider = item.divider {
                DividerStylePreview(style: divider.style, horizontal: model.orientation.isVertical)
                    .frame(width: 52, height: 52)
                    .contentShape(Rectangle())
                    .onDrag { NSItemProvider(object: item.id as NSString) }
            } else {
                Image(nsImage: icon(item))
                    .resizable().interpolation(.high).scaledToFit().frame(width: 48, height: 48)
            }
            Text(item.divider.map { $0.style == .smallSpacer ? L10n.string("style.small_spacer") : ($0.style == .system ? L10n.string("style.system_short") : $0.style.title) } ?? item.title)
                .font(.caption).foregroundStyle(.secondary).lineLimit(1).frame(width: 76)
            if item.isManaged {
                HStack(spacing: 10) {
                    Button { model.shift(item.id, by: -1) } label: { Image(systemName: "chevron.left") }
                        .help(L10n.string("divider.move_left_help"))
                        .disabled(index <= (model.items.first?.isFinder == true ? 1 : 0))
                    Button { model.remove(item.id) } label: { Image(systemName: "xmark") }.help(L10n.string("divider.remove"))
                    Button { model.shift(item.id, by: 1) } label: { Image(systemName: "chevron.right") }
                        .help(L10n.string("divider.move_right_help")).disabled(index == model.items.count - 1)
                }
                .font(.system(size: 9, weight: .semibold)).buttonStyle(.plain)
            } else { Color.clear.frame(height: 12) }
        }
        .frame(width: 78)
        .contextMenu {
            Button(L10n.string("divider.insert_after")) { model.insert(at: index + 1) }
            if item.isManaged {
                Button(L10n.string("divider.move_left")) { model.shift(item.id, by: -1) }
                Button(L10n.string("divider.move_right")) { model.shift(item.id, by: 1) }
                Button(L10n.string("divider.remove"), role: .destructive) { model.remove(item.id) }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(item.title)
    }
    private func insertion(at index: Int) -> some View {
        Button { model.insert(at: index) } label: {
            Image(systemName: "plus.circle.fill").font(.system(size: 15)).foregroundStyle(.tertiary)
                .frame(width: 26, height: 84).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(L10n.format("divider.insert_here", model.selectedStyle.title))
        .accessibilityLabel(L10n.format("divider.insert_position", index))
        .onDrop(of: [UTType.text], isTargeted: nil) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: String.self) { value, _ in
                guard let value else { return }
                Task { @MainActor in model.move(value, to: index) }
            }
            return true
        }
    }
    private func icon(_ item: DockItem) -> NSImage {
        if item.isFinder { return NSWorkspace.shared.icon(forFile: "/System/Library/CoreServices/Finder.app") }
        if let url = item.url { return NSWorkspace.shared.icon(forFile: url.path) }
        return NSImage(systemSymbolName: "square.dashed", accessibilityDescription: item.title) ?? NSImage()
    }
}
```

## DockDividerApp/Views/SettingsView.swift

```swift
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: DockViewModel
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.string("settings.style")).font(.headline)
            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ForEach(DividerStyle.allCases) { style in
                    styleCard(style)
                }
            }
            Text(L10n.string("settings.appearance")).font(.headline).padding(.top, 8)
            VStack(alignment: .leading, spacing: 12) {
                Toggle(L10n.string("settings.match"), isOn: $model.matchAppearance)
                    .onChange(of: model.matchAppearance) { model.settingsChanged() }
                Toggle(L10n.string("settings.restart"), isOn: $model.automaticallyReload)
                    .onChange(of: model.automaticallyReload) { model.settingsChanged() }
                Text(L10n.string("settings.note"))
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private func styleCard(_ style: DividerStyle) -> some View {
        let selected = model.selectedStyle == style
        let shape = RoundedRectangle(cornerRadius: 14)
        return Button { model.selectedStyle = style } label: {
            HStack(spacing: 12) {
                DividerStylePreview(style: style)
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(style.title).font(.system(size: 13, weight: .semibold))
                            .fixedSize(horizontal: false, vertical: true)
                        if style == .system {
                            Text(L10n.string("settings.default"))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(.quaternary, in: Capsule())
                                .fixedSize()
                        }
                    }
                    Text(style.detail).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 17))
                    .foregroundStyle(selected ? Color.accentColor : Color.secondary.opacity(0.45))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
            .background(selected ? Color.accentColor.opacity(0.08) : Color(nsColor: .controlBackgroundColor), in: shape)
            .overlay(shape.strokeBorder(selected ? Color.accentColor.opacity(0.55) : Color(nsColor: .separatorColor).opacity(0.45), lineWidth: selected ? 1.5 : 1))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
```

## DividerLauncher/main.swift

```swift
// A Mach-O background executable. Launch Services starts it without activating
// an application; it exits without creating NSApplication, a menu or a window.
import Foundation
exit(EXIT_SUCCESS)
```

## Tests/DockDividerTests/DockSafetyTests.swift

```swift
import Testing
import AppKit
@testable import DockDividerApp

final class MemoryPreferences: DockPreferences {
    var snapshot: DockSnapshot
    var isManaged = false
    var writes = 0
    var reads = 0
    var onRead: ((Int) -> Void)?
    init(_ domain: [String: Any]) { snapshot = DockSnapshot(domain: domain) }
    func read() throws -> DockSnapshot { reads += 1; onRead?(reads); return snapshot }
    func writeApps(_ apps: [[String: Any]]) throws { writes += 1; snapshot.domain["persistent-apps"] = apps }
}

@Suite("Dock safety", .serialized)
final class DockSafetyTests {
    var paths: AppPaths!
    var registry: DividerRegistry!
    var backups: BackupStore!
    let safari: [String: Any] = ["GUID": 10, "tile-type": "file-tile", "tile-data": ["file-label": "Safari", "unknown-bookmark": Data([1, 2, 3])], "unknown-future-key": ["a": 9]]
    let foreignSpacer: [String: Any] = ["GUID": 20, "tile-type": "spacer-tile", "tile-data": [String: Any]()]

    init() throws {
        paths = AppPaths(root: FileManager.default.temporaryDirectory.appendingPathComponent("DockDividerTests-\(UUID().uuidString)"))
        registry = try DividerRegistry(paths: paths)
        backups = BackupStore(paths: paths)
    }
    deinit {
        if FileManager.default.fileExists(atPath: paths.root.path) { try? FileManager.default.removeItem(at: paths.root) }
    }
    func domain(_ apps: [[String: Any]]) -> [String: Any] {
        ["persistent-apps": apps, "persistent-others": [["tile-type": "directory-tile", "unknown": "keep"]],
         "tilesize": 52, "orientation": "bottom", "future-setting": Data([42])]
    }
    func managed(_ style: DividerStyle = .spacer, guid: UInt32 = 30) throws -> DockItem {
        let record = DividerRecord(id: UUID(), guid: guid, style: style, position: 1)
        try registry.register([record])
        return DockItem(id: record.id.uuidString, raw: ["GUID": NSNumber(value: guid), "tile-type": style.tileType, "tile-data": [String: Any]()], divider: record)
    }
    func writer(_ preferences: MemoryPreferences) -> DockWriter {
        DockWriter(preferences: preferences, backups: backups, registry: registry)
    }
    @Test func testInsertionPreservesUnknownEntriesAndOtherDomainKeys() throws {
        let pref = MemoryPreferences(domain([safari, foreignSpacer]))
        let original = pref.snapshot
        let divider = try managed(.smallSpacer)
        try writer(pref).apply([DockItem(id: "app", raw: safari), divider, DockItem(id: "foreign", raw: foreignSpacer)], expected: original)
        #expect(pref.writes == 1)
        #expect(Plist.equal(pref.snapshot.apps[0], safari))
        #expect(Plist.equal(pref.snapshot.apps[2], foreignSpacer))
        for key in ["persistent-others", "tilesize", "future-setting"] {
            #expect(Plist.equal(pref.snapshot.domain[key]!, original.domain[key]!))
        }
        #expect(Plist.equal(try backups.load(original: true).domain, original.domain))
        #expect(Plist.equal(try backups.load(original: false).domain, original.domain))
    }
    @Test func testDeletingOrChangingAnExistingAppIsRejectedBeforeWriting() throws {
        let pref = MemoryPreferences(domain([safari]))
        #expect(throws: (any Error).self) { try writer(pref).apply([], expected: pref.snapshot) }
        var changed = safari; changed["unknown-future-key"] = "lost"
        #expect(throws: (any Error).self) { try writer(pref).apply([DockItem(id: "app", raw: changed)], expected: pref.snapshot) }
        #expect(pref.writes == 0)
        #expect(!(backups.hasPrevious))
    }
    @Test func testConcurrentDockChangeIsRejected() throws {
        let pref = MemoryPreferences(domain([safari]))
        let expected = pref.snapshot
        pref.snapshot.domain["persistent-apps"] = [safari, foreignSpacer]
        let divider = try managed()
        #expect(throws: (any Error).self) { try writer(pref).apply([DockItem(id: "app", raw: safari), divider], expected: expected) }
        #expect(pref.writes == 0)
        #expect(pref.snapshot.apps.count == 2)
    }
    @Test func testChangeDuringBackupIsRejected() throws {
        let pref = MemoryPreferences(domain([safari]))
        let expected = pref.snapshot
        pref.onRead = { [weak pref] count in
            if count == 2 { pref?.snapshot.domain["persistent-apps"] = [self.safari, self.foreignSpacer] }
        }
        let divider = try managed()
        #expect(throws: (any Error).self) { try writer(pref).apply([DockItem(id: "app", raw: safari), divider], expected: expected) }
        #expect(pref.writes == 0)
        #expect(backups.hasPrevious)
    }
    @Test func testRemoveAllOnlyRemovesRegisteredSpacerAndKeepsForeignSpacer() throws {
        let own = try managed()
        let pref = MemoryPreferences(domain([safari, own.raw, foreignSpacer]))
        try writer(pref).removeAll()
        #expect(Plist.equal(pref.snapshot.apps, [safari, foreignSpacer]))
        #expect(Plist.equal(try backups.load(original: false).apps, [safari, own.raw, foreignSpacer]))
    }
    @Test func testOwnershipRequiresRecordedGuidAndExactTileType() throws {
        let own = try managed()
        #expect(registry.record(for: own.raw) != nil)
        #expect(registry.record(for: foreignSpacer) == nil)
        var fake = own.raw; fake["tile-type"] = "file-tile"
        #expect(registry.record(for: fake) == nil)
        fake = own.raw; fake["tile-data"] = ["file-data": ["_CFURLString": "file:///Applications/Safari.app"]]
        #expect(registry.record(for: fake) == nil)
    }
    @Test func testRestoreLoadsPreviousBeforeCreatingNewBackupAndKeepsOtherSettings() throws {
        let pref = MemoryPreferences(domain([safari]))
        try backups.save(pref.snapshot)
        pref.snapshot.domain["persistent-apps"] = [safari, foreignSpacer]
        pref.snapshot.domain["tilesize"] = 70
        try writer(pref).restore(original: false)
        #expect(Plist.equal(pref.snapshot.apps, [safari]))
        #expect(pref.snapshot.domain["tilesize"] as? Int == 70)
        #expect(Plist.equal(try backups.load(original: false).apps, [safari, foreignSpacer]))
        #expect(Plist.equal(try backups.load(original: true).apps, [safari]))
    }
    @Test func testManagedDockAndInvalidPlistAreNeverWritten() throws {
        let pref = MemoryPreferences(domain([safari]))
        pref.isManaged = true
        #expect(throws: (any Error).self) { try writer(pref).commit([foreignSpacer], expected: pref.snapshot) }
        pref.isManaged = false
        #expect(throws: (any Error).self) { try writer(pref).commit([["tile-type": "file-tile", "invalid": URL(fileURLWithPath: "/tmp")]], expected: pref.snapshot) }
        #expect(pref.writes == 0)
    }
    @Test func testBackupFailurePreventsDockWrite() throws {
        try FileManager.default.createDirectory(at: paths.root, withIntermediateDirectories: true)
        try Data("blocks directory creation".utf8).write(to: paths.backups)
        let pref = MemoryPreferences(domain([safari]))
        #expect(throws: (any Error).self) { try writer(pref).commit([safari, foreignSpacer], expected: pref.snapshot) }
        #expect(pref.writes == 0)
    }
    @Test func testNoOpDoesNotWriteOrCreateBackup() throws {
        let pref = MemoryPreferences(domain([safari]))
        try writer(pref).commit([safari], expected: pref.snapshot)
        #expect(pref.writes == 0)
        #expect(!(backups.hasOriginal))
    }
    @Test func testRegistrySurvivesRelaunch() throws {
        let own = try managed(.smallSpacer)
        let reloaded = try DividerRegistry(paths: paths)
        #expect(reloaded.record(for: own.raw)?.id == own.divider?.id)
    }
    @Test func legacyRenderVariantDecodesWithoutLosingOwnershipMetadata() throws {
        let json = Data("{\"dark\":true,\"orientation\":\"bottom\"}".utf8)
        let legacy = try JSONDecoder().decode(RenderVariant.self, from: json)
        #expect(legacy.iconVersion == 1)
        #expect(legacy.key == "v1-dark-bottom")
        #expect(legacy != RenderVariant(dark: true, orientation: .bottom))
        let current = RenderVariant(dark: true, orientation: .bottom)
        #expect(try JSONDecoder().decode(RenderVariant.self, from: JSONEncoder().encode(current)) == current)
    }
    @Test func testUnknownTileSurvivesInsertion() throws {
        let unknown: [String: Any] = ["tile-type": "future-tile", "arbitrary-data": ["b": true]]
        let pref = MemoryPreferences(domain([unknown]))
        let own = try managed()
        try writer(pref).apply([DockItem(id: "unknown", raw: unknown), own], expected: pref.snapshot)
        #expect(Plist.equal(pref.snapshot.apps[0], unknown))
    }
    @Test func testRendererHasTransparentBackgroundAndCorrectOrientation() throws {
        for orientation in [DockOrientation.bottom, .left, .right] {
            let png = try DividerRenderer.png(style: .system, variant: RenderVariant(dark: false, orientation: orientation), pixels: 128)
            let rep = try #require(NSBitmapImageRep(data: png))
            #expect(rep.pixelsWide == 128)
            #expect(try #require(rep.colorAt(x: 0, y: 0)).alphaComponent == 0)
            #expect(try #require(rep.colorAt(x: 64, y: 64)).alphaComponent > 0)
            let outside = orientation == .bottom ? rep.colorAt(x: 20, y: 64) : rep.colorAt(x: 64, y: 20)
            #expect(try #require(outside).alphaComponent == 0)
        }
        let icon = try DividerRenderer.icon(style: .system, variant: RenderVariant(dark: true, orientation: .bottom))
        #expect(String(data: icon.prefix(4), encoding: .utf8) == "icns")
        #expect(NSImage(data: icon) != nil)
    }
}
```

## Tests/DockDividerTests/HelperBundleTests.swift

```swift
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
```

## Tests/DockDividerTests/LocalizationTests.swift

```swift
import Foundation
import Testing
@testable import DockDividerApp

@Suite("Localization")
struct LocalizationTests {
    private func strings(_ language: String) throws -> [String: String] {
        let url = try #require(L10n.bundle.url(forResource: "Localizable", withExtension: "strings", subdirectory: nil, localization: language))
        let table = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil)
        return try #require(table as? [String: String])
    }
    @Test func bothLanguagesHaveCompleteMatchingKeysAndFormatting() throws {
        let german = try strings("de"), english = try strings("en")
        #expect(Set(german.keys) == Set(english.keys))
        #expect(german.values.allSatisfy { !$0.isEmpty })
        #expect(english.values.allSatisfy { !$0.isEmpty })
        for key in german.keys {
            let pattern = #"%(?:\d+\$)?(?:l)?[d@]"#
            let regex = try NSRegularExpression(pattern: pattern)
            func specifiers(_ value: String) -> [String] {
                regex.matches(in: value, range: NSRange(value.startIndex..., in: value)).map { (value as NSString).substring(with: $0.range) }
            }
            #expect(specifiers(german[key]!) == specifiers(english[key]!))
        }
        #expect(String(format: try #require(english["status.count"]), 12, 2) == "12 saved Dock entries · 2 own dividers")
        #expect(String(format: try #require(english["divider.insert_here"]), "Thin Divider") == "Insert Thin Divider here")
    }
    @Test func dockReadingHelpExplainsPinnedAndTemporaryApps() throws {
        for (language, pinned) in [("de", "Im Dock behalten"), ("en", "Keep in Dock")] {
            let message = try #require(strings(language)["dock.read_info"])
            #expect(message.contains(pinned))
            #expect(message.contains("Finder"))
        }
    }
}
```

## Tests/DockDividerTests/SystemReadTests.swift

```swift
import Testing
import Foundation
@testable import DockDividerApp

@Suite("Read-only system check")
struct SystemReadTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["DOCK_DIVIDER_TEST_SYSTEM_READ"] == "1"))
    func currentUserDockCanBeReadWithoutWriting() throws {
        let snapshot = try SystemDockPreferences().read()
        #expect(snapshot.domain["persistent-apps"] is [[String: Any]])
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("UnusedDockRegistry-\(UUID().uuidString)")
        let registry = try DividerRegistry(paths: AppPaths(root: path))
        let (_, items) = try DockConfigurationService(preferences: SystemDockPreferences(), registry: registry).read()
        #expect(Plist.equal(items.filter { !$0.isFinder }.map(\.raw), snapshot.apps))
        #expect(!FileManager.default.fileExists(atPath: path.path))
    }
}
```

## scripts/GenerateAppIcon.swift

```swift
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
```
