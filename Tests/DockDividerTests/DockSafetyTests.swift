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
