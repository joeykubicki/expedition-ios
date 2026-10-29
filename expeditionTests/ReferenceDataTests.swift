import Foundation
import Testing
@testable import expedition

struct ReferenceDataTests {
    let parks = try! ReferenceDataLoader.loadParks()
    let states = try! ReferenceDataLoader.loadStates()
    let countries = try! ReferenceDataLoader.loadCountries(locale: Locale(identifier: "en_US"))

    // MARK: Counts

    @Test func loadsAll63Parks() {
        #expect(parks.count == 63)
    }

    @Test func loads50StatesWithoutDC() {
        #expect(states.count == 50)
        #expect(!states.contains { $0.id.code == "DC" })
    }

    @Test func loads197CountriesPlusExtras() {
        #expect(countries.count == 200)
        #expect(countries.filter(\.countsTowardTotal).count == 197)
        let extras = Set(countries.filter { !$0.countsTowardTotal }.map(\.id.code))
        #expect(extras == ["GL", "PR", "AQ"])
    }

    // MARK: Identifiers

    @Test(arguments: PlaceCategory.allCases)
    func idsAreUniqueWithinCategory(_ category: PlaceCategory) {
        let places = [parks, states, countries].flatMap { $0 }.filter { $0.category == category }
        #expect(Set(places.map(\.id)).count == places.count)
    }

    @Test func parkIDsAreKebabCaseSlugs() {
        let slug = /[a-z]+(-[a-z]+)*/
        for park in parks {
            #expect(park.id.code.wholeMatch(of: slug) != nil, "\(park.id.code)")
        }
    }

    @Test func parkStateCodesAreKnown() {
        let known = Set(states.map(\.id.code)).union(["AS", "VI"])
        for park in parks {
            #expect(!park.stateCodes.isEmpty, "\(park.name)")
            #expect(Set(park.stateCodes).isSubset(of: known), "\(park.name): \(park.stateCodes)")
        }
    }

    // MARK: Names

    @Test func everyCountryHasALocalizedName() {
        for country in countries {
            #expect(country.name != country.id.code, "No name for \(country.id.code)")
        }
    }

    @Test func palestineUsesOverrideName() {
        #expect(ReferenceDataLoader.countryName(for: "PS", locale: Locale(identifier: "en_US")) == "Palestine")
    }

    @Test func placesAreSortedByName() {
        for places in [parks, states, countries] {
            let names = places.map(\.name)
            #expect(names == names.sorted { $0.localizedStandardCompare($1) == .orderedAscending })
        }
    }

    // MARK: Geometry

    @Test func coordinatesAreInRange() {
        for place in parks + states + countries {
            let points = [place.labelCoordinate]
                + (place.boundary ?? []).flatMap { [$0.exterior] + $0.holes }.flatMap { $0 }
            for point in points {
                #expect((-90...90).contains(point.latitude), "\(place.name)")
                #expect((-180...180).contains(point.longitude), "\(place.name)")
            }
        }
    }

    @Test func statesAndCountriesHaveClosedBoundaries() {
        for place in states + countries {
            let polygons = place.boundary ?? []
            #expect(!polygons.isEmpty, "\(place.name) has no boundary")
            for ring in polygons.flatMap({ [$0.exterior] + $0.holes }) {
                #expect(ring.count >= 4, "\(place.name)")
                #expect(ring.first == ring.last, "\(place.name) ring isn't closed")
            }
        }
    }

    @Test func parksHaveNoBoundary() {
        #expect(parks.allSatisfy { $0.boundary == nil })
    }
}

@MainActor
struct ReferenceDataStoreTests {
    @Test func loadIndexesPlacesByCategoryAndCode() async {
        let store = ReferenceDataStore()
        await store.load()

        #expect(store.isLoaded)
        #expect(store.loadError == nil)
        #expect(store.places(in: .park).count == 63)
        // "CA" is both California and Canada.
        #expect(store.place(for: PlaceID(category: .state, code: "CA"))?.name == "California")
        #expect(store.place(for: PlaceID(category: .country, code: "CA")) != nil)
        #expect(store.place(for: PlaceID(category: .park, code: "grand-canyon"))?.name == "Grand Canyon")
    }
}
