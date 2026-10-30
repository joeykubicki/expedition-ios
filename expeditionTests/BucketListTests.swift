import Foundation
import SwiftData
import Testing
@testable import expedition

@MainActor
struct BucketListRulesTests {
    let container: ModelContainer
    let store: PlaceEntryStore
    let zion = PlaceID(category: .park, code: "zion")
    let added = Date(timeIntervalSince1970: 1_000)

    init() throws {
        container = try ModelContainerFactory.make(inMemory: true)
        store = PlaceEntryStore(context: container.mainContext)
        store.now = { [added] in added }
    }

    @Test func addingRecordsWhen() throws {
        try store.setOnBucketList(true, for: zion)

        let entry = try #require(try store.entry(for: zion))
        #expect(entry.wantsToVisit)
        #expect(entry.bucketListAddedAt == added)
        #expect(try store.bucketListCodes(in: .park) == ["zion"])
    }

    @Test func visitingTakesAPlaceOffAndUnvisitingDoesntPutItBack() throws {
        try store.setOnBucketList(true, for: zion)

        try store.setVisited(true, for: zion)
        let entry = try #require(try store.entry(for: zion))
        #expect(!entry.isOnBucketList)
        #expect(entry.bucketListAddedAt == nil)

        try store.setVisited(false, for: zion)
        #expect(!entry.isOnBucketList)
        #expect(try store.bucketListCodes(in: .park).isEmpty)
    }

    @Test func visitedPlacesCantBeAdded() throws {
        try store.setVisited(true, for: zion)
        try store.setOnBucketList(true, for: zion)

        #expect(try store.entry(for: zion)?.isOnBucketList == false)
    }

    @Test func removingAnUntouchedPlaceCreatesNothing() throws {
        try store.setOnBucketList(false, for: zion)
        #expect(try store.entry(for: zion) == nil)
    }

    /// If sync ever leaves both flags set, visited wins.
    @Test func visitedWinsOverAStaleFlag() throws {
        let entry = try store.entryOrCreate(for: zion)
        entry.isVisited = true
        entry.isOnBucketList = true

        #expect(!entry.wantsToVisit)
        #expect(try store.bucketListCodes(in: .park).isEmpty)
    }

    @Test func editorTogglesAndAddingAVisitChecksOff() {
        let editor = MemoriesEditor(placeID: zion, store: store)

        editor.toggleBucketList()
        #expect(editor.isOnBucketList)
        editor.toggleBucketList()
        #expect(!editor.isOnBucketList)

        editor.toggleBucketList()
        editor.addVisit(Visit(start: VisitDate(year: 2026)))
        #expect(editor.isVisited)
        #expect(!editor.isOnBucketList)

        editor.toggleBucketList()
        #expect(!editor.isOnBucketList, "Visited places can't be added")
    }

    @Test func listFilterShowsOnlyBucketListPlaces() {
        let referenceData = PreviewSupport.referenceData()
        let places = PlaceListFilter.filter(
            referenceData.parks,
            searchText: "",
            visitFilter: .bucketList,
            visitedCodes: ["zion"],
            bucketListCodes: ["glacier", "denali"],
            stateNames: referenceData.stateNames
        )
        #expect(places.map(\.id.code) == ["denali", "glacier"])
    }
}

@MainActor
struct BucketListTests {
    let container: ModelContainer
    let store: PlaceEntryStore
    let referenceData = PreviewSupport.referenceData()

    init() throws {
        container = try ModelContainerFactory.make(inMemory: true)
        store = PlaceEntryStore(context: container.mainContext)
    }

    private func add(_ category: PlaceCategory, _ code: String, daysAgo: Double) throws {
        try store.entryOrCreate(for: PlaceID(category: category, code: code))
            .setOnBucketList(true, at: Date(timeIntervalSince1970: 1_000_000 - daysAgo * 86_400))
    }

    private func bucketList(_ category: PlaceCategory? = nil) throws -> BucketList {
        BucketList(
            entries: try container.mainContext.fetch(FetchDescriptor<PlaceEntry>()),
            category: category,
            place: referenceData.place(for:)
        )
    }

    @Test func groupsByCategoryNewestFirst() throws {
        try add(.country, "IT", daysAgo: 10)
        try add(.park, "denali", daysAgo: 40)
        try add(.park, "glacier", daysAgo: 3)
        try add(.state, "MT", daysAgo: 5)

        let list = try bucketList()

        #expect(list.groups.map(\.category) == [.park, .state, .country])
        #expect(list.groups[0].items.map(\.place.name) == ["Glacier", "Denali"])
    }

    @Test func leavesOutVisitedAndUnknownPlaces() throws {
        try add(.park, "glacier", daysAgo: 1)
        try add(.park, "not-a-park", daysAgo: 1)
        let stale = try store.entryOrCreate(for: PlaceID(category: .park, code: "zion"))
        stale.isVisited = true
        stale.isOnBucketList = true

        #expect(try bucketList().groups.flatMap(\.items).map(\.place.name) == ["Glacier"])
    }

    @Test func filtersByCategory() throws {
        try add(.park, "glacier", daysAgo: 1)
        try add(.country, "IT", daysAgo: 1)

        #expect(try bucketList(.country).groups.map(\.category) == [.country])
        #expect(try bucketList(.state).isEmpty)
    }

    @Test func unmergedDuplicatesAppearOnce() throws {
        let id = PlaceID(category: .park, code: "glacier")
        for daysAgo in [1.0, 9.0] {
            let copy = PlaceEntry(placeID: id)
            container.mainContext.insert(copy)
            copy.setOnBucketList(true, at: Date(timeIntervalSince1970: 1_000_000 - daysAgo * 86_400))
        }

        let items = try bucketList().groups.flatMap(\.items)
        #expect(items.count == 1)
        #expect(items.first?.addedAt == Date(timeIntervalSince1970: 1_000_000 - 9 * 86_400))
    }

    @Test func sampleDataHasABucketList() throws {
        let sample = PreviewSupport.container()
        let list = BucketList(
            entries: try sample.mainContext.fetch(FetchDescriptor<PlaceEntry>()),
            category: nil,
            place: referenceData.place(for:)
        )
        #expect(list.groups.count == 3)
    }
}
