import SwiftUI

/// One place in a category list, with a button to mark it visited and a
/// bookmark when it's on the bucket list. Tapping the rest of the row opens
/// the place's details.
struct PlaceRow: View {
    let place: Place
    let subtitle: String?
    let isVisited: Bool
    var isOnBucketList = false
    let onToggleVisited: () -> Void
    var onToggleBucketList: () -> Void = {}
    let onSelect: () -> Void

    private var flag: String? {
        place.category == .country ? FlagEmoji.forRegionCode(place.id.code) : nil
    }

    private var toggleTitle: LocalizedStringResource {
        isVisited ? "Mark as Not Visited" : "Mark as Visited"
    }

    private var bucketListTitle: LocalizedStringResource {
        isOnBucketList ? "Remove from Bucket List" : "Add to Bucket List"
    }

    private var status: LocalizedStringResource {
        if isVisited { "Visited" } else if isOnBucketList { "On bucket list" } else { "Not visited" }
    }

    var body: some View {
        HStack(spacing: 12) {
            if let flag {
                Text(flag)
                    .font(.title2)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(place.name)
                    if isOnBucketList, !isVisited {
                        Image(systemName: "bookmark.fill")
                            .font(.caption)
                            .foregroundStyle(place.category.visitedColor)
                    }
                }
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
        .contentShape(.rect)
        .onTapGesture(perform: onSelect)
        .swipeActions(edge: .leading) {
            Button(isVisited ? "Not Visited" : "Visited",
                   systemImage: isVisited ? "xmark.circle" : "checkmark.circle",
                   action: onToggleVisited)
                .tint(isVisited ? .gray : place.category.visitedColor)
        }
        .swipeActions(edge: .trailing) {
            if !isVisited {
                Button(isOnBucketList ? "Remove" : "Bucket List",
                       systemImage: isOnBucketList ? "bookmark.slash" : "bookmark",
                       action: onToggleBucketList)
                    .tint(isOnBucketList ? .gray : .visitedDeep)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(subtitle.map { "\(place.name), \($0)" } ?? place.name)
        .accessibilityValue(Text(status))
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Shows details and memories")
        .accessibilityAction { onSelect() }
        .accessibilityAction(named: Text(toggleTitle), onToggleVisited)
        .accessibilityActions {
            if !isVisited {
                Button(bucketListTitle, action: onToggleBucketList)
            }
        }
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
        PlaceRow(place: zion, subtitle: "Utah", isVisited: true, onToggleVisited: {}, onSelect: {})
        PlaceRow(place: zion, subtitle: "Utah", isVisited: false, onToggleVisited: {}, onSelect: {})
        PlaceRow(place: zion, subtitle: "Utah", isVisited: false, isOnBucketList: true, onToggleVisited: {}, onSelect: {})
        PlaceRow(place: japan, subtitle: nil, isVisited: true, onToggleVisited: {}, onSelect: {})
    }
}
