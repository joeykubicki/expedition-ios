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

    private func timeline(_ category: PlaceCategory? = nil) throws -> Timeline {
        Timeline(
            entries: try container.mainContext.fetch(FetchDescriptor<PlaceEntry>()),
            category: category,
            place: referenceData.place(for:)
        )
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
