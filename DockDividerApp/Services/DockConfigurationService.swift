import Foundation
import CoreFoundation

protocol DockPreferences {
    func read() throws -> DockSnapshot
    func writeApps(_ apps: [[String: Any]]) throws
    func writeValues(_ values: [String: Any]) throws
    func isForced(_ key: String) -> Bool
    var isManaged: Bool { get }
}

extension DockPreferences {
    func isForced(_ key: String) -> Bool { isManaged }
    func writeValues(_ values: [String: Any]) throws {
        guard values.keys.allSatisfy({ $0 == "persistent-apps" }),
              let apps = values["persistent-apps"] as? [[String: Any]] else {
            throw DockError.invalid(L10n.string("error.options"))
        }
        try writeApps(apps)
    }
}

final class SystemDockPreferences: DockPreferences {
    private let domain = "com.apple.dock" as CFString
    var isManaged: Bool {
        CFPreferencesAppValueIsForced("persistent-apps" as CFString, domain)
    }
    func isForced(_ key: String) -> Bool { CFPreferencesAppValueIsForced(key as CFString, domain) }
    func read() throws -> DockSnapshot {
        guard CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost),
              let values = CFPreferencesCopyMultiple(nil, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? [String: Any],
              values["persistent-apps"] is [[String: Any]] else {
            throw DockError.io(L10n.string("error.read"))
        }
        return DockSnapshot(domain: values)
    }
    func writeApps(_ apps: [[String: Any]]) throws { try writeValues(["persistent-apps": apps]) }
    func writeValues(_ values: [String: Any]) throws {
        let allowed = DockOptions.keys.union(["persistent-apps"])
        guard Set(values.keys).isSubset(of: allowed), PropertyListSerialization.propertyList(values, isValidFor: .binary) else {
            throw DockError.invalid(L10n.string("error.configuration"))
        }
        guard !values.keys.contains(where: isForced) else { throw DockError.managed }
        CFPreferencesSetMultiple(values as CFDictionary, nil, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
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
            DockItem(id: "\(index)-\(DockItem.guid(in: raw) ?? 0)", raw: raw, divider: registry.record(for: raw), isFinder: DockItem.fileURL(in: raw)?.path == "/System/Library/CoreServices/Finder.app")
        }
        // Finder is implicit on modern macOS and is not stored in persistent-apps.
        if !items.contains(where: { $0.url?.path == "/System/Library/CoreServices/Finder.app" }) {
            items.insert(DockItem(id: "finder", raw: [:], divider: nil, isFinder: true), at: 0)
        }
        return (snapshot, items)
    }
}
