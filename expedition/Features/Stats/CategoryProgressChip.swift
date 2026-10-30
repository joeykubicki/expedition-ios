import SwiftUI

/// Compact "4 of 63 parks" capsule that floats over the map.
struct CategoryProgressChip: View {
    let progress: CategoryProgress

    var body: some View {
        Text("\(progress.visited) of \(progress.total) \(progress.category.pluralNoun)")
            .font(.subheadline.weight(.semibold))
            .fontDesign(.serif)
            .foregroundStyle(Color.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: .capsule)
            .overlay(Capsule().strokeBorder(progress.category.visitedColor.opacity(0.5), lineWidth: 1))
            .accessibilityLabel("Visited \(progress.visited) of \(progress.total) \(progress.category.pluralNoun)")
    }
}
