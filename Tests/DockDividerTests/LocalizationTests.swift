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
}
