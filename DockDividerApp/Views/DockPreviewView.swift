import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct DockPreviewView: View {
    @ObservedObject var model: DockViewModel
    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .center, spacing: 0) {
                if model.items.first?.isFinder != true { insertion(at: 0) }
                ForEach(Array(model.items.enumerated()), id: \.element.id) { index, item in
                    tile(item, at: index)
                    insertion(at: index + 1)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
        .frame(height: 128)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.separator.opacity(0.4)))
    }
    private func tile(_ item: DockItem, at index: Int) -> some View {
        VStack(spacing: 9) {
            if let divider = item.divider {
                DividerStylePreview(style: divider.style, horizontal: model.orientation.isVertical)
                    .frame(width: 52, height: 52)
                    .contentShape(Rectangle())
                    .onDrag { NSItemProvider(object: item.id as NSString) }
            } else {
                Image(nsImage: icon(item))
                    .resizable().interpolation(.high).scaledToFit().frame(width: 48, height: 48)
            }
            Text(item.divider.map { $0.style == .smallSpacer ? L10n.string("style.small_spacer") : ($0.style == .system ? L10n.string("style.system_short") : $0.style.title) } ?? item.title)
                .font(.caption).foregroundStyle(.secondary).lineLimit(1).frame(width: 76)
            if item.isManaged {
                HStack(spacing: 10) {
                    Button { model.shift(item.id, by: -1) } label: { Image(systemName: "chevron.left") }
                        .help(L10n.string("divider.move_left_help"))
                        .disabled(index <= (model.items.first?.isFinder == true ? 1 : 0))
                    Button { model.remove(item.id) } label: { Image(systemName: "xmark") }.help(L10n.string("divider.remove"))
                    Button { model.shift(item.id, by: 1) } label: { Image(systemName: "chevron.right") }
                        .help(L10n.string("divider.move_right_help")).disabled(index == model.items.count - 1)
                }
                .font(.system(size: 9, weight: .semibold)).buttonStyle(.plain)
            } else { Color.clear.frame(height: 12) }
        }
        .frame(width: 78)
        .contextMenu {
            Button(L10n.string("divider.insert_after")) { model.insert(at: index + 1) }
            if item.isManaged {
                Button(L10n.string("divider.move_left")) { model.shift(item.id, by: -1) }
                Button(L10n.string("divider.move_right")) { model.shift(item.id, by: 1) }
                Button(L10n.string("divider.remove"), role: .destructive) { model.remove(item.id) }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(item.title)
    }
    private func insertion(at index: Int) -> some View {
        Button { model.insert(at: index) } label: {
            Image(systemName: "plus.circle.fill").font(.system(size: 15)).foregroundStyle(.tertiary)
                .frame(width: 26, height: 84).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(L10n.format("divider.insert_here", model.selectedStyle.title))
        .accessibilityLabel(L10n.format("divider.insert_position", index))
        .onDrop(of: [UTType.text], isTargeted: nil) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: String.self) { value, _ in
                guard let value else { return }
                Task { @MainActor in model.move(value, to: index) }
            }
            return true
        }
    }
    private func icon(_ item: DockItem) -> NSImage {
        if item.isFinder { return NSWorkspace.shared.icon(forFile: "/System/Library/CoreServices/Finder.app") }
        if let url = item.url { return NSWorkspace.shared.icon(forFile: url.path) }
        return NSImage(systemSymbolName: "square.dashed", accessibilityDescription: item.title) ?? NSImage()
    }
}
