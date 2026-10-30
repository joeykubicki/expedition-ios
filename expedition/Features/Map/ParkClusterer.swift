import MapKit

/// Parks whose markers would overlap at the current zoom, shown as one marker.
nonisolated struct ParkCluster: Identifiable, Equatable, Sendable {
    let parks: [Place]

    var id: String { parks.map(\.id.code).joined(separator: "+") }
    var isSingle: Bool { parks.count == 1 }

    /// The members' average position on the flat map, which is where the
    /// clusterer measures overlaps from (parks never span the antimeridian).
    var coordinate: Coordinate {
        let center = ParkClusterer.center(of: parks.map(ParkClusterer.mapPoint)).coordinate
        return Coordinate(latitude: center.latitude, longitude: center.longitude)
    }

    /// A region that fits every member with room to spare, so they separate
    /// when the map zooms to it.
    var zoomRegion: MKCoordinateRegion {
        let latitudes = parks.map(\.labelCoordinate.latitude)
        let longitudes = parks.map(\.labelCoordinate.longitude)
        let minimumSpan = 1.5 // degrees; the closest parks (Sequoia, Kings Canyon) are 0.4° apart
        return MKCoordinateRegion(
            center: coordinate.clLocationCoordinate,
            span: MKCoordinateSpan(
                latitudeDelta: max((latitudes.max()! - latitudes.min()!) * 3, minimumSpan),
                longitudeDelta: max((longitudes.max()! - longitudes.min()!) * 3, minimumSpan)
            )
        )
    }
}

nonisolated enum ParkClusterer {
    /// Groups parks so that no two markers on screen are closer than
    /// `spacing` (width apart horizontally or height apart vertically).
    ///
    /// - Parameter pointsPerMapPoint: screen points per `MKMapPoint` unit at
    ///   the current zoom, or `nil` when unknown (every park stands alone).
    static func clusters(for parks: [Place], pointsPerMapPoint: Double?, spacing: CGSize) -> [ParkCluster] {
        guard let pointsPerMapPoint, pointsPerMapPoint > 0 else {
            return parks.map { ParkCluster(parks: [$0]) }
        }
        let reachX = spacing.width / pointsPerMapPoint
        let reachY = spacing.height / pointsPerMapPoint

        // Merge the closest overlapping pair until nothing overlaps. Merging
        // moves a group's center, so pairs are rechecked each round; with
        // 63 parks that's cheap. Ties go to the earlier pair, so results are
        // stable for a given order.
        var groups = parks.map { (points: [mapPoint(for: $0)], parks: [$0]) }
        while true {
            var closest: (first: Int, second: Int, distance: Double)?
            let centers = groups.map { center(of: $0.points) }
            for i in centers.indices {
                for j in centers.indices where j > i {
                    let dx = abs(centers[i].x - centers[j].x), dy = abs(centers[i].y - centers[j].y)
                    guard dx < reachX, dy < reachY else { continue }
                    let distance = hypot(dx / reachX, dy / reachY)
                    if distance < closest?.distance ?? .infinity {
                        closest = (i, j, distance)
                    }
                }
            }
            guard let closest else { break }
            let absorbed = groups.remove(at: closest.second)
            groups[closest.first].points += absorbed.points
            groups[closest.first].parks += absorbed.parks
        }
        return groups.map { ParkCluster(parks: $0.parks) }
    }

    static func mapPoint(for park: Place) -> MKMapPoint {
        MKMapPoint(park.labelCoordinate.clLocationCoordinate)
    }

    static func center(of points: [MKMapPoint]) -> MKMapPoint {
        MKMapPoint(
            x: points.map(\.x).reduce(0, +) / Double(points.count),
            y: points.map(\.y).reduce(0, +) / Double(points.count)
        )
    }
}
