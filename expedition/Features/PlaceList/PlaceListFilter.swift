import Foundation

nonisolated enum VisitFilter: String, CaseIterable, Sendable {
    case all
    case visited
    case bucketList
    case notVisited
}

/// Search and visited filtering for a category's list. Pure so it can be
/// tested without views.
nonisolated enum PlaceListFilter {
    /// Places matching the search text and visit filter, in their original order.
    /// `bucketListCodes` should hold only places not yet visited.
    ///
    /// Search ignores case and accents and matches the place name, an exact
    /// state/country code, or (for parks) the name of a state the park is in.
    static func filter(
        _ places: [Place],
        searchText: String,
        visitFilter: VisitFilter,
        visitedCodes: Set<String>,
        bucketListCodes: Set<String> = [],
        stateNames: [String: String]
    ) -> [Place] {
        let query = normalized(searchText)
        return places.filter { place in
            let isVisited = visitedCodes.contains(place.id.code)
            switch visitFilter {
            case .all: break
            case .visited: guard isVisited else { return false }
            case .bucketList: guard !isVisited, bucketListCodes.contains(place.id.code) else { return false }
            case .notVisited: guard !isVisited else { return false }
            }
            return query.isEmpty || matches(place, query: query, stateNames: stateNames)
        }
    }

    /// Splits alphabetically sorted places into runs by first letter, for the
    /// A–Z section index.
    static func sectionedByInitial(_ places: [Place]) -> [(initial: String, places: [Place])] {
        var sections: [(initial: String, places: [Place])] = []
        for place in places {
            let initial = normalized(String(place.name.prefix(1))).uppercased()
            if sections.last?.initial == initial {
                sections[sections.count - 1].places.append(place)
            } else {
                sections.append((initial, [place]))
            }
        }
        return sections
    }

    private static func matches(_ place: Place, query: String, stateNames: [String: String]) -> Bool {
        if normalized(place.name).contains(query) { return true }
        if place.category != .park, normalized(place.id.code) == query { return true }
        return place.stateCodes.contains { code in
            stateNames[code].map { normalized($0).contains(query) } ?? false
        }
    }

    private static func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}
