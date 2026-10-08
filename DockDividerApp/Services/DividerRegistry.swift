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
