import Foundation

struct AppReference: Codable, Equatable {
    var name: String
    var bundleIdentifier: String?
    var path: String
}

struct ProfileEntry: Codable, Identifiable {
    enum Kind: String, Codable { case app, divider, preserved }
    var id = UUID()
    var kind: Kind
    var app: AppReference?
    var style: DividerStyle?
    var preserved: Data?
}

struct DockProfile: Codable, Identifiable {
    var version = 1
    var id = UUID()
    var name: String
    var created = Date()
    var entries: [ProfileEntry]
    var options: DockOptions
    var appCount: Int { entries.filter { $0.kind == .app }.count }
    var dividerCount: Int { entries.filter { $0.kind == .divider }.count }

    func validate() throws {
        try options.validate()
        guard version == 1, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              name.count <= 120, entries.count <= 500,
              Set(entries.map(\.id)).count == entries.count else {
            throw DockError.invalid(L10n.string("error.profile"))
        }
        for entry in entries {
            switch entry.kind {
            case .app:
                guard let app = entry.app, app.path.hasPrefix("/"), app.path.count < 4096,
                      !app.name.isEmpty, app.name.count <= 256 else { throw DockError.invalid(L10n.string("error.profile")) }
            case .divider:
                guard entry.style != nil else { throw DockError.invalid(L10n.string("error.profile")) }
            case .preserved:
                guard let data = entry.preserved, data.count <= 1_000_000,
                      let raw = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
                      raw["tile-type"] is String else { throw DockError.invalid(L10n.string("error.profile")) }
            }
        }
    }
}

struct MissingProfileApp: Identifiable {
    let id: UUID
    let reference: AppReference
}
