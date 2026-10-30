import Foundation
import Testing
@testable import expedition

struct PlaceHitTesterTests {
    let countries = try! ReferenceDataLoader.loadCountries(locale: Locale(identifier: "en_US"))
    let states = try! ReferenceDataLoader.loadStates()

    private func country(at latitude: Double, _ longitude: Double) -> String? {
        PlaceHitTester.place(at: Coordinate(latitude: latitude, longitude: longitude), in: countries)?.id.code
    }

    private func state(at latitude: Double, _ longitude: Double) -> String? {
        PlaceHitTester.place(at: Coordinate(latitude: latitude, longitude: longitude), in: states)?.id.code
    }

    @Test func findsCountriesInland() {
        #expect(country(at: 48.86, 2.35) == "FR")    // Paris
        #expect(country(at: 35.68, 139.69) == "JP")  // Tokyo
        #expect(country(at: -13.53, -71.97) == "PE") // Cusco
    }

    @Test func enclaveWinsOverSurroundingCountry() {
        #expect(country(at: -29.31, 27.48) == "LS")  // Maseru, Lesotho
        #expect(country(at: -26.20, 28.05) == "ZA")  // Johannesburg
    }

    @Test func tinyCountryInsideLargerOneWins() {
        #expect(country(at: 41.89, 12.48) == "IT")   // Rome
        #expect(country(at: 43.94, 12.45) == "SM")   // San Marino
    }

    @Test func mergedAreasBelongToTheirRecognizedCountry() {
        #expect(country(at: 9.56, 44.06) == "SO")    // Hargeisa (Somaliland)
        #expect(country(at: 35.25, 33.60) == "CY")   // northern Cyprus
        #expect(country(at: 34.77, 32.90) == "CY")   // southern Cyprus
    }

    /// Natural Earth's default data is de facto: Morocco's outline includes the
    /// part of Western Sahara it administers; the rest is its own unassigned feature.
    @Test func westernSaharaFollowsNaturalEarthDeFactoBorders() {
        #expect(country(at: 26.0, -14.5) == "MA")
        #expect(country(at: 21.5, -14.5) == nil)
    }

    @Test func openOceanIsNothing() {
        #expect(country(at: 30, -40) == nil)         // mid-Atlantic
        #expect(country(at: -40, -120) == nil)       // South Pacific
    }

    @Test func worksOnBothSidesOfTheAntimeridian() {
        #expect(country(at: -17.8, 178.0) == "FJ")   // Viti Levu, west of 180°
        #expect(country(at: -16.8, -179.9) == "FJ")  // Taveuni, east of 180°
        #expect(country(at: 67.0, 175.0) == "RU")    // inland Chukotka
    }

    @Test func wrappedLongitudesAreNormalized() {
        #expect(country(at: 48.86, 2.35 + 360) == "FR")
        #expect(country(at: 35.68, 139.69 - 360) == "JP")
    }

    @Test func extrasAreHittable() {
        #expect(country(at: 72, -40) == "GL")        // Greenland ice sheet
        #expect(country(at: 18.4, -66.1) == "PR")    // San Juan
    }

    @Test func findsStatesIncludingAlaskaAndHawaii() {
        #expect(state(at: 39.74, -104.99) == "CO")   // Denver
        #expect(state(at: 61.22, -149.90) == "AK")   // Anchorage
        #expect(state(at: 19.6, -155.5) == "HI")     // Big Island
        #expect(state(at: 38.9, -77.03) == nil)      // Washington, DC (excluded)
    }

    @Test func parksHaveNoOutlineToHit() throws {
        let parks = try ReferenceDataLoader.loadParks()
        #expect(PlaceHitTester.place(at: Coordinate(latitude: 37.3, longitude: -113.05), in: parks) == nil)
    }

    @Test func holesAreExcluded() {
        let square = [(0.0, 0.0), (0, 10), (10, 10), (10, 0), (0, 0)].map { Coordinate(latitude: $0.0, longitude: $0.1) }
        let hole = [(4.0, 4.0), (4, 6), (6, 6), (6, 4), (4, 4)].map { Coordinate(latitude: $0.0, longitude: $0.1) }
        let polygon = BoundaryPolygon(exterior: square, holes: [hole])

        #expect(PlaceHitTester.contains(polygon, Coordinate(latitude: 2, longitude: 2)))
        #expect(!PlaceHitTester.contains(polygon, Coordinate(latitude: 5, longitude: 5)))
        #expect(!PlaceHitTester.contains(polygon, Coordinate(latitude: 11, longitude: 5)))
    }
}
