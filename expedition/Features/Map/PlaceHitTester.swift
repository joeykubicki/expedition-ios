import Foundation

/// Finds which state or country outline contains a tapped coordinate.
///
/// Outlines are split at the 180° meridian in the source data, so plain
/// longitude/latitude math works on both sides of it.
nonisolated enum PlaceHitTester {
    /// The place whose outline contains `coordinate`. When several do (a tiny
    /// country inside a larger outline), the one with the smallest containing
    /// polygon wins. `nil` for water or places without outlines.
    static func place(at coordinate: Coordinate, in places: [Place]) -> Place? {
        let point = Coordinate(latitude: coordinate.latitude, longitude: normalizedLongitude(coordinate.longitude))
        var best: (place: Place, area: Double)?
        for place in places {
            for polygon in place.boundary ?? [] where contains(polygon, point) {
                let area = abs(signedArea(polygon.exterior))
                if best == nil || area < best!.area {
                    best = (place, area)
                }
            }
        }
        return best?.place
    }

    /// Inside the exterior ring and outside every hole.
    static func contains(_ polygon: BoundaryPolygon, _ point: Coordinate) -> Bool {
        ringContains(polygon.exterior, point) && !polygon.holes.contains { ringContains($0, point) }
    }

    /// Even-odd ray casting.
    private static func ringContains(_ ring: [Coordinate], _ point: Coordinate) -> Bool {
        var inside = false
        var j = ring.count - 1
        for i in ring.indices {
            let a = ring[i], b = ring[j]
            if (a.latitude > point.latitude) != (b.latitude > point.latitude) {
                let crossing = (b.longitude - a.longitude) * (point.latitude - a.latitude)
                    / (b.latitude - a.latitude) + a.longitude
                if point.longitude < crossing {
                    inside.toggle()
                }
            }
            j = i
        }
        return inside
    }

    /// Shoelace formula in degrees²; only used to compare sizes.
    private static func signedArea(_ ring: [Coordinate]) -> Double {
        zip(ring, ring.dropFirst()).reduce(0) { sum, pair in
            sum + pair.0.longitude * pair.1.latitude - pair.1.longitude * pair.0.latitude
        } / 2
    }

    /// Maps that wrap around can report longitudes outside -180...180.
    private static func normalizedLongitude(_ longitude: Double) -> Double {
        var value = longitude.truncatingRemainder(dividingBy: 360)
        if value > 180 { value -= 360 }
        if value < -180 { value += 360 }
        return value
    }
}
