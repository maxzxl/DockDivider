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
