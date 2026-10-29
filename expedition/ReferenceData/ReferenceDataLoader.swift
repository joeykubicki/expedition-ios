import Foundation

/// Loads the bundled parks, states, and countries. Pure and synchronous so it
/// can be tested directly; `ReferenceDataStore` calls it off the main actor.
nonisolated enum ReferenceDataLoader {
    enum LoadError: Error {
        case missingResource(String)
    }

    /// Countries whose name we show differently from `Locale`'s.
    static let countryNameOverrides = ["PS": "Palestine"]

    /// Territories that have national parks but aren't in the states list.
    static let territoryNames = ["AS": "American Samoa", "VI": "U.S. Virgin Islands"]

    static func loadParks(from bundle: Bundle = .main) throws -> [Place] {
        struct ParkRecord: Decodable {
            let id: String
            let name: String
            let states: [String]
            let latitude: Double
            let longitude: Double
        }

        let records = try JSONDecoder().decode([ParkRecord].self, from: data(named: "parks.json", in: bundle))
        return records.map { record in
            Place(
                id: PlaceID(category: .park, code: record.id),
                name: record.name,
                labelCoordinate: Coordinate(latitude: record.latitude, longitude: record.longitude),
                boundary: nil,
                stateCodes: record.states,
                countsTowardTotal: true
            )
        }
        .sortedByName()
    }

    static func loadStates(from bundle: Bundle = .main) throws -> [Place] {
        struct StateProperties: Decodable, Sendable {
            let id: String
            let name: String
            let labelLatitude: Double
            let labelLongitude: Double
        }

        let collection = try JSONDecoder().decode(
            GeoJSONFeatureCollection<StateProperties>.self,
            from: data(named: "states.geojson", in: bundle)
        )
        return collection.features.map { feature in
            let properties = feature.properties
            return Place(
                id: PlaceID(category: .state, code: properties.id),
                name: properties.name,
                labelCoordinate: Coordinate(latitude: properties.labelLatitude, longitude: properties.labelLongitude),
                boundary: feature.geometry.polygons,
                stateCodes: [],
                countsTowardTotal: true
            )
        }
        .sortedByName()
    }

    static func loadCountries(from bundle: Bundle = .main, locale: Locale = .current) throws -> [Place] {
        struct CountryProperties: Decodable, Sendable {
            let id: String
            let sovereign: Bool
            let labelLatitude: Double
            let labelLongitude: Double
        }

        let collection = try JSONDecoder().decode(
            GeoJSONFeatureCollection<CountryProperties>.self,
            from: data(named: "countries.geojson", in: bundle)
        )
        return collection.features.map { feature in
            let properties = feature.properties
            return Place(
                id: PlaceID(category: .country, code: properties.id),
                name: countryName(for: properties.id, locale: locale),
                labelCoordinate: Coordinate(latitude: properties.labelLatitude, longitude: properties.labelLongitude),
                boundary: feature.geometry.polygons,
                stateCodes: [],
                countsTowardTotal: properties.sovereign
            )
        }
        .sortedByName()
    }

    static func countryName(for code: String, locale: Locale = .current) -> String {
        countryNameOverrides[code] ?? locale.localizedString(forRegionCode: code) ?? code
    }

    private static func data(named fileName: String, in bundle: Bundle) throws -> Data {
        let name = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        guard let url = bundle.url(forResource: name, withExtension: ext) else {
            throw LoadError.missingResource(fileName)
        }
        return try Data(contentsOf: url)
    }
}

private extension Array where Element == Place {
    nonisolated func sortedByName() -> [Place] {
        sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
