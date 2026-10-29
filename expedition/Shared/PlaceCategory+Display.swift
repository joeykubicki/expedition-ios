import SwiftUI

extension PlaceCategory {
    /// Tab and navigation title.
    var title: LocalizedStringResource {
        switch self {
        case .park: "Parks"
        case .state: "States"
        case .country: "Countries"
        }
    }

    /// Lowercase plural for sentences like "42 of 63 parks".
    var pluralNoun: String {
        switch self {
        case .park: String(localized: "parks")
        case .state: String(localized: "states")
        case .country: String(localized: "countries")
        }
    }

    var symbolName: String {
        switch self {
        case .park: "tree.fill"
        case .state: "map.fill"
        case .country: "globe.americas.fill"
        }
    }

    /// Fill for visited places: evergreen for parks, rust for everything else.
    var visitedColor: Color {
        self == .park ? .parkVisited : .visited
    }
}
