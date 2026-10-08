import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system, german = "de", english = "en"
    static let preferenceKey = "appLanguage"
    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: L10n.string("language.system")
        case .german: "Deutsch"
        case .english: "English"
        }
    }
    static func saved(in defaults: UserDefaults = .standard) -> AppLanguage {
        AppLanguage(rawValue: defaults.string(forKey: preferenceKey) ?? "") ?? .system
    }
    var locale: Locale {
        let identifier = self == .system
            ? L10n.bundle.preferredLocalizations.first(where: { ["de", "en"].contains($0) }) ?? "en"
            : rawValue
        return Locale(identifier: identifier)
    }
}

/// Resolves an explicit app language without changing macOS language preferences.
enum L10n {
    static var bundle: Bundle {
        #if SWIFT_PACKAGE
        Bundle.module
        #else
        Bundle.main
        #endif
    }
    static func string(_ key: String, language: AppLanguage = .saved()) -> String {
        let localizedBundle: Bundle
        if language != .system,
           let path = bundle.path(forResource: language.rawValue, ofType: "lproj"),
           let selection = Bundle(path: path) {
            localizedBundle = selection
        } else {
            localizedBundle = bundle
        }
        return NSLocalizedString(key, bundle: localizedBundle, comment: "")
    }
    static func format(_ key: String, language: AppLanguage = .saved(), _ arguments: CVarArg...) -> String {
        String(format: string(key, language: language), locale: language.locale, arguments: arguments)
    }
}
