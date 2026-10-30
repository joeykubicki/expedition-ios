import MapKit

/// What the year map shows: each place visited that year once, numbered by
/// its trips in order (oldest first), and where to point the camera.
struct YearMap: Equatable {
    struct Stop: Identifiable, Equatable {
        let place: Place
        /// The year's trips this place was on, e.g. [1] or [1, 3].
        let tripNumbers: [Int]
        var id: PlaceID { place.id }
    }

    /// Oldest first, numbered from 1; same order as `stops` is numbered.
    let trips: [Timeline.Trip]
    /// In order of first trip.
    let stops: [Stop]

    init(year: Timeline.Year) {
        trips = year.trips.reversed()
        var numbersByPlace: [PlaceID: (place: Place, numbers: [Int])] = [:]
        var order: [PlaceID] = []
        for (index, trip) in trips.enumerated() {
            for item in trip.items {
                if numbersByPlace[item.place.id] == nil {
                    order.append(item.place.id)
                    numbersByPlace[item.place.id] = (item.place, [])
                }
                if numbersByPlace[item.place.id]?.numbers.last != index + 1 {
                    numbersByPlace[item.place.id]?.numbers.append(index + 1)
                }
            }
        }
        stops = order.map { Stop(place: numbersByPlace[$0]!.place, tripNumbers: numbersByPlace[$0]!.numbers) }
    }

    var places: [Place] { stops.map(\.place) }

    /// Fits every stop, or `nil` for the whole world.
    var mapRect: MKMapRect? {
        Self.mapRect(fitting: places)
    }

    /// Places spread over more than this many degrees of longitude get the
    /// whole world instead.
    nonisolated static let widestSpan = 200.0
    /// So a single park isn't shown at street level.
    nonisolated static let narrowestSpan = 3.0

    /// The smallest map rectangle containing every place's main landmass (or
    /// its label point, for parks), with a margin. Only the largest polygon
    /// counts, so France means mainland France, not French Guiana. Works
    /// across the 180° meridian by framing the shortest way round: Fiji's two
    /// halves sit side by side, and a rectangle may extend past the edge of
    /// the world, which MapKit wraps.
    nonisolated static func mapRect(fitting places: [Place]) -> MKMapRect? {
        var longitudes: [(min: Double, max: Double)] = []
        var latitudes = (min: 90.0, max: -90.0)
        func include(_ ring: [Coordinate]) {
            guard let first = ring.first else { return }
            var lon = (min: first.longitude, max: first.longitude)
            for coordinate in ring {
                lon = (min(lon.min, coordinate.longitude), max(lon.max, coordinate.longitude))
                latitudes = (min(latitudes.min, coordinate.latitude), max(latitudes.max, coordinate.latitude))
            }
            longitudes.append(lon)
        }
        for place in places {
            // Outlines are split at 180° in the source data, so no single
            // polygon wraps.
            if let mainland = place.boundary?.max(by: { boxArea($0.exterior) < boxArea($1.exterior) }) {
                include(mainland.exterior)
            } else {
                include([place.labelCoordinate])
            }
        }
        guard !longitudes.isEmpty else { return nil }

        // Merge overlapping spans, then leave out the biggest empty gap
        // (including the one that wraps past 180°).
        var merged: [(min: Double, max: Double)] = []
        for span in longitudes.sorted(by: { $0.min < $1.min }) {
            if let last = merged.last, span.min <= last.max {
                merged[merged.count - 1].max = max(last.max, span.max)
            } else {
                merged.append(span)
            }
        }
        var gap = (start: merged.last!.max, end: merged[0].min + 360)
        for (a, b) in zip(merged, merged.dropFirst()) where b.min - a.max > gap.end - gap.start {
            gap = (a.max, b.min)
        }
        var west = gap.end, width = 360 - (gap.end - gap.start)
        guard width <= widestSpan else { return nil }
        if west >= 180 { west -= 360 }

        let worldWidth = MKMapSize.world.width
        let northwest = MKMapPoint(CLLocationCoordinate2D(latitude: min(latitudes.max, 85), longitude: west))
        let south = MKMapPoint(CLLocationCoordinate2D(latitude: max(latitudes.min, -85), longitude: west))
        let fitted = MKMapRect(x: northwest.x, y: northwest.y, width: width / 360 * worldWidth, height: south.y - northwest.y)

        // A margin, and never smaller than `narrowestSpan`.
        let smallest = narrowestSpan / 360 * worldWidth
        let size = MKMapSize(width: max(fitted.width * 1.4, smallest), height: max(fitted.height * 1.4, smallest))
        return MKMapRect(
            x: fitted.midX - size.width / 2,
            y: max(fitted.midY - size.height / 2, 0),
            width: size.width,
            height: min(size.height, MKMapSize.world.height)
        )
    }

    /// Bounding-box area in degrees², only for comparing a place's polygons.
    private nonisolated static func boxArea(_ ring: [Coordinate]) -> Double {
        let lons = ring.map(\.longitude), lats = ring.map(\.latitude)
        guard let minLon = lons.min(), let maxLon = lons.max(), let minLat = lats.min(), let maxLat = lats.max() else { return 0 }
        return (maxLon - minLon) * (maxLat - minLat)
    }
}
