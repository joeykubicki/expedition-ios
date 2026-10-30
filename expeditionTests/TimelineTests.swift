import Foundation
import SwiftData
import Testing
@testable import expedition

@MainActor
struct TimelineTests {
    let container: ModelContainer
    let store: PlaceEntryStore
    let referenceData = PreviewSupport.referenceData()

    init() throws {
        container = try ModelContainerFactory.make(inMemory: true)
        store = PlaceEntryStore(context: container.mainContext)
    }

    private func record(_ category: PlaceCategory, _ code: String, visited: Bool = true, _ visits: [Visit]) throws {
        let entry = try store.entryOrCreate(for: PlaceID(category: category, code: code))
        entry.isVisited = visited
        entry.visits = visits
    }

    private func timeline(_ category: PlaceCategory? = nil, showsReturnVisits: Bool = true) throws -> Timeline {
        Timeline(
            entries: try container.mainContext.fetch(FetchDescriptor<PlaceEntry>()),
            category: category,
            showsReturnVisits: showsReturnVisits,
            place: referenceData.place(for:)
        )
    }

    private func day(_ year: Int, _ month: Int, _ day: Int) -> VisitDate {
        VisitDate(year: year, month: month, day: day)
    }

    /// Place names per trip, newest trip first.
    private func trips(_ category: PlaceCategory? = nil) throws -> [[String]] {
        try timeline(category).years.flatMap(\.trips).map { $0.items.map(\.place.name) }
    }

    @Test func groupsByStartYearNewestFirst() throws {
        try record(.park, "zion", [
            Visit(start: VisitDate(year: 2023, month: 10, day: 12)),
            Visit(start: VisitDate(year: 2016)),
        ])
        try record(.country, "JP", [Visit(start: VisitDate(year: 2023, month: 4))])
        try record(.state, "UT", [Visit(start: VisitDate(year: 2023))])
        // A New Year's trip belongs to the year it started.
        try record(.country, "IS", [Visit(start: VisitDate(year: 2016, month: 12, day: 30), end: VisitDate(year: 2017, month: 1, day: 2))])

        let timeline = try timeline()

        #expect(timeline.years.map(\.year) == [2023, 2016])
        #expect(timeline.years[0].items.map(\.place.name) == ["Zion", "Japan", "Utah"], "Year-only visits come last")
        #expect(timeline.years[1].items.map(\.place.name) == ["Iceland", "Zion"])
    }

    @Test func countsDistinctPlacesPerYear() throws {
        try record(.park, "zion", [
            Visit(start: VisitDate(year: 2023, month: 3)),
            Visit(start: VisitDate(year: 2023, month: 10)),
        ])
        try record(.park, "arches", [Visit(start: VisitDate(year: 2023, month: 10))])

        let year = try #require(try timeline().years.first)
        #expect(year.items.count == 3)
        #expect(year.placeCount == 2)
    }

    @Test func undatedVisitedPlacesAreListedByName() throws {
        try record(.country, "PE", [])
        try record(.park, "arches", [])
        try record(.park, "zion", [Visit(start: VisitDate(year: 2020))])

        #expect(try timeline().undated.map(\.name) == ["Arches", "Peru"])
    }

    @Test func unvisitedPlacesAreHiddenEvenWithVisits() throws {
        try record(.park, "zion", visited: false, [Visit(start: VisitDate(year: 2020))])
        try record(.park, "arches", visited: false, [])

        #expect(try timeline().isEmpty)
    }

    @Test func filtersByCategory() throws {
        try record(.park, "zion", [Visit(start: VisitDate(year: 2020))])
        try record(.country, "JP", [Visit(start: VisitDate(year: 2021))])
        try record(.country, "PE", [])

        let countries = try timeline(.country)
        #expect(countries.years.flatMap(\.items).map(\.place.name) == ["Japan"])
        #expect(countries.undated.map(\.name) == ["Peru"])
        #expect(try timeline(.state).isEmpty)
    }

    // MARK: Trips

    @Test func overlappingVisitsAreOneTripInOrder() throws {
        try record(.park, "bryce-canyon", [Visit(start: day(2023, 10, 15), end: day(2023, 10, 17))])
        try record(.park, "zion", [Visit(start: day(2023, 10, 12), end: day(2023, 10, 15))])

        #expect(try trips() == [["Zion", "Bryce Canyon"]], "Sharing a day counts; oldest first within the trip")
        let span = try #require(try timeline().years.first?.trips.first?.span)
        #expect(span.start == day(2023, 10, 12) && span.end == day(2023, 10, 17))
    }

    @Test func backToBackDaysAreSeparateTrips() throws {
        try record(.park, "zion", [Visit(start: day(2023, 10, 12), end: day(2023, 10, 15))])
        try record(.park, "bryce-canyon", [Visit(start: day(2023, 10, 16))])

        #expect(try trips() == [["Bryce Canyon"], ["Zion"]])
    }

    @Test func tripsFollowChains() throws {
        try record(.park, "zion", [Visit(start: day(2023, 10, 1), end: day(2023, 10, 3))])
        try record(.park, "bryce-canyon", [Visit(start: day(2023, 10, 3), end: day(2023, 10, 6))])
        try record(.park, "arches", [Visit(start: day(2023, 10, 6))])

        #expect(try trips() == [["Zion", "Bryce Canyon", "Arches"]], "Zion and Arches don't overlap, but Bryce joins them")
    }

