import Foundation

final class ProfileStore {
    let directory: URL
    init(paths: AppPaths) { directory = paths.root.appendingPathComponent("Profiles", isDirectory: true) }
    func all() throws -> [DockProfile] {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .map { try read($0) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    func save(_ profile: DockProfile) throws {
        try profile.validate()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try encode(profile).write(to: directory.appendingPathComponent("\(profile.id).json"), options: .atomic)
    }
    func remove(_ profile: DockProfile) throws {
        // App-managed files go to Trash, retaining the normal macOS recovery path.
        let url = directory.appendingPathComponent("\(profile.id).json")
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
    }
    func read(_ url: URL) throws -> DockProfile {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        guard data.count <= 10_000_000 else { throw DockError.invalid(L10n.string("error.profile")) }
        let profile = try JSONDecoder().decode(DockProfile.self, from: data)
        try profile.validate()
        return profile
    }
    func encode(_ profile: DockProfile) throws -> Data {
        try profile.validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(profile)
    }
}
