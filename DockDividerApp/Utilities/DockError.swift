import Foundation

enum DockError: LocalizedError {
    case invalid(String), conflict, managed, io(String)
    var errorDescription: String? {
        switch self {
        case .invalid(let message), .io(let message): message
        case .conflict: L10n.string("error.conflict")
        case .managed: L10n.string("error.managed")
        }
    }
}

enum Plist {
    static func equal(_ a: Any, _ b: Any) -> Bool {
        // NSObject equality ignores dictionary order and retains unknown keys.
        (a as AnyObject).isEqual(b)
    }
    static func data(_ value: Any) throws -> Data {
        try PropertyListSerialization.data(fromPropertyList: value, format: .binary, options: 0)
    }
    static func dictionary(at url: URL) throws -> [String: Any] {
        guard let value = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), options: [], format: nil) as? [String: Any] else {
            throw DockError.invalid(L10n.format("error.invalid_backup", url.lastPathComponent))
        }
        return value
    }
}
