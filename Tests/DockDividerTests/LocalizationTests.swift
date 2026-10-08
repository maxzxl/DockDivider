import Foundation
import Testing
@testable import DockDividerApp

@Suite("Localization")
struct LocalizationTests {
    private func strings(_ language: String) throws -> [String: String] {
        let url = try #require(L10n.bundle.url(forResource: "Localizable", withExtension: "strings", subdirectory: nil, localization: language))
        let table = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil)
        return try #require(table as? [String: String])
    }
    @Test func bothLanguagesHaveCompleteMatchingKeysAndFormatting() throws {
        let german = try strings("de"), english = try strings("en")
        #expect(Set(german.keys) == Set(english.keys))
        #expect(german.values.allSatisfy { !$0.isEmpty })
        #expect(english.values.allSatisfy { !$0.isEmpty })
        for key in german.keys {
            let pattern = #"%(?:\d+\$)?(?:l)?[d@]"#
            let regex = try NSRegularExpression(pattern: pattern)
            func specifiers(_ value: String) -> [String] {
                regex.matches(in: value, range: NSRange(value.startIndex..., in: value)).map { (value as NSString).substring(with: $0.range) }
            }
            #expect(specifiers(german[key]!) == specifiers(english[key]!))
        }
        #expect(String(format: try #require(english["status.count"]), 12, 2) == "12 saved Dock entries · 2 own dividers")
        #expect(String(format: try #require(english["divider.insert_here"]), "Thin Divider") == "Insert Thin Divider here")
    }
    @Test func dockReadingHelpExplainsPinnedAndTemporaryApps() throws {
        for (language, pinned) in [("de", "Im Dock behalten"), ("en", "Keep in Dock")] {
            let message = try #require(strings(language)["dock.read_info"])
            #expect(message.contains(pinned))
            #expect(message.contains("Finder"))
        }
    }
    @Test func explicitLanguagesResolveIndependentlyOfSystemPreferences() {
        #expect(L10n.string("dock.current", language: .english) == "Current Dock")
        #expect(L10n.string("dock.current", language: .german) == "Aktuelles Dock")
        #expect(L10n.format("status.count", language: .english, 12, 2) == "12 saved Dock entries · 2 own dividers")
        #expect(AppLanguage.english.locale.language.languageCode?.identifier == "en")
        #expect(AppLanguage.german.locale.language.languageCode?.identifier == "de")
    }

    @Test @MainActor func languageSwitchPersistsAndKeepsTheDraft() throws {
        let name = "DockDividerLanguageTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        #expect(AppLanguage.saved(in: defaults) == .system)
        defaults.set("unknown-language", forKey: AppLanguage.preferenceKey)
        #expect(AppLanguage.saved(in: defaults) == .system)
        defaults.set("de", forKey: AppLanguage.preferenceKey)
        let model = DockViewModel(demo: true, defaults: defaults)
        defer { try? FileManager.default.removeItem(at: model.paths.root) }
        #expect(model.error == nil)
        #expect(model.language == .german)
        model.selectedStyle = .smallSpacer
        model.insert(at: 2)
        let ids = model.items.map(\.id)
        let raw = model.items.map(\.raw)
        #expect(model.status.contains("Vorschau"))
        model.language = .english
        #expect(model.hasChanges)
        #expect(model.selectedStyle == .smallSpacer)
        #expect(model.items.map(\.id) == ids)
        #expect(Plist.equal(model.items.map(\.raw), raw))
        #expect(model.status == L10n.string("status.preview", language: .english))
        #expect(AppLanguage.saved(in: defaults) == .english)
        let reopened = DockViewModel(demo: true, defaults: defaults)
        defer { try? FileManager.default.removeItem(at: reopened.paths.root) }
        #expect(reopened.language == .english)
        #expect(reopened.status.contains("saved Dock entries"))
        model.language = .system
        #expect(AppLanguage.saved(in: defaults) == .system)
        #expect(model.hasChanges)
    }

}
