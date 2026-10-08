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
