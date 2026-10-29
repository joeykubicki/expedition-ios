import Foundation
import SwiftData
import Testing
@testable import expedition

@MainActor
struct PlaceEntryStoreTests {
    let container: ModelContainer
    let store: PlaceEntryStore

    let zion = PlaceID(category: .park, code: "zion")
    let california = PlaceID(category: .state, code: "CA")
    let canada = PlaceID(category: .country, code: "CA")

    init() throws {
        container = try ModelContainerFactory.make(inMemory: true)
        store = PlaceEntryStore(context: container.mainContext)
    }

    private func allEntries() throws -> [PlaceEntry] {
        try container.mainContext.fetch(FetchDescriptor<PlaceEntry>())
    }

    @Test func entryIsNilBeforeAnythingIsRecorded() throws {
        #expect(try store.entry(for: zion) == nil)
    }

    @Test func entryOrCreateLooksUpBeforeCreating() throws {
        let first = try store.entryOrCreate(for: zion)
        let second = try store.entryOrCreate(for: zion)

        #expect(first === second)
        #expect(try allEntries().count == 1)
    }

    @Test func toggleVisitedFlipsStateAndUpdatesTimestamp() throws {
        let created = Date(timeIntervalSince1970: 1_000)
        let toggled = Date(timeIntervalSince1970: 2_000)
        store.now = { created }
        try store.entryOrCreate(for: zion)
        store.now = { toggled }

        #expect(try store.toggleVisited(for: zion) == true)
        #expect(try store.entry(for: zion)?.updatedAt == toggled)
        #expect(try store.toggleVisited(for: zion) == false)
        #expect(try store.entry(for: zion)?.isVisited == false)
    }

    @Test func settingSameVisitedStateLeavesTimestampAlone() throws {
        store.now = { Date(timeIntervalSince1970: 1_000) }
        try store.setVisited(true, for: zion)
        store.now = { Date(timeIntervalSince1970: 2_000) }
        try store.setVisited(true, for: zion)

        #expect(try store.entry(for: zion)?.updatedAt == Date(timeIntervalSince1970: 1_000))
    }

    @Test func sameCodeInDifferentCategoriesStaysSeparate() throws {
        try store.setVisited(true, for: california)

        #expect(try store.entry(for: canada) == nil)
        #expect(try store.visitedCodes(in: .state) == ["CA"])
        #expect(try store.visitedCodes(in: .country).isEmpty)
    }

    @Test func visitedCodesExcludesUnvisitedEntries() throws {
        try store.setVisited(true, for: zion)
        try store.entryOrCreate(for: PlaceID(category: .park, code: "arches"))

        #expect(try store.visitedCodes(in: .park) == ["zion"])
    }

    @Test func lookupMergesSyncedDuplicates() throws {
        let context = container.mainContext
        let older = PlaceEntry(placeID: zion, createdAt: Date(timeIntervalSince1970: 1_000))
        older.notes = "Angels Landing"
        let newer = PlaceEntry(placeID: zion, createdAt: Date(timeIntervalSince1970: 2_000))
        newer.isVisited = true
        context.insert(older)
        context.insert(newer)
        try context.save()

        let entry = try #require(try store.entry(for: zion))

        #expect(entry === older)
        #expect(entry.isVisited)
        #expect(entry.notes == "Angels Landing")
        #expect(try allEntries().count == 1)
    }

    @Test func mergeAllDuplicatesRemovesExtras() throws {
        let context = container.mainContext
        for _ in 0..<3 { context.insert(PlaceEntry(placeID: zion)) }
        context.insert(PlaceEntry(placeID: california))
        try context.save()

        #expect(try store.mergeAllDuplicates() == 2)
        #expect(try allEntries().count == 2)
        #expect(try store.mergeAllDuplicates() == 0)
    }
}
