import SwiftUI

/// A place in a cross-category list (Timeline, Bucket List): its flag or
/// category icon, name, and a detail line such as a visit's dates.
struct PlaceSummaryRow: View {
    let place: Place
    let detail: String
    let hint: LocalizedStringResource
    let onSelect: () -> Void

    @ScaledMetric(relativeTo: .title2) private var iconWidth = 32.0

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                icon
                    .frame(width: iconWidth)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(place.name)
                        .foregroundStyle(Color.ink)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(detail == place.category.eyebrow ? "\(place.name), \(detail)" : "\(place.name), \(place.category.eyebrow), \(detail)")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(Text(hint))
    }

    @ViewBuilder
    private var icon: some View {
        if place.category == .country, let flag = FlagEmoji.forRegionCode(place.id.code) {
            Text(flag)
                .font(.title2)
        } else {
            Image(systemName: place.category.symbolName)
                .font(.title3)
                .foregroundStyle(place.category.visitedColor)
        }
    }
}
