import SwiftUI

extension PlaceCategory {
    /// Small label above the name in the detail sheet.
    var eyebrow: String {
        switch self {
        case .park: String(localized: "National Park")
        case .state: String(localized: "U.S. State")
        case .country: String(localized: "Country")
        }
    }

    var favoritesTitle: LocalizedStringResource {
        self == .park ? "Favorite Hikes" : "Favorite Cities"
    }

    var addFavoriteTitle: LocalizedStringResource {
        self == .park ? "Add Hike" : "Add City"
    }

    var favoriteNamePrompt: LocalizedStringResource {
        self == .park ? "Hike name" : "City name"
    }

    /// Only hikes carry a link (e.g. to AllTrails).
    var favoritesHaveLinks: Bool {
        self == .park
    }
}
