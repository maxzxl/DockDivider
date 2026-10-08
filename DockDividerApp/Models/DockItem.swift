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
