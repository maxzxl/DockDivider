import SwiftUI

struct DividerStylePreview: View {
    let style: DividerStyle
    var horizontal = false
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        ZStack {
            if style.isLine {
                Rectangle()
                    .fill((colorScheme == .dark ? Color.white : Color.black).opacity(style.opacity))
                    .frame(width: horizontal ? 34 * style.lineHeight : style.lineWidth,
                           height: horizontal ? style.lineWidth : 34 * style.lineHeight)
            } else {
                HStack(spacing: style == .spacer ? 17 : 7) {
                    RoundedRectangle(cornerRadius: 2).fill(.secondary.opacity(0.35)).frame(width: 5, height: 17)
                    RoundedRectangle(cornerRadius: 2).fill(.secondary.opacity(0.35)).frame(width: 5, height: 17)
                }
            }
        }
        .frame(width: 46, height: 38)
        .accessibilityHidden(true)
    }
}
