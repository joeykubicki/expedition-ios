import Foundation

/// Decodes the GeoJSON written by `tools/build-reference-data.py`: a
/// FeatureCollection whose geometries are all MultiPolygons.
nonisolated struct GeoJSONFeatureCollection<Properties: Decodable & Sendable>: Decodable, Sendable {
    let features: [Feature]

    struct Feature: Decodable, Sendable {
        let properties: Properties
        let geometry: MultiPolygon
    }

    struct MultiPolygon: Decodable, Sendable {
        let polygons: [BoundaryPolygon]

        private enum CodingKeys: String, CodingKey {
            case type, coordinates
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)
            guard type == "MultiPolygon" else {
                throw DecodingError.dataCorruptedError(
                    forKey: .type, in: container,
                    debugDescription: "Expected MultiPolygon, got \(type)"
                )
            }
            // GeoJSON positions are [longitude, latitude].
            let positions = try container.decode([[[[Double]]]].self, forKey: .coordinates)
            polygons = positions.map { rings in
                let coordinates = rings.map { ring in
                    ring.map { Coordinate(latitude: $0[1], longitude: $0[0]) }
                }
                return BoundaryPolygon(exterior: coordinates.first ?? [], holes: Array(coordinates.dropFirst()))
            }
        }
    }
}
