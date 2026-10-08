import Foundation

final class BackupStore {
    let paths: AppPaths
    init(paths: AppPaths) { self.paths = paths }
    @discardableResult
    func save(_ snapshot: DockSnapshot) throws -> URL {
        let fm = FileManager.default
        try fm.createDirectory(at: paths.backups, withIntermediateDirectories: true)
        let data = try Plist.data(snapshot.domain)
        let archive = paths.backups.appendingPathComponent("\(Int(Date().timeIntervalSince1970))-\(UUID().uuidString).plist")
        try data.write(to: archive, options: .atomic)
        if !fm.fileExists(atPath: paths.original.path) { try data.write(to: paths.original, options: .atomic) }
        try data.write(to: paths.previous, options: .atomic)
        guard Plist.equal(try Plist.dictionary(at: archive), snapshot.domain) else {
            throw DockError.io(L10n.string("error.backup_verify"))
        }
        return archive
    }
    func load(original: Bool) throws -> DockSnapshot {
        let domain = try Plist.dictionary(at: original ? paths.original : paths.previous)
        guard domain["persistent-apps"] is [[String: Any]] else { throw DockError.invalid(L10n.string("error.backup_apps")) }
        return DockSnapshot(domain: domain)
    }
    var hasPrevious: Bool { FileManager.default.fileExists(atPath: paths.previous.path) }
    var hasOriginal: Bool { FileManager.default.fileExists(atPath: paths.original.path) }
}
