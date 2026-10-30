import Foundation

/// Visits grouped by year for the Timeline tab, plus visited places that
/// don't have any dates yet.
struct Timeline: Equatable {
    struct Item: Identifiable, Equatable {
        let place: Place
        let visit: Visit
        var id: UUID { visit.id }
    }

    struct Year: Identifiable, Equatable {
        let year: Int
        /// Newest first.
        let items: [Item]
        var id: Int { year }
        /// Distinct places visited that year (one place can have several trips).
        var placeCount: Int { Set(items.map(\.place.id)).count }
    }

    /// Newest year first. A visit belongs to the year it started.
    let years: [Year]
    /// Visited places with no visits, by name.
    let undated: [Place]

    var isEmpty: Bool { years.isEmpty && undated.isEmpty }

    /// Builds the timeline from visited entries in `category` (or every
    /// category when `nil`). Unvisited places are left out even if they have
    /// visits, and so are entries whose place isn't in the reference data.
    init(entries: [PlaceEntry], category: PlaceCategory?, place: (PlaceID) -> Place?) {
        var items: [Item] = []
        var undated: [Place] = []
        for entry in entries where entry.isVisited {
            guard let id = entry.placeID, category == nil || id.category == category,
                  let place = place(id)
            else { continue }
            if entry.visits.isEmpty {
                undated.append(place)
            } else {
                items += entry.visits.map { Item(place: place, visit: $0) }
            }
        }

        let byYear = Dictionary(grouping: items) { $0.visit.start.year }
        years = byYear.keys.sorted(by: >).map { year in
            Year(year: year, items: byYear[year]!.sorted(by: Self.newestFirst))
        }
        self.undated = undated.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private static func newestFirst(_ a: Item, _ b: Item) -> Bool {
        if a.visit.start != b.visit.start || a.visit.end != b.visit.end {
            return Visit.newestFirst(a.visit, b.visit)
        }
        return a.place.name.localizedStandardCompare(b.place.name) == .orderedAscending
    }
}
