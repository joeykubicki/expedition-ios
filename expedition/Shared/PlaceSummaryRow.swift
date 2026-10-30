import SwiftUI

/// A place in a cross-category list (Timeline, Bucket List): its flag or
/// category icon, name, and a detail line such as a visit's dates.
struct PlaceSummaryRow: View {
    let place: Place
    let detail: String
    /// Marks a return visit on the Timeline.
    var isReturnVisit = false
    /// Extra spoken context, such as "trip with Utah".
    var accessibilityContext: String?
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
                    if isReturnVisit {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Return visit")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.inkSoft)
                    }
                }
                Spacer(minLength: 0)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(Text(hint))
    }

    private var accessibilityLabel: String {
        var parts = [place.name, place.category.eyebrow]
        if detail != place.category.eyebrow { parts.append(detail) }
        if isReturnVisit { parts.append(String(localized: "Return visit")) }
        if let accessibilityContext { parts.append(accessibilityContext) }
        return parts.joined(separator: ", ")
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
