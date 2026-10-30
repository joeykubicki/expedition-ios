import Foundation
import SwiftData
import Testing
@testable import expedition

@MainActor
struct DataTransferTests {
    let zion = PlaceID(category: .park, code: "zion")
    let utah = PlaceID(category: .state, code: "UT")
    let japan = PlaceID(category: .country, code: "JP")

    /// A context must not outlive its container, so keep containers for the test's lifetime.
    private final class Containers {
        var all: [ModelContainer] = []
    }
    private let containers = Containers()

    private func makeStore() throws -> PlaceEntryStore {
        let container = try ModelContainerFactory.make(inMemory: true)
        containers.all.append(container)
        return PlaceEntryStore(context: container.mainContext)
    }

    private func entries(in store: PlaceEntryStore) throws -> [PlaceEntry] {
        try store.context.fetch(FetchDescriptor<PlaceEntry>())
    }

    /// Exports, encodes to JSON, decodes, and imports into `destination`.
    @discardableResult
    private func transfer(from source: PlaceEntryStore, to destination: PlaceEntryStore) throws -> ImportSummary {
        let data = try DataTransfer.encode(DataTransfer.exportFile(from: try entries(in: source)))
        return try DataTransfer.importFile(try DataTransfer.decode(data), into: destination)
    }

    private func populate(_ store: PlaceEntryStore) throws {
        store.now = { Date(timeIntervalSince1970: 1_700_000_000.123) }
        try store.setVisited(true, for: zion)
        let entry = try store.entryOrCreate(for: zion)
        entry.notes = "Hiked the Narrows"
        entry.favorites = [FavoriteItem(name: "Angels Landing", url: URL(string: "https://www.alltrails.com/trail/x"))]
        entry.memories = [Memory(text: "Bighorn sheep", createdAt: Date(timeIntervalSince1970: 1_700_000_100))]
        entry.visits = [
            Visit(start: VisitDate(year: 2023, month: 10, day: 12), end: VisitDate(year: 2023, month: 10, day: 15)),
            Visit(start: VisitDate(year: 2016)),
        ]
        try store.setVisited(true, for: utah)
        try store.entryOrCreate(for: japan).notes = "Want to go back"
        try store.setOnBucketList(true, for: japan)
        try store.context.save()
    }

    // MARK: Round trip

    @Test func roundTripRestoresEverything() throws {
        let source = try makeStore()
        try populate(source)
        let destination = try makeStore()

        let summary = try transfer(from: source, to: destination)

        #expect(summary == ImportSummary(added: 3, merged: 0, skipped: 0))
        let original = DataTransfer.exportFile(from: try entries(in: source)).entries
        let restored = DataTransfer.exportFile(from: try entries(in: destination)).entries
        #expect(restored == original)
    }

    @Test func reimportingSameFileChangesNothing() throws {
        let store = try makeStore()
        try populate(store)
        let before = DataTransfer.exportFile(from: try entries(in: store)).entries

        let summary = try transfer(from: store, to: store)

        #expect(summary == ImportSummary(added: 0, merged: 3, skipped: 0))
        #expect(try entries(in: store).count == 3)
        #expect(DataTransfer.exportFile(from: try entries(in: store)).entries == before)
    }

    @Test func importMergesIntoExistingData() throws {
        let source = try makeStore()
        try populate(source)
        let destination = try makeStore()
        let local = try destination.entryOrCreate(for: zion)
        local.notes = "Camped at Watchman"
        local.favorites = [FavoriteItem(name: "Observation Point")]
        try destination.context.save()

        let summary = try transfer(from: source, to: destination)

        #expect(summary == ImportSummary(added: 2, merged: 1, skipped: 0))
        let merged = try #require(try destination.entry(for: zion))
        #expect(merged.isVisited)
        #expect(merged.notes.contains("Camped at Watchman") && merged.notes.contains("Hiked the Narrows"))
        #expect(Set(merged.favorites.map(\.name)) == ["Observation Point", "Angels Landing"])
        #expect(try entries(in: destination).count == 3)
    }

    @Test func importNeverUnmarksVisited() throws {
        let source = try makeStore()
        try source.entryOrCreate(for: zion)
        let destination = try makeStore()
        try destination.setVisited(true, for: zion)

        try transfer(from: source, to: destination)

        #expect(try destination.entry(for: zion)?.isVisited == true)
    }

    // MARK: File format

