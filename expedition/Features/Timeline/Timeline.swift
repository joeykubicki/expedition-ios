import Foundation

/// Visits grouped into trips and years for the Timeline tab, plus visited
/// places that don't have any dates yet.
struct Timeline: Equatable {
    struct Item: Identifiable, Equatable {
        let place: Place
        let visit: Visit
        /// Not the place's first (earliest) visit.
        let isReturn: Bool
        var id: UUID { visit.id }
    }

    /// Visits whose dates overlap, usually one item. Year-only visits never
    /// join a trip: "2019" would overlap everything else that year.
    struct Trip: Identifiable, Equatable {
        /// Oldest first, the order they happened.
        let items: [Item]
        /// The whole trip's dates, at the coarsest precision in it.
        let span: Visit
        var id: UUID { items[0].id }
        var isSingle: Bool { items.count == 1 }
    }

    struct Year: Identifiable, Equatable {
        let year: Int
        /// Newest first.
        let trips: [Trip]
        var id: Int { year }

        var items: [Item] { trips.flatMap(\.items) }
        /// Distinct places visited that year (one place can have several trips).
        var placeCount: Int { Set(items.map(\.place.id)).count }
        /// Places first visited that year.
        var newPlaceCount: Int { Set(items.filter { !$0.isReturn }.map(\.place.id)).count }
        var countryCount: Int { Set(items.filter { $0.place.category == .country }.map(\.place.id)).count }
    }

    /// Newest year first. A trip belongs to the year it started.
    let years: [Year]
    /// Visited places with no visits, by name.
    let undated: [Place]

    var isEmpty: Bool { years.isEmpty && undated.isEmpty }

    /// Builds the timeline from visited entries in `category` (or every
    /// category when `nil`). Unvisited places are left out even if they have
    /// visits, and so are entries whose place isn't in the reference data.
    /// Trips only group what's shown.
    init(entries: [PlaceEntry], category: PlaceCategory?, showsReturnVisits: Bool = true, place: (PlaceID) -> Place?) {
        // By place, so unmerged duplicate entries agree on the first visit.
        var visitsByPlace: [PlaceID: (place: Place, visits: [Visit])] = [:]
        for entry in entries where entry.isVisited {
            guard let id = entry.placeID, category == nil || id.category == category,
                  let place = place(id)
            else { continue }
            visitsByPlace[id, default: (place, [])].visits += entry.visits
        }

        var items: [Item] = []
        var undated: [Place] = []
        for (place, visits) in visitsByPlace.values {
            guard !visits.isEmpty else {
                undated.append(place)
                continue
            }
            let chronological = visits.sorted { Visit.newestFirst($1, $0) }
            for (index, visit) in chronological.enumerated() where showsReturnVisits || index == 0 {
                items.append(Item(place: place, visit: visit, isReturn: index > 0))
            }
        }

        let byYear = Dictionary(grouping: Self.trips(from: items)) { $0.span.start.year }
        years = byYear.keys.sorted(by: >).map { year in
            Year(year: year, trips: byYear[year]!.sorted(by: Self.newestFirst))
        }
        self.undated = undated.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Joins items whose days overlap (sharing a day counts), following chains.
    static func trips(from items: [Item]) -> [Trip] {
        let (yearOnly, groupable) = (items.filter { $0.visit.start.precision == .year },
                                     items.filter { $0.visit.start.precision != .year })
        var groups: [[Item]] = []
        var groupEnd: VisitDate?
        for item in groupable.sorted(by: chronological) {
            let days = item.visit.days
            if let end = groupEnd, days.lowerBound <= end {
                groups[groups.count - 1].append(item)
                groupEnd = max(end, days.upperBound)
            } else {
                groups.append([item])
                groupEnd = days.upperBound
            }
        }
        groups += yearOnly.map { [$0] }
        return groups.map { Trip(items: $0, span: span(of: $0)) }
    }

    /// From the earliest start to the latest end, at the coarsest precision
    /// in the trip (October 2023 for Utah in October plus Zion Oct 12–15).
    private static func span(of items: [Item]) -> Visit {
        if items.count == 1 { return items[0].visit }
        let precision = items.map(\.visit.start.precision).max { $0.coarseness < $1.coarseness }!
        let start = items.map(\.visit.start).min()!.truncated(to: precision)
        let end = items.map { $0.visit.end ?? $0.visit.start }.max()!.truncated(to: precision)
        return Visit(id: items[0].visit.id, start: start, end: end > start ? end : nil)
    }

    private static func chronological(_ a: Item, _ b: Item) -> Bool {
        if a.visit.days.lowerBound != b.visit.days.lowerBound {
            return a.visit.days.lowerBound < b.visit.days.lowerBound
        }
        return a.place.name.localizedStandardCompare(b.place.name) == .orderedAscending
    }

    private static func newestFirst(_ a: Trip, _ b: Trip) -> Bool {
        if a.span.start != b.span.start || a.span.end != b.span.end {
            return Visit.newestFirst(a.span, b.span)
        }
        return a.items[0].place.name.localizedStandardCompare(b.items[0].place.name) == .orderedAscending
    }
}
