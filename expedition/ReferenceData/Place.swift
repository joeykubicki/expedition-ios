import CoreLocation

/// A trackable place from the bundled reference data. Read-only; user data
/// about a place lives in SwiftData and refers to it by `PlaceID`.
nonisolated struct Place: Identifiable, Hashable, Sendable {
    let id: PlaceID
    let name: String
    /// Where to put the place's pin or label on the map.
    let labelCoordinate: Coordinate
    /// Outline for states and countries; `nil` for parks.
    let boundary: [BoundaryPolygon]?
    /// USPS codes of the state(s) or territory a park is in; empty otherwise.
    let stateCodes: [String]
    /// `false` for places shown on the map but excluded from progress totals
    /// (Greenland, Puerto Rico, Antarctica).
    let countsTowardTotal: Bool

    var category: PlaceCategory { id.category }
}

nonisolated struct Coordinate: Hashable, Codable, Sendable {
    let latitude: Double
    let longitude: Double

    var clLocationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// One polygon of a place's outline, with optional holes (e.g. Lesotho
/// inside South Africa).
nonisolated struct BoundaryPolygon: Hashable, Sendable {
    let exterior: [Coordinate]
    let holes: [[Coordinate]]
}
