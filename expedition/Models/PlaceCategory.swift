import Foundation

/// The kinds of places a user can track.
///
/// SwiftData models store this as its raw `String` value so `#Predicate`
/// filtering works reliably.
nonisolated enum PlaceCategory: String, CaseIterable, Codable, Sendable {
    case park
    case state
    case country
}

/// Identifies a place across all categories.
///
/// Codes are only unique within a category ("CA" is both California and
/// Canada), so the category is part of the identity.
nonisolated struct PlaceID: Hashable, Codable, Sendable {
    let category: PlaceCategory
    /// Park slug (`grand-canyon`), USPS state code (`UT`), or ISO 3166-1
    /// alpha-2 country code (`JP`).
    let code: String
}
