import MapKit
import SwiftUI

/// One polygon of a place's outline, ready for `MapPolygon`. Built once per
/// map appearance; the reference data itself stays MapKit-free.
struct MapShape: Identifiable {
    let id: String
    let placeID: PlaceID
    let polygon: MKPolygon
    /// Outline to draw instead of stroking `polygon`, for the few shapes cut
    /// at the antimeridian (see `AntimeridianSeams`); `nil` otherwise.
    let seamlessOutline: [MKPolyline]?

    static func shapes(for places: [Place]) -> [MapShape] {
        places.flatMap { place in
            (place.boundary ?? []).enumerated().map { index, part in
                let exterior = part.exterior.map(\.clLocationCoordinate)
                let holes = part.holes.map { hole in
                    let coordinates = hole.map(\.clLocationCoordinate)
                    return MKPolygon(coordinates: coordinates, count: coordinates.count)
                }
                return MapShape(
                    id: "\(place.id.category.rawValue)-\(place.id.code)-\(index)",
                    placeID: place.id,
                    polygon: MKPolygon(coordinates: exterior, count: exterior.count, interiorPolygons: holes),
                    seamlessOutline: seamlessOutline(for: part)
                )
            }
        }
    }

    private static func seamlessOutline(for part: BoundaryPolygon) -> [MKPolyline]? {
        let rings = [part.exterior] + part.holes
        let runs = rings.map(AntimeridianSeams.outlineRuns)
        guard runs.contains(where: { $0 != nil }) else { return nil }
        return zip(rings, runs).flatMap { ring, ringRuns in
            (ringRuns ?? [ring]).map { run in
                let coordinates = run.map(\.clLocationCoordinate)
                return MKPolyline(coordinates: coordinates, count: coordinates.count)
            }
        }
    }
}

extension PlaceCategory {
    /// Lower 48 for parks and states (Alaska and Hawaii are a pan away);
    /// the whole world for countries.
    var initialCameraPosition: MapCameraPosition {
        switch self {
        case .park, .state:
            .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 39.0, longitude: -96.5),
                span: MKCoordinateSpan(latitudeDelta: 30, longitudeDelta: 62)
            ))
        case .country:
            .rect(.world)
        }
    }
}