    @Test func aMonthOverlapsTheDaysInIt() throws {
        try record(.state, "UT", [Visit(start: VisitDate(year: 2023, month: 10))])
        try record(.park, "zion", [Visit(start: day(2023, 10, 12), end: day(2023, 10, 15))])

        let trip = try #require(try timeline().years.first?.trips.first)
        #expect(trip.items.map(\.place.name) == ["Utah", "Zion"])
        #expect(trip.span == Visit(id: trip.span.id, start: VisitDate(year: 2023, month: 10)), "Shown at the coarsest precision")
    }

    @Test func yearOnlyVisitsNeverGroup() throws {
        try record(.state, "AZ", [Visit(start: VisitDate(year: 2019))])
        try record(.park, "grand-canyon", [Visit(start: VisitDate(year: 2019))])
        try record(.country, "FR", [Visit(start: VisitDate(year: 2019, month: 5))])

        #expect(try trips().map(\.count) == [1, 1, 1])
    }

    @Test func tripsOnlyGroupWhatTheFilterShows() throws {
        try record(.state, "UT", [Visit(start: VisitDate(year: 2023, month: 10))])
        try record(.park, "zion", [Visit(start: day(2023, 10, 12))])

        #expect(try trips() == [["Utah", "Zion"]])
        #expect(try trips(.park) == [["Zion"]])
    }

    // MARK: First and return visits

    @Test func laterVisitsAreReturns() throws {
        try record(.park, "zion", [
            Visit(start: day(2023, 10, 12)),
            Visit(start: VisitDate(year: 2016)),
            Visit(start: VisitDate(year: 2019, month: 6)),
        ])

        let items = try timeline().years.flatMap(\.items)
        #expect(items.map(\.visit.start.year) == [2023, 2019, 2016])
        #expect(items.map(\.isReturn) == [true, true, false])
    }

    @Test func sameDayVisitsStillHaveOneFirst() throws {
        try record(.park, "zion", [Visit(start: day(2023, 10, 12)), Visit(start: day(2023, 10, 12))])

        #expect(try timeline().years.flatMap(\.items).count { !$0.isReturn } == 1)
    }

    @Test func hidingReturnsLeavesFirstVisits() throws {
        try record(.park, "zion", [Visit(start: day(2023, 10, 12)), Visit(start: VisitDate(year: 2016))])
        try record(.park, "arches", [Visit(start: day(2023, 10, 14))])

        let firsts = try timeline(showsReturnVisits: false)
        #expect(firsts.years.map(\.year) == [2023, 2016])
        #expect(firsts.years[0].items.map(\.place.name) == ["Arches"])
    }

    // MARK: Year stats

    @Test func yearsCountNewPlacesAndCountries() throws {
        try record(.park, "zion", [Visit(start: day(2023, 10, 12)), Visit(start: VisitDate(year: 2016))])
        try record(.park, "arches", [Visit(start: day(2023, 10, 14))])
        try record(.country, "JP", [Visit(start: VisitDate(year: 2023, month: 4))])
        try record(.country, "FR", [Visit(start: VisitDate(year: 2023, month: 5)), Visit(start: VisitDate(year: 2023, month: 8))])

        let years = try timeline().years
        let year2023 = try #require(years.first)
        #expect(year2023.placeCount == 4)
        #expect(year2023.newPlaceCount == 3, "Zion was new in 2016")
        #expect(year2023.countryCount == 2)
        #expect(years.last?.newPlaceCount == 1)
    }

    @Test func sampleZionTripIncludesUtah() throws {
        let sample = PreviewSupport.container()
        let timeline = Timeline(
            entries: try sample.mainContext.fetch(FetchDescriptor<PlaceEntry>()),
            category: nil,
            place: referenceData.place(for:)
        )
        let trips = timeline.years.flatMap(\.trips).filter { !$0.isSingle }
        #expect(trips.map { $0.items.map(\.place.name) } == [["Utah", "Zion"]])
    }

    @Test func sampleDataHasDatedAndUndatedPlaces() throws {
        let sample = PreviewSupport.container()
        let timeline = Timeline(
            entries: try sample.mainContext.fetch(FetchDescriptor<PlaceEntry>()),
            category: nil,
            place: referenceData.place(for:)
        )
        #expect(timeline.years.count >= 4)
        #expect(!timeline.undated.isEmpty)
    }
}

@MainActor
struct MemoriesEditorVisitTests {
    let container: ModelContainer
    let store: PlaceEntryStore
    let zion = PlaceID(category: .park, code: "zion")

    init() throws {
        container = try ModelContainerFactory.make(inMemory: true)
        store = PlaceEntryStore(context: container.mainContext)
    }

    @Test func addingAVisitMarksThePlaceVisitedOnce() {
        let editor = MemoriesEditor(placeID: zion, store: store)

        #expect(editor.addVisit(Visit(start: VisitDate(year: 2016))))
        #expect(editor.isVisited)
        #expect(!editor.addVisit(Visit(start: VisitDate(year: 2023))), "Already visited")
        #expect(editor.visits.map(\.start.year) == [2023, 2016])
    }

    @Test func unmarkingKeepsVisits() {
        let editor = MemoriesEditor(placeID: zion, store: store)
        editor.addVisit(Visit(start: VisitDate(year: 2016)))
        editor.toggleVisited()

        #expect(!editor.isVisited)
        #expect(editor.visits.count == 1)
    }

    @Test func updatesAndRemovesVisits() {
        let editor = MemoriesEditor(placeID: zion, store: store)
        let visit = Visit(start: VisitDate(year: 2016))
        editor.addVisit(visit)

        editor.updateVisit(Visit(id: visit.id, start: VisitDate(year: 2017, month: 5)))
        #expect(editor.visits.map(\.start) == [VisitDate(year: 2017, month: 5)])

        editor.removeVisit(id: visit.id)
        #expect(editor.visits.isEmpty)
    }
}
