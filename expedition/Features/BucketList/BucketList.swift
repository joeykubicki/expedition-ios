import Foundation

/// The Bucket List tab's contents: places the user wants to visit, grouped
/// by category (parks, states, countries), newest additions first.
struct BucketList: Equatable {
    struct Item: Identifiable, Equatable {
        let place: Place
        let addedAt: Date?
        var id: PlaceID { place.id }
    }

    struct Group: Identifiable, Equatable {
        let category: PlaceCategory
        let items: [Item]
        var id: PlaceCategory { category }
    }

    /// In category order; categories with nothing listed are left out.
    let groups: [Group]

    var isEmpty: Bool { groups.isEmpty }

    /// Builds the list from entries in `category` (or every category when
    /// `nil`). Visited places are left out even if still flagged, and so are
    /// entries whose place isn't in the reference data.
    init(entries: [PlaceEntry], category: PlaceCategory?, place: (PlaceID) -> Place?) {
        var itemsByID: [PlaceID: Item] = [:]
        for entry in entries where entry.wantsToVisit {
            guard let id = entry.placeID, category == nil || id.category == category,
                  let place = place(id)
            else { continue }
            // Unmerged duplicates from sync: keep the earliest addition.
            let addedAt = [itemsByID[id]?.addedAt, entry.bucketListAddedAt].compactMap { $0 }.min()
            itemsByID[id] = Item(place: place, addedAt: addedAt)
        }
        groups = PlaceCategory.allCases.compactMap { category in
            let items = itemsByID.values.filter { $0.place.category == category }.sorted(by: Self.newestFirst)
            return items.isEmpty ? nil : Group(category: category, items: items)
        }
    }

    private static func newestFirst(_ a: Item, _ b: Item) -> Bool {
        switch (a.addedAt, b.addedAt) {
        case let (a?, b?) where a != b: a > b
        case (.some, nil): true
        case (nil, .some): false
        default: a.place.name.localizedStandardCompare(b.place.name) == .orderedAscending
        }
    }
}
