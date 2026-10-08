import AppKit
import SwiftUI

// An explicit type alias uses the compatible property wrapper even when a newer
// SDK also exports a State macro that Command Line Tools cannot load.
private typealias ViewState<Value> = SwiftUI.State<Value>

struct ContentView: View {
    @ObservedObject var model: DockViewModel
    @Environment(\.colorScheme) private var colorScheme
    @ViewState private var recovery: RecoveryAction? = nil
    @ViewState private var discard = false
    @ViewState private var showDockInfo = false
    private let contentWidth: CGFloat = 860
    enum RecoveryAction: String, Identifiable {
        case previous, original, removeAll
        var id: String { rawValue }
        var title: String {
            switch self {
            case .previous: L10n.string("restore.previous_title")
            case .original: L10n.string("restore.original_title")
            case .removeAll: L10n.string("restore.remove_title")
            }
        }
    }
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(spacing: 14) {
                        Image(nsImage: NSApplication.shared.applicationIconImage)
                            .resizable().scaledToFit().frame(width: 54, height: 54)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("DockDivider").font(.system(size: 25, weight: .semibold))
                            Text(L10n.string("app.tagline")).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if model.isDemo { Text(L10n.string("demo.notice")).font(.caption).foregroundStyle(.secondary) }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(L10n.string("dock.current")).font(.headline)
                            Button { showDockInfo.toggle() } label: {
                                Image(systemName: "info.circle").foregroundStyle(.secondary)
                            }
                            .buttonStyle(.borderless)
                            .help(L10n.string("dock.read_info"))
                            .accessibilityLabel(L10n.string("dock.read_info_label"))
                            .popover(isPresented: $showDockInfo, arrowEdge: .bottom) {
                                Text(L10n.string("dock.read_info"))
                                    .font(.callout).fixedSize(horizontal: false, vertical: true)
                                    .frame(width: 310, alignment: .leading).padding(16)
                            }
                            Spacer()
                            Button { if model.hasChanges { discard = true } else { model.reload() } } label: {
                                Label(L10n.string("dock.read"), systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.borderless).disabled(model.isBusy)
                        }
                        DockPreviewView(model: model).disabled(!model.canEdit)
                        Text(L10n.string("dock.edit_help"))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    SettingsView(model: model).disabled(!model.canEdit)
                    HStack(alignment: .top, spacing: 9) {
                        Image(systemName: "info.circle").foregroundStyle(.secondary)
                        Text(L10n.string("dock.line_note"))
                            .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: contentWidth)
                .padding(28)
                .frame(maxWidth: .infinity)
            }
            Divider()
            VStack(spacing: 13) {
                HStack {
                    Menu {
                        Button(L10n.string("restore.previous")) { recovery = .previous }.disabled(!model.backupAvailable)
                        Button(L10n.string("restore.original")) { recovery = .original }.disabled(!model.originalAvailable)
                        Divider()
                        Button(L10n.string("restore.remove_all"), role: .destructive) { recovery = .removeAll }
                            .disabled(model.managedCount == 0)
                        Divider()
                        Button(L10n.string("restore.open_backups")) { model.showBackups() }
                    } label: { Label(L10n.string("restore.menu"), systemImage: "clock.arrow.circlepath") }
                    .menuStyle(.borderlessButton).fixedSize().disabled(!model.canEdit)
                    Spacer()
                    if model.isBusy { ProgressView().controlSize(.small) }
                    Button(L10n.string("dock.restart")) { model.restartDock() }.disabled(model.isBusy || model.isDemo)
                    Button(L10n.string("dock.apply")) { model.apply() }
                        .buttonStyle(.borderedProminent).keyboardShortcut(.return, modifiers: .command)
                        .disabled(!model.hasChanges || !model.canEdit)
                }
                HStack {
                    Circle().fill(model.hasChanges ? Color.orange : Color.secondary.opacity(0.5)).frame(width: 5, height: 5)
                    Text(model.status).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    Spacer()
                }
            }
            .frame(maxWidth: contentWidth)
            .padding(.horizontal, 28).padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(.bar)
        }
        .frame(minWidth: 720, idealWidth: 800, minHeight: 790)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { model.appearanceChanged(dark: colorScheme == .dark) }
        .onChange(of: colorScheme) { _, scheme in model.appearanceChanged(dark: scheme == .dark) }
        .alert("DockDivider", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button(L10n.string("common.ok")) { model.error = nil }
        } message: { Text(model.error ?? "") }
        .alert(L10n.string("discard.title"), isPresented: $discard) {
            Button(L10n.string("common.cancel"), role: .cancel) {}
            Button(L10n.string("dock.read"), role: .destructive) { model.reload() }
        } message: { Text(L10n.string("discard.message")) }
        .alert(item: $recovery) { action in
            Alert(title: Text(action.title),
                  message: Text(action == .removeAll
                    ? L10n.string("restore.remove_message")
                    : L10n.string("restore.message")),
                  primaryButton: .destructive(Text(action == .removeAll ? L10n.string("common.remove") : L10n.string("common.restore"))) {
                      switch action {
                      case .previous: model.restore(original: false)
                      case .original: model.restore(original: true)
                      case .removeAll: model.removeAll()
                      }
                  }, secondaryButton: .cancel(Text(L10n.string("common.cancel"))))
        }
    }
}
