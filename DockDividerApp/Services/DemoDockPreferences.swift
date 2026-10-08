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