    @Test func exportIsStableAndVersioned() throws {
        let store = try makeStore()
        try populate(store)
        let exportedAt = Date(timeIntervalSince1970: 1_800_000_000)

        let first = try DataTransfer.encode(DataTransfer.exportFile(from: try entries(in: store), exportedAt: exportedAt))
        let second = try DataTransfer.encode(DataTransfer.exportFile(from: try entries(in: store).reversed(), exportedAt: exportedAt))
        let json = try #require(String(data: first, encoding: .utf8))

        #expect(first == second)
        #expect(json.contains("\"format\" : \"expedition-export\""))
        #expect(json.contains("\"version\" : 3"))
        #expect(json.contains("\"isOnBucketList\" : true"))
        #expect(json.contains("\"year\" : 2016"))
        #expect(json.contains("\"exportedAt\" : 1800000000"))
        #expect(json.contains("https://www.alltrails.com/trail/x"))
    }

    @Test func rejectsNonExpeditionJSON() {
        let data = Data(#"{"hello": "world"}"#.utf8)
        #expect(throws: ImportError.notAnExpeditionFile) { try DataTransfer.decode(data) }
    }

    @Test func rejectsNewerVersionWithHelpfulError() {
        let data = Data(#"{"format": "expedition-export", "version": 4, "somethingNew": []}"#.utf8)
        #expect(throws: ImportError.newerVersion(4)) { try DataTransfer.decode(data) }
    }

    @Test func rejectsMalformedFiles() {
        #expect(throws: ImportError.unreadable) { try DataTransfer.decode(Data("not json".utf8)) }
        let missingEntries = Data(#"{"format": "expedition-export", "version": 1}"#.utf8)
        #expect(throws: ImportError.unreadable) { try DataTransfer.decode(missingEntries) }
    }

    /// Version 1 files predate visits; their `visitDates` was always empty.
    @Test func readsVersion1Files() throws {
        let json = """
        {"format": "expedition-export", "version": 1, "exportedAt": 1793361600,
         "entries": [
          {"entryID": "00000000-0000-0000-0000-000000000002", "category": "park", "code": "zion",
           "isVisited": true, "visitDates": [], "notes": "Old notes", "favorites": [], "memories": [],
           "createdAt": 1793361600, "updatedAt": 1793361600}
         ]}
        """
        let store = try makeStore()

        _ = try DataTransfer.importFile(try DataTransfer.decode(Data(json.utf8)), into: store)

        let zion = try #require(try store.entry(for: zion))
        #expect(zion.notes == "Old notes")
        #expect(zion.visits.isEmpty)
    }

    @Test func readsVersion2FilesWithoutABucketList() throws {
        let json = """
        {"format": "expedition-export", "version": 2, "exportedAt": 1793361600,
         "entries": [
          {"entryID": "00000000-0000-0000-0000-000000000002", "category": "country", "code": "IT",
           "isVisited": false, "notes": "Someday", "favorites": [], "memories": [], "visits": [],
           "createdAt": 1793361600, "updatedAt": 1793361600}
         ]}
        """
        let store = try makeStore()

        _ = try DataTransfer.importFile(try DataTransfer.decode(Data(json.utf8)), into: store)

        let italy = try #require(try store.entry(for: PlaceID(category: .country, code: "IT")))
        #expect(!italy.isOnBucketList)
        #expect(italy.bucketListAddedAt == nil)
    }

    /// Hand-edited or odd files: visited wins, as everywhere else.
    @Test func importedVisitedPlacesAreNotOnTheBucketList() throws {
        let json = """
        {"format": "expedition-export", "version": 3, "exportedAt": 1793361600,
         "entries": [
          {"entryID": "00000000-0000-0000-0000-000000000002", "category": "country", "code": "IT",
           "isVisited": true, "isOnBucketList": true, "bucketListAddedAt": 1793361600,
           "notes": "", "favorites": [], "memories": [], "visits": [],
           "createdAt": 1793361600, "updatedAt": 1793361600},
          {"entryID": "00000000-0000-0000-0000-000000000003", "category": "country", "code": "NO",
           "isVisited": false, "isOnBucketList": true, "bucketListAddedAt": 1793361600,
           "notes": "", "favorites": [], "memories": [], "visits": [],
           "createdAt": 1793361600, "updatedAt": 1793361600}
         ]}
        """
        let store = try makeStore()

        _ = try DataTransfer.importFile(try DataTransfer.decode(Data(json.utf8)), into: store)

        #expect(try store.bucketListCodes(in: .country) == ["NO"])
        #expect(try store.entry(for: PlaceID(category: .country, code: "IT"))?.isOnBucketList == false)
        #expect(try store.entry(for: PlaceID(category: .country, code: "NO"))?.bucketListAddedAt == Date(timeIntervalSince1970: 1793361600))
    }

    @Test func readsVisitsAtEveryPrecision() throws {
        let json = """
        {"format": "expedition-export", "version": 2, "exportedAt": 1793361600,
         "entries": [
          {"entryID": "00000000-0000-0000-0000-000000000002", "category": "country", "code": "FR",
           "isVisited": true, "notes": "", "favorites": [], "memories": [],
           "visits": [
             {"id": "00000000-0000-0000-0000-00000000000A", "start": {"year": 2019, "month": 5}, "end": {"year": 2019, "month": 6}},
             {"id": "00000000-0000-0000-0000-00000000000B", "start": {"year": 2012}},
             {"id": "00000000-0000-0000-0000-00000000000C", "start": {"year": 2024, "month": 2, "day": 29}}
           ],
           "createdAt": 1793361600, "updatedAt": 1793361600}
         ]}
        """
        let file = try DataTransfer.decode(Data(json.utf8))
        let visits = try #require(file.entries.first?.visits)

        #expect(visits.map(\.start.precision) == [.month, .year, .day])
        #expect(visits[0].end == VisitDate(year: 2019, month: 6))
    }

    @Test(arguments: [
        #"{"year": 2019, "month": 13}"#,                 // no 13th month
        #"{"year": 2023, "month": 2, "day": 29}"#,       // not a leap year
        #"{"year": 2019, "day": 4}"#,                    // day without month
    ])
    func rejectsImpossibleVisitDates(_ date: String) {
        let json = """
        {"format": "expedition-export", "version": 2, "exportedAt": 1793361600,
         "entries": [
          {"entryID": "00000000-0000-0000-0000-000000000002", "category": "park", "code": "zion",
           "isVisited": true, "notes": "", "favorites": [], "memories": [],
           "visits": [{"id": "00000000-0000-0000-0000-00000000000A", "start": \(date)}],
           "createdAt": 1793361600, "updatedAt": 1793361600}
         ]}
        """
        #expect(throws: ImportError.unreadable) { try DataTransfer.decode(Data(json.utf8)) }
    }

    @Test func rejectsVisitsEndingBeforeTheyStart() {
        let json = """
        {"format": "expedition-export", "version": 2, "exportedAt": 1793361600,
         "entries": [
          {"entryID": "00000000-0000-0000-0000-000000000002", "category": "park", "code": "zion",
           "isVisited": true, "notes": "", "favorites": [], "memories": [],
           "visits": [{"id": "00000000-0000-0000-0000-00000000000A", "start": {"year": 2020}, "end": {"year": 2019}}],
           "createdAt": 1793361600, "updatedAt": 1793361600}
         ]}
        """
        #expect(throws: ImportError.unreadable) { try DataTransfer.decode(Data(json.utf8)) }
    }

    @Test func skipsUnknownCategories() throws {
        let json = """
        {"format": "expedition-export", "version": 1, "exportedAt": 1793361600,
         "entries": [
          {"entryID": "00000000-0000-0000-0000-000000000001", "category": "monument", "code": "x",
           "isVisited": true, "visitDates": [], "notes": "", "favorites": [], "memories": [],
           "createdAt": 1793361600, "updatedAt": 1793361600},
          {"entryID": "00000000-0000-0000-0000-000000000002", "category": "park", "code": "zion",
           "isVisited": true, "visitDates": [], "notes": "", "favorites": [], "memories": [],
           "createdAt": 1793361600.5, "updatedAt": 1793361600}
         ]}
        """
        let store = try makeStore()

        let summary = try DataTransfer.importFile(try DataTransfer.decode(Data(json.utf8)), into: store)

        #expect(summary == ImportSummary(added: 1, merged: 0, skipped: 1))
        #expect(try store.entry(for: zion)?.isVisited == true)
    }

    @Test func exportFileNameIsDated() {
        // Noon UTC, so the local date is the same in every time zone from UTC-11 to UTC+11.
        let package = ExportPackage(file: ExportFile(exportedAt: Date(timeIntervalSince1970: 1_800_014_400), entries: []))
        #expect(package.fileName == "Expedition 2027-01-15.json")
    }
}
