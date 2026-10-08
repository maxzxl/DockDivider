import AppKit

@MainActor
enum AppCatalog {
    static func isApplication(_ url: URL) -> Bool {
        url.isFileURL && url.pathExtension.lowercased() == "app" &&
            FileManager.default.fileExists(atPath: url.path) &&
            Bundle(url: url)?.bundleIdentifier != nil
    }
    static func resolve(_ app: AppReference) -> URL? {
        if let id = app.bundleIdentifier, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id), isApplication(url) { return url }
        let url = URL(fileURLWithPath: app.path)
        return isApplication(url) ? url : nil
    }
    static func reference(for item: DockItem) -> AppReference? {
        guard let url = item.url, !item.isFinder, url.pathExtension.lowercased() == "app" else { return nil }
        let data = item.raw["tile-data"] as? [String: Any]
        return AppReference(name: item.title, bundleIdentifier: Bundle(url: url)?.bundleIdentifier ?? data?["bundle-identifier"] as? String, path: url.path)
    }
    static func tile(for url: URL, guid: UInt32) throws -> DockItem {
        guard isApplication(url), url.path != "/System/Library/CoreServices/Finder.app" else {
            throw DockError.invalid(L10n.string("error.application"))
        }
        var data: [String: Any] = ["file-label": url.deletingPathExtension().lastPathComponent,
                                 "file-type": 41, "file-data": ["_CFURLString": url.absoluteString, "_CFURLStringType": 15]]
        if let identifier = Bundle(url: url)?.bundleIdentifier { data["bundle-identifier"] = identifier }
        return DockItem(id: UUID().uuidString, raw: ["GUID": NSNumber(value: guid), "tile-type": "file-tile", "tile-data": data])
    }
    static func choose(multiple: Bool = true) -> [URL] {
        let panel = NSOpenPanel()
        panel.title = L10n.string("apps.add")
        panel.prompt = L10n.string("common.add")
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = multiple
        panel.treatsFilePackagesAsDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.applicationBundle]
        return panel.runModal() == .OK ? panel.urls : []
    }
}
