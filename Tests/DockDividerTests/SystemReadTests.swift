import Testing
import Foundation
@testable import DockDividerApp

@Suite("Read-only system check")
struct SystemReadTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["DOCK_DIVIDER_TEST_SYSTEM_READ"] == "1"))
    func currentUserDockCanBeReadWithoutWriting() throws {
        let snapshot = try SystemDockPreferences().read()
        #expect(snapshot.domain["persistent-apps"] is [[String: Any]])
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("UnusedDockRegistry-\(UUID().uuidString)")
        let registry = try DividerRegistry(paths: AppPaths(root: path))
        let (_, items) = try DockConfigurationService(preferences: SystemDockPreferences(), registry: registry).read()
        #expect(Plist.equal(items.filter { !$0.isFinder }.map(\.raw), snapshot.apps))
        #expect(!FileManager.default.fileExists(atPath: path.path))
    }
}
