import AppKit
import SwiftUI

@main
struct DockDividerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = DockViewModel()
    var body: some Scene {
        Window("DockDivider", id: "main") {
            ContentView(model: model)
        }
        .defaultSize(width: 800, height: 820)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .toolbar) {
                Button(L10n.string("dock.read_menu")) { model.reload() }.disabled(model.hasChanges)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
