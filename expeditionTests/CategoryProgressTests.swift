import Testing
@testable import expedition

struct CategoryProgressTests {
    private static func place(_ category: PlaceCategory, _ code: String, counts: Bool = true) -> Place {
        Place(
            id: PlaceID(category: category, code: code),
            name: code,
            labelCoordinate: Coordinate(latitude: 0, longitude: 0),
            boundary: nil,
            stateCodes: [],
            countsTowardTotal: counts
        )
    }

    let countries: [Place]

    init() {
        countries = [
            Self.place(.country, "JP"),
            Self.place(.country, "FR"),
            Self.place(.country, "PE"),
            Self.place(.country, "GL", counts: false),
        ]
    }

    @Test func countsVisitedOutOfTotal() {
        let progress = CategoryProgress(category: .country, places: countries, visitedCodes: ["JP", "FR"])

        #expect(progress.visited == 2)
        #expect(progress.total == 3)
        #expect(progress.fraction == 2.0 / 3.0)
    }

    @Test func extrasAndUnknownCodesDontCount() {
        let progress = CategoryProgress(category: .country, places: countries, visitedCodes: ["JP", "GL", "ZZ"])

        #expect(progress.visited == 1)
        #expect(progress.total == 3)
    }

    @Test func nothingVisitedIsZero() {
        let progress = CategoryProgress(category: .country, places: countries, visitedCodes: [])

        #expect(progress.visited == 0)
        #expect(progress.fraction == 0)
    }

    @Test func emptyCategoryHasZeroFraction() {
        let progress = CategoryProgress(category: .park, places: [], visitedCodes: ["zion"])

        #expect(progress.total == 0)
        #expect(progress.fraction == 0)
    }

    @Test func onlyCountsPlacesInTheCategory() {
        let places = countries + [Self.place(.state, "CA")]
        let progress = CategoryProgress(category: .state, places: places, visitedCodes: ["CA"])

        #expect(progress.visited == 1)
        #expect(progress.total == 1)
    }

    @Test func realParksTotalIs63() throws {
        let parks = try ReferenceDataLoader.loadParks()
        let progress = CategoryProgress(category: .park, places: parks, visitedCodes: ["zion", "yosemite"])

        #expect(progress.total == 63)
        #expect(progress.visited == 2)
    }
}
