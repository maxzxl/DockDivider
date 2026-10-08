import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: DockViewModel
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.string("settings.style")).font(.headline)
            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ForEach(DividerStyle.allCases) { style in
                    styleCard(style)
                }
            }
            Text(L10n.string("settings.appearance")).font(.headline).padding(.top, 8)
            VStack(alignment: .leading, spacing: 12) {
                Toggle(L10n.string("settings.match"), isOn: $model.matchAppearance)
                    .onChange(of: model.matchAppearance) { model.settingsChanged() }
                Toggle(L10n.string("settings.restart"), isOn: $model.automaticallyReload)
                    .onChange(of: model.automaticallyReload) { model.settingsChanged() }
                Text(L10n.string("settings.note"))
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private func styleCard(_ style: DividerStyle) -> some View {
        let selected = model.selectedStyle == style
        let shape = RoundedRectangle(cornerRadius: 14)
        return Button { model.selectedStyle = style } label: {
            HStack(spacing: 12) {
                DividerStylePreview(style: style)
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(style.title).font(.system(size: 13, weight: .semibold))
                            .fixedSize(horizontal: false, vertical: true)
                        if style == .system {
                            Text(L10n.string("settings.default"))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(.quaternary, in: Capsule())
                                .fixedSize()
                        }
                    }
                    Text(style.detail).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 17))
                    .foregroundStyle(selected ? Color.accentColor : Color.secondary.opacity(0.45))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
            .background(selected ? Color.accentColor.opacity(0.08) : Color(nsColor: .controlBackgroundColor), in: shape)
            .overlay(shape.strokeBorder(selected ? Color.accentColor.opacity(0.55) : Color(nsColor: .separatorColor).opacity(0.45), lineWidth: selected ? 1.5 : 1))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
