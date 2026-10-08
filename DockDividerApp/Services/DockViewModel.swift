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
