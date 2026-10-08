import Foundation

enum DividerStyle: String, CaseIterable, Codable, Identifiable {
    case system, thin, standard, spacer, smallSpacer
    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: L10n.string("style.system")
        case .thin: L10n.string("style.thin")
        case .standard: L10n.string("style.standard")
        case .spacer: L10n.string("style.spacer")
        case .smallSpacer: L10n.string("style.small_spacer")
        }
    }
    var detail: String {
        switch self {
        case .system: L10n.string("style.system_detail")
        case .thin: L10n.string("style.thin_detail")
        case .standard: L10n.string("style.standard_detail")
        case .spacer: L10n.string("style.spacer_detail")
        case .smallSpacer: L10n.string("style.small_spacer_detail")
        }
    }
    var isLine: Bool { self != .spacer && self != .smallSpacer }
    var tileType: String {
        switch self {
        case .spacer: "spacer-tile"
        case .smallSpacer: "small-spacer-tile"
        default: "file-tile"
        }
    }
    // Relative to a 64pt icon, not Apple's private separator metrics.
    var lineWidth: Double { self == .standard ? 2 : (self == .thin ? 0.75 : 1) }
    var lineHeight: Double { self == .thin ? 0.64 : 0.82 }
    var opacity: Double { self == .standard ? 0.42 : (self == .thin ? 0.30 : 0.23) }
}

enum DockOrientation: String, Codable {
    case bottom, left, right
    var isVertical: Bool { self != .bottom }
}

struct RenderVariant: Codable, Equatable {
    static let currentIconVersion = 2
    var dark: Bool
    var orientation: DockOrientation
    var iconVersion: Int
    init(dark: Bool, orientation: DockOrientation, iconVersion: Int = currentIconVersion) {
        self.dark = dark
        self.orientation = orientation
        self.iconVersion = iconVersion
    }
    private enum CodingKeys: String, CodingKey { case dark, orientation, iconVersion }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        dark = try values.decode(Bool.self, forKey: .dark)
        orientation = try values.decode(DockOrientation.self, forKey: .orientation)
        // Existing registries predate the explicit custom-icon treatment.
        iconVersion = try values.decodeIfPresent(Int.self, forKey: .iconVersion) ?? 1
    }
    var key: String { "v\(iconVersion)-\(dark ? "dark" : "light")-\(orientation.rawValue)" }
}

struct DividerRecord: Codable, Identifiable, Equatable {
    var id: UUID
    var guid: UInt32
    var style: DividerStyle
    var position: Int
    var variant: RenderVariant?
}
