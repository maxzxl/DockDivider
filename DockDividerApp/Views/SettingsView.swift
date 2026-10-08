import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: DockViewModel
    private let lineColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
    private let spacerColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(L10n.string("settings.style")).font(.headline)
                Spacer()
                Text(L10n.string("settings.style_help")).font(.caption).foregroundStyle(.secondary)
            }
            LazyVGrid(columns: lineColumns, spacing: 10) {
                ForEach([DividerStyle.system, .thin, .standard]) { style in
                    styleCard(style)
                }
            }
            LazyVGrid(columns: spacerColumns, spacing: 10) {
                ForEach([DividerStyle.spacer, .smallSpacer]) { style in
                    styleCard(style)
                }
            }
            Text(L10n.string("settings.appearance")).font(.headline).padding(.top, 10)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(L10n.string("settings.match"))
                    Spacer()
                    Toggle(L10n.string("settings.match"), isOn: $model.matchAppearance).labelsHidden()
                        .onChange(of: model.matchAppearance) { model.settingsChanged() }
                }
                Divider()
                HStack {
                    Text(L10n.string("settings.restart"))
                    Spacer()
                    Toggle(L10n.string("settings.restart"), isOn: $model.automaticallyReload).labelsHidden()
                        .onChange(of: model.automaticallyReload) { model.settingsChanged() }
                }
            }
            .toggleStyle(.switch).controlSize(.small)
            .padding(14)
            .background(.background.opacity(0.65), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.separator.opacity(0.35)))
            Text(L10n.string("settings.note"))
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func styleCard(_ style: DividerStyle) -> some View {
        let selected = model.selectedStyle == style
        let shape = RoundedRectangle(cornerRadius: 14)
        return Button { model.selectedStyle = style } label: {
            Group {
                if style.isLine {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            DividerStylePreview(style: style).frame(height: 28)
                            Spacer(minLength: 4)
                            if style == .system {
                                Text(L10n.string("settings.default"))
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 6).padding(.vertical, 3)
                                    .background(.quaternary, in: Capsule())
                            }
                            selectionMark(selected)
                        }
                        Text(style == .system ? L10n.string("style.system_short") : style.title)
                            .font(.system(size: 13, weight: .semibold))
                        Text(style.detail).font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, minHeight: 94, alignment: .leading)
                } else {
                    HStack(spacing: 10) {
                        DividerStylePreview(style: style)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(style.title).font(.system(size: 13, weight: .semibold))
                            Text(style.detail).font(.caption).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        selectionMark(selected)
                    }
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                }
            }
            .padding(12)
            .background(selected ? Color.accentColor.opacity(0.075) : Color(nsColor: .controlBackgroundColor).opacity(0.75), in: shape)
            .overlay(shape.strokeBorder(selected ? Color.accentColor.opacity(0.6) : Color(nsColor: .separatorColor).opacity(0.35), lineWidth: selected ? 1.5 : 1))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .help(style.title)
    }

    private func selectionMark(_ selected: Bool) -> some View {
        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 15))
            .foregroundStyle(selected ? Color.accentColor : Color.secondary.opacity(0.4))
            .accessibilityHidden(true)
    }
}
