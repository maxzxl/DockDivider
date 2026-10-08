import Foundation

struct DockOptions: Codable, Equatable {
    var size: Double = 48
    var magnification = false
    var magnifiedSize: Double = 96
    var orientation: DockOrientation = .bottom
    var autoHide = false
    var showRecents = true
    var minimizeIntoApp = false
    var animateOpening = true
    var showIndicators = true
    var minimizeEffect = "genie"

    init() {}
    init(domain: [String: Any]) {
        size = (domain["tilesize"] as? NSNumber)?.doubleValue ?? 48
        magnification = (domain["magnification"] as? NSNumber)?.boolValue ?? false
        magnifiedSize = (domain["largesize"] as? NSNumber)?.doubleValue ?? 96
        orientation = DockOrientation(rawValue: domain["orientation"] as? String ?? "bottom") ?? .bottom
        autoHide = (domain["autohide"] as? NSNumber)?.boolValue ?? false
        showRecents = (domain["show-recents"] as? NSNumber)?.boolValue ?? true
        minimizeIntoApp = (domain["minimize-to-application"] as? NSNumber)?.boolValue ?? false
        animateOpening = (domain["launchanim"] as? NSNumber)?.boolValue ?? true
        showIndicators = (domain["show-process-indicators"] as? NSNumber)?.boolValue ?? true
        minimizeEffect = domain["mineffect"] as? String ?? "genie"
    }
    static let keys: Set<String> = ["tilesize", "magnification", "largesize", "orientation", "autohide", "show-recents", "minimize-to-application", "launchanim", "show-process-indicators", "mineffect"]
    var values: [String: Any] {
        ["tilesize": size, "magnification": magnification, "largesize": magnifiedSize,
         "orientation": orientation.rawValue, "autohide": autoHide, "show-recents": showRecents,
         "minimize-to-application": minimizeIntoApp, "launchanim": animateOpening,
         "show-process-indicators": showIndicators, "mineffect": minimizeEffect]
    }
    func validate() throws {
        guard size.isFinite, magnifiedSize.isFinite, (16...128).contains(size),
              (16...128).contains(magnifiedSize), ["genie", "scale"].contains(minimizeEffect) else {
            throw DockError.invalid(L10n.string("error.options"))
        }
    }
    func changes(from baseline: DockOptions) -> [String: Any] {
        values.filter { !Plist.equal($0.value, baseline.values[$0.key]!) }
    }
}

enum WorkspacePage: String, CaseIterable, Identifiable {
    case layout, dock, profiles, backups
    var id: String { rawValue }
    var title: String { L10n.string("page.\(rawValue)") }
    var symbol: String {
        switch self {
        case .layout: "rectangle.split.3x1"
        case .dock: "slider.horizontal.3"
        case .profiles: "square.stack"
        case .backups: "clock.arrow.circlepath"
        }
    }
}
