import Foundation
import Testing
@testable import expedition

@MainActor
struct DuplicateMergerTests {
    let yosemite = PlaceID(category: .park, code: "yosemite")
    let early = Date(timeIntervalSince1970: 1_000)
    let late = Date(timeIntervalSince1970: 2_000)

    private func makeEntry(
        _ id: PlaceID? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        visited: Bool = false,
        notes: String = "",
        favorites: [FavoriteItem] = [],
        memories: [Memory] = [],
        visitDates: [Date] = []
    ) -> PlaceEntry {
        let entry = PlaceEntry(placeID: id ?? yosemite, createdAt: createdAt ?? early)
        entry.updatedAt = updatedAt ?? entry.createdAt
        entry.isVisited = visited
        entry.notes = notes
        entry.favorites = favorites
        entry.memories = memories
        entry.visitDates = visitDates
        return entry
    }

    // MARK: Survivor

    @Test func oldestEntrySurvives() {
        let older = makeEntry(createdAt: early)
        let newer = makeEntry(createdAt: late)

        let (survivor, duplicates) = DuplicateMerger.merge([newer, older])

        #expect(survivor === older)
        #expect(duplicates.count == 1 && duplicates[0] === newer)
    }

    @Test func survivorTieBreakIsIndependentOfInputOrder() {
        let a = makeEntry(createdAt: early)
        let b = makeEntry(createdAt: early)

        let first = DuplicateMerger.merge([a, b]).survivor
        let second = DuplicateMerger.merge([b, a]).survivor

        #expect(first === second)
    }

    // MARK: Fields

    @Test func visitedIfAnyCopyIsVisited() {
        let survivor = DuplicateMerger.merge([
            makeEntry(createdAt: early, visited: false),
            makeEntry(createdAt: late, visited: true),
        ]).survivor

        #expect(survivor.isVisited)
    }

    @Test func distinctNotesAreKeptAndRepeatsAreNot() {
        let survivor = DuplicateMerger.merge([
            makeEntry(createdAt: early, notes: "Sunrise at Tunnel View"),
            makeEntry(createdAt: late, notes: "Camped at Upper Pines"),
            makeEntry(createdAt: late, notes: "  Sunrise at Tunnel View\n"),
            makeEntry(createdAt: late, notes: ""),
        ]).survivor

        #expect(survivor.notes == "Sunrise at Tunnel View\n\nCamped at Upper Pines")
    }

    @Test func favoritesUnionByIDAndName() {
        let shared = FavoriteItem(name: "Half Dome")
        let url = URL(string: "https://www.alltrails.com/trail/us/california/mist-trail")!
        let survivor = DuplicateMerger.merge([
            makeEntry(createdAt: early, favorites: [shared, FavoriteItem(name: "Mist Trail")]),
            makeEntry(createdAt: late, favorites: [shared, FavoriteItem(name: "mist trail ", url: url),
                                                   FavoriteItem(name: "Clouds Rest")]),
        ]).survivor

        #expect(survivor.favorites.map(\.name) == ["Half Dome", "Mist Trail", "Clouds Rest"])
        #expect(survivor.favorites[1].url == url)
    }

    @Test func favoriteNamesMatchIgnoringAccents() {
        let survivor = DuplicateMerger.merge([
            makeEntry(PlaceID(category: .country, code: "CO"), createdAt: early,
                      favorites: [FavoriteItem(name: "Bogotá")]),
            makeEntry(PlaceID(category: .country, code: "CO"), createdAt: late,
                      favorites: [FavoriteItem(name: "Bogota")]),
        ]).survivor

        #expect(survivor.favorites.map(\.name) == ["Bogotá"])
    }

    @Test func memoriesUnionByIDAndText() {
        let shared = Memory(text: "Saw a bear")
        let survivor = DuplicateMerger.merge([
            makeEntry(createdAt: early, memories: [shared]),
            makeEntry(createdAt: late, memories: [shared, Memory(text: "saw a bear"), Memory(text: "First snow")]),
        ]).survivor

        #expect(survivor.memories.map(\.text) == ["Saw a bear", "First snow"])
    }

    @Test func datesAreCombined() {
        let survivor = DuplicateMerger.merge([
            makeEntry(createdAt: early, updatedAt: early, visitDates: [late]),
            makeEntry(createdAt: late, updatedAt: late.addingTimeInterval(500), visitDates: [early, late]),
        ]).survivor

        #expect(survivor.visitDates == [early, late])
        #expect(survivor.createdAt == early)
        #expect(survivor.updatedAt == late.addingTimeInterval(500))
    }

    // MARK: Determinism

    @Test func mergedContentIsIndependentOfInputOrder() {
        func group() -> [PlaceEntry] {
            [
                makeEntry(createdAt: early, notes: "A", favorites: [FavoriteItem(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "Mist Trail")]),
                makeEntry(createdAt: late, visited: true, notes: "B", favorites: [FavoriteItem(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, name: "Half Dome")]),
            ]
        }

        let forward = DuplicateMerger.merge(group()).survivor
        let reversed = DuplicateMerger.merge(group().reversed()).survivor

        #expect(forward.isVisited == reversed.isVisited)
        #expect(forward.notes == reversed.notes)
        #expect(forward.favorites == reversed.favorites)
    }

    @Test func mergingAgainChangesNothing() {
        let entries = [
            makeEntry(createdAt: early, notes: "A", favorites: [FavoriteItem(name: "Mist Trail")]),
            makeEntry(createdAt: late, visited: true, notes: "B"),
        ]
        let survivor = DuplicateMerger.merge(entries).survivor
        let notes = survivor.notes
        let favorites = survivor.favorites

        let duplicates = DuplicateMerger.mergeAll([survivor])

        #expect(duplicates.isEmpty)
        #expect(survivor.notes == notes)
        #expect(survivor.favorites == favorites)
    }

    // MARK: mergeAll

    @Test func mergeAllOnlyTouchesDuplicateGroups() {
        let single = makeEntry(PlaceID(category: .park, code: "zion"), notes: "Narrows")
        let stateCA = makeEntry(PlaceID(category: .state, code: "CA"))
        let countryCA = makeEntry(PlaceID(category: .country, code: "CA"))
        let dupA = makeEntry(createdAt: early)
        let dupB = makeEntry(createdAt: late)

        let duplicates = DuplicateMerger.mergeAll([single, stateCA, countryCA, dupA, dupB])

        #expect(duplicates.count == 1 && duplicates[0] === dupB)
        #expect(single.notes == "Narrows")
    }
}
