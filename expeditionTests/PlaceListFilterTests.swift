import Foundation
import Testing
@testable import expedition

struct PlaceListFilterTests {
    let parks = try! ReferenceDataLoader.loadParks()
    let states = try! ReferenceDataLoader.loadStates()
    let countries = try! ReferenceDataLoader.loadCountries(locale: .init(identifier: "en_US"))
    let stateNames: [String: String]

    init() {
        stateNames = ReferenceDataLoader.territoryNames.merging(
            states.map { ($0.id.code, $0.name) }, uniquingKeysWith: { _, state in state }
        )
    }

    private func codes(
        _ places: [Place],
        search: String = "",
        filter: VisitFilter = .all,
        visited: Set<String> = []
    ) -> [String] {
        PlaceListFilter.filter(
            places, searchText: search, visitFilter: filter, visitedCodes: visited, stateNames: stateNames
        ).map(\.id.code)
    }

    // MARK: Search

    @Test func emptySearchReturnsEverything() {
        #expect(codes(parks).count == 63)
        #expect(codes(parks, search: "   ").count == 63)
    }

    @Test func searchIgnoresCaseAndAccents() {
        #expect(codes(countries, search: "cote") == ["CI"])
        #expect(codes(countries, search: "SÃO TOMÉ") == ["ST"])
    }

    @Test func parksMatchByStateName() {
        #expect(Set(codes(parks, search: "utah"))
            == ["arches", "bryce-canyon", "canyonlands", "capitol-reef", "zion"])
    }

    @Test func parksMatchMultiStateAndTerritoryNames() {
        #expect(codes(parks, search: "nevada").contains("death-valley"))
        #expect(codes(parks, search: "virgin islands") == ["virgin-islands"])
    }

    @Test func statesAndCountriesMatchByExactCode() {
        // Codes that don't appear inside any name, so only the code can match.
        #expect(codes(states, search: "tx") == ["TX"])
        #expect(codes(countries, search: "jp") == ["JP"])
    }

    @Test func parksDontMatchBySlug() {
        #expect(codes(parks, search: "grand-canyon").isEmpty)
    }

    // MARK: Visit filter

    @Test func visitedFilterKeepsOnlyVisited() {
        #expect(codes(states, filter: .visited, visited: ["UT", "CA"]) == ["CA", "UT"])
    }

    @Test func notVisitedFilterExcludesVisited() {
        let result = codes(states, filter: .notVisited, visited: ["UT", "CA"])
        #expect(result.count == 48)
        #expect(!result.contains("UT"))
    }

    @Test func searchAndFilterCombine() {
        #expect(codes(parks, search: "utah", filter: .visited, visited: ["zion", "yosemite"]) == ["zion"])
    }

    @Test func extrasAppearInCountryList() {
        #expect(Set(codes(countries, search: "green")) == ["GL"])
        #expect(codes(countries).count == 200)
    }

    // MARK: Sections

    @Test func sectionsGroupByFoldedInitialInOrder() {
        let sections = PlaceListFilter.sectionedByInitial(countries)
        let initials = sections.map(\.initial)

        #expect(initials.first == "A")
        #expect(Set(initials).count == initials.count, "Each letter should appear once: \(initials)")
        #expect(sections.flatMap(\.places).count == countries.count)
        #expect(sections.first { $0.initial == "C" }?.places.contains { $0.id.code == "CI" } == true)
    }

    // MARK: State summaries and flags

    @MainActor
    @Test func stateSummaryNamesStatesAndTerritories() throws {
        let store = ReferenceDataStore()
        try store.loadSynchronously()

        let deathValley = try #require(store.place(for: PlaceID(category: .park, code: "death-valley")))
        let samoa = try #require(store.place(for: PlaceID(category: .park, code: "american-samoa")))
        let japan = try #require(store.place(for: PlaceID(category: .country, code: "JP")))

        #expect(store.stateSummary(for: deathValley) == "California · Nevada")
        #expect(store.stateSummary(for: samoa) == "American Samoa")
        #expect(store.stateSummary(for: japan) == nil)
    }

    @Test func flagEmojiFromRegionCode() {
        #expect(FlagEmoji.forRegionCode("JP") == "🇯🇵")
        #expect(FlagEmoji.forRegionCode("xk") == "🇽🇰")
        #expect(FlagEmoji.forRegionCode("USA") == nil)
        #expect(FlagEmoji.forRegionCode("1A") == nil)
    }
}
