import Foundation
import SwiftData
import Testing
@testable import expedition

@MainActor
struct MemoriesEditorTests {
    let container: ModelContainer
    let store: PlaceEntryStore
    let zion = PlaceID(category: .park, code: "zion")

    init() throws {
        container = try ModelContainerFactory.make(inMemory: true)
        store = PlaceEntryStore(context: container.mainContext)
        store.now = { Date(timeIntervalSince1970: 1_000) }
    }

    private func entryCount() throws -> Int {
        try container.mainContext.fetchCount(FetchDescriptor<PlaceEntry>())
    }

    // MARK: Lazy creation

    @Test func openingWithoutEditingCreatesNothing() throws {
        let editor = MemoriesEditor(placeID: zion, store: store)

        #expect(editor.entry == nil)
        #expect(editor.notes.isEmpty && editor.favorites.isEmpty && !editor.isVisited)
        #expect(try entryCount() == 0)
    }

    @Test func blankInputCreatesNothing() throws {
        let editor = MemoriesEditor(placeID: zion, store: store)
        editor.setNotes("   ")
        editor.addFavorite(name: "  ")
        editor.addMemory("\n")

        #expect(try entryCount() == 0)
    }

    @Test func firstEditCreatesEntryAndLaterEditsReuseIt() throws {
        let editor = MemoriesEditor(placeID: zion, store: store)
        editor.setNotes("Hot day")
        editor.addMemory("Saw a condor")

        #expect(try entryCount() == 1)
        #expect(try store.entry(for: zion)?.notes == "Hot day")
    }

    @Test func picksUpExistingEntry() throws {
        try store.setVisited(true, for: zion)

        let editor = MemoriesEditor(placeID: zion, store: store)

        #expect(editor.isVisited)
    }

    @Test func editsUpdateTimestamp() throws {
        let editor = MemoriesEditor(placeID: zion, store: store)
        editor.setNotes("First")
        store.now = { Date(timeIntervalSince1970: 2_000) }
        editor.setNotes("First, then more")

        #expect(editor.entry?.updatedAt == Date(timeIntervalSince1970: 2_000))
    }

    @Test func toggleVisited() {
        let editor = MemoriesEditor(placeID: zion, store: store)
        editor.toggleVisited()
        #expect(editor.isVisited)
        editor.toggleVisited()
        #expect(!editor.isVisited)
    }

    // MARK: Favorites

    @Test func addFavoriteTrimsAndNormalizesLink() {
        let editor = MemoriesEditor(placeID: zion, store: store)

        #expect(editor.addFavorite(name: "  Angels Landing ", link: " alltrails.com/trail/us/utah/angels-landing-trail "))
        #expect(editor.favorites.first?.name == "Angels Landing")
        #expect(editor.favorites.first?.url?.absoluteString == "https://alltrails.com/trail/us/utah/angels-landing-trail")
    }

    @Test func addFavoriteWithoutLink() {
        let editor = MemoriesEditor(placeID: zion, store: store)

        #expect(editor.addFavorite(name: "The Narrows"))
        #expect(editor.favorites.first?.url == nil)
    }

    @Test func invalidLinkAddsNothing() throws {
        let editor = MemoriesEditor(placeID: zion, store: store)

        #expect(!editor.addFavorite(name: "Observation Point", link: "not a link"))
        #expect(editor.favorites.isEmpty)
        #expect(try entryCount() == 0)
    }

    @Test func updateFavorite() throws {
        let editor = MemoriesEditor(placeID: zion, store: store)
        editor.addFavorite(name: "Narows")
        let id = try #require(editor.favorites.first?.id)

        #expect(editor.updateFavorite(id: id, name: "The Narrows", link: "https://www.alltrails.com/x"))
        #expect(editor.favorites.first?.name == "The Narrows")
        #expect(editor.favorites.first?.url != nil)

        #expect(!editor.updateFavorite(id: id, name: "The Narrows", link: "bad link"))
        #expect(editor.favorites.first?.url?.absoluteString == "https://www.alltrails.com/x")

        #expect(editor.updateFavorite(id: id, name: "The Narrows", link: ""))
        #expect(editor.favorites.first?.url == nil)
    }

    @Test func removeAndReorderFavorites() {
        let editor = MemoriesEditor(placeID: zion, store: store)
        for name in ["A", "B", "C"] { editor.addFavorite(name: name) }

        editor.moveFavorites(from: [2], to: 0)
        #expect(editor.favorites.map(\.name) == ["C", "A", "B"])

        editor.removeFavorites(at: [1])
        #expect(editor.favorites.map(\.name) == ["C", "B"])
    }

    // MARK: Memories

    @Test func addEditRemoveAndReorderMemories() throws {
        let editor = MemoriesEditor(placeID: zion, store: store)
        editor.addMemory(" Sunrise ")
        editor.addMemory("Bighorn sheep")
        #expect(editor.memories.map(\.text) == ["Sunrise", "Bighorn sheep"])
        #expect(editor.memories.first?.createdAt == Date(timeIntervalSince1970: 1_000))

        let id = try #require(editor.memories.first?.id)
        #expect(editor.updateMemory(id: id, text: "Sunrise at Canyon Overlook"))
        #expect(!editor.updateMemory(id: id, text: "  "))

        editor.moveMemories(from: [1], to: 0)
        #expect(editor.memories.map(\.text) == ["Bighorn sheep", "Sunrise at Canyon Overlook"])

        editor.removeMemories(at: [0])
        #expect(editor.memories.map(\.text) == ["Sunrise at Canyon Overlook"])
    }

    @Test func changesArePersisted() throws {
        let editor = MemoriesEditor(placeID: zion, store: store)
        editor.addFavorite(name: "Emerald Pools")

        let reloaded = MemoriesEditor(placeID: zion, store: PlaceEntryStore(context: ModelContext(container)))

        #expect(reloaded.favorites.map(\.name) == ["Emerald Pools"])
    }
}

struct LinkInputTests {
    @Test func emptyAndWhitespaceAreEmpty() {
        #expect(LinkInput("") == .empty)
        #expect(LinkInput("   ") == .empty)
    }

    @Test func addsHTTPSWhenMissing() {
        #expect(LinkInput("alltrails.com/trail/x") == .valid(URL(string: "https://alltrails.com/trail/x")!))
    }

    @Test func keepsExistingScheme() {
        #expect(LinkInput("http://example.com") == .valid(URL(string: "http://example.com")!))
    }

    @Test func rejectsNonWebAddresses() {
        #expect(LinkInput("not a link") == .invalid)
        #expect(LinkInput("hello") == .invalid)
        #expect(LinkInput("ftp://example.com") == .invalid)
        #expect(LinkInput("javascript://alert(1)") == .invalid)
    }
}
