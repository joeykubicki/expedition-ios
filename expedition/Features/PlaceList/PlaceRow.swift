import SwiftUI

/// One place in a category list, with a button to mark it visited.
struct PlaceRow: View {
    let place: Place
    let subtitle: String?
    let isVisited: Bool
    let onToggleVisited: () -> Void

    private var flag: String? {
        place.category == .country ? FlagEmoji.forRegionCode(place.id.code) : nil
    }

    private var toggleTitle: LocalizedStringResource {
        isVisited ? "Mark as Not Visited" : "Mark as Visited"
    }

    var body: some View {
        HStack(spacing: 12) {
            if let flag {
                Text(flag)
                    .font(.title2)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(place.name)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            Button(action: onToggleVisited) {
                Image(systemName: isVisited ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isVisited ? place.category.visitedColor : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.borderless)
        }
        .swipeActions(edge: .leading) {
            Button(isVisited ? "Not Visited" : "Visited",
                   systemImage: isVisited ? "xmark.circle" : "checkmark.circle",
                   action: onToggleVisited)
                .tint(isVisited ? .gray : place.category.visitedColor)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(subtitle.map { "\(place.name), \($0)" } ?? place.name)
        .accessibilityValue(isVisited ? "Visited" : "Not visited")
        .accessibilityAction(named: Text(toggleTitle), onToggleVisited)
    }
}

#Preview {
    let zion = Place(
        id: PlaceID(category: .park, code: "zion"),
        name: "Zion",
        labelCoordinate: Coordinate(latitude: 37.3, longitude: -113.05),
        boundary: nil,
        stateCodes: ["UT"],
        countsTowardTotal: true
    )
    let japan = Place(
        id: PlaceID(category: .country, code: "JP"),
        name: "Japan",
        labelCoordinate: Coordinate(latitude: 36, longitude: 138),
        boundary: nil,
        stateCodes: [],
        countsTowardTotal: true
    )
    List {
        PlaceRow(place: zion, subtitle: "Utah", isVisited: true, onToggleVisited: {})
        PlaceRow(place: zion, subtitle: "Utah", isVisited: false, onToggleVisited: {})
        PlaceRow(place: japan, subtitle: nil, isVisited: true, onToggleVisited: {})
    }
}
