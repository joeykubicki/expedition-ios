import SwiftUI

extension View {
    /// Centers a scrolling list in a column no wider than `maxWidth`, so rows
    /// don't stretch across an iPad. The background and scroll indicators
    /// still fill the screen. Does nothing when the screen is narrower.
    func readableContentWidth(_ maxWidth: CGFloat = 700) -> some View {
        modifier(ReadableContentWidth(maxWidth: maxWidth))
    }
}

private struct ReadableContentWidth: ViewModifier {
    let maxWidth: CGFloat
    @State private var width: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .contentMargins(.horizontal, max(0, (width - maxWidth) / 2), for: .scrollContent)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }
}
