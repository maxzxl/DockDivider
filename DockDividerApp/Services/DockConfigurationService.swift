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
