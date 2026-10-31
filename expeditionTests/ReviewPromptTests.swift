import Foundation
import SwiftData
import Testing
@testable import expedition

@MainActor
struct ReviewPromptTests {
    let container: ModelContainer
    let store: PlaceEntryStore
    let prompt: ReviewPrompt

    init() throws {
        container = try ModelContainerFactory.make(inMemory: true)
        store = PlaceEntryStore(context: container.mainContext)
        let defaults = try #require(UserDefaults(suiteName: "ReviewPromptTests.\(UUID().uuidString)"))
        prompt = ReviewPrompt(context: container.mainContext, defaults: defaults)
    }

    private func park(_ index: Int) -> PlaceID {
        PlaceID(category: .park, code: "park-\(index)")
    }

    private func visit(_ count: Int) throws {
        for index in 0..<count {
            try store.setVisited(true, for: park(index))
        }
    }

    private func editor(for id: PlaceID) -> MemoriesEditor {
        MemoriesEditor(placeID: id, store: store)
    }

    @Test func notDueBelowEitherThreshold() throws {
        try visit(9)
        editor(for: park(0)).setNotes("Angels Landing at sunrise")

        #expect(prompt.counts() == ReviewPrompt.Counts(visited: 9, placesWithInfo: 1))
        #expect(!prompt.shouldAsk())
    }

    @Test func dueAtTenVisitedAcrossCategories() throws {
        try visit(8)
        try store.setVisited(true, for: PlaceID(category: .state, code: "UT"))
        try store.setVisited(true, for: PlaceID(category: .country, code: "JP"))

        #expect(prompt.counts()?.visited == 10)
        #expect(prompt.shouldAsk())
    }

    @Test func unmarkedPlacesDontCountTowardVisited() throws {
        try visit(10)
        try store.setVisited(false, for: park(3))

        #expect(prompt.counts()?.visited == 9)
        #expect(!prompt.shouldAsk())
    }

    @Test func oneVisitedPlaceWithLotsOfInfoCountsOnce() throws {
        try visit(1)
        let zion = editor(for: park(0))
        zion.setNotes("Great trip")
        zion.addVisit(Visit(start: VisitDate(year: 2024)))
        zion.addFavorite(name: "The Narrows")
        zion.addMemory("Flash flood warning")

        #expect(prompt.counts()?.placesWithInfo == 1)
        #expect(!prompt.shouldAsk())
    }

    @Test func dueWhenTwoVisitedPlacesHaveInfo() throws {
        try visit(2)
        editor(for: park(0)).addFavorite(name: "Delicate Arch")
        editor(for: park(1)).addMemory("Saw a bison")

        #expect(prompt.counts()?.placesWithInfo == 2)
        #expect(prompt.shouldAsk())
    }

    @Test func infoOnUnvisitedPlacesAndBlankNotesDontCount() throws {
        try visit(1)
        editor(for: park(0)).setNotes("   \n")
        editor(for: park(1)).setNotes("Someday")

        #expect(prompt.counts()?.placesWithInfo == 0)
    }

    @Test func photosCountAsInfoOnVisitedPlaces() throws {
        try visit(2)
        let photo = CompressedPhoto(image: Data([1]), thumbnail: Data([1]), pixelWidth: 1, pixelHeight: 1)
        let library = PhotoLibrary(context: container.mainContext)
        try library.add([photo], to: park(0))
        try library.add([photo, photo], to: park(1))
        try library.add([photo], to: park(5)) // not visited

        #expect(prompt.counts()?.placesWithInfo == 2)
    }

    @Test func asksOnlyOnce() throws {
        try visit(10)
        #expect(prompt.shouldAsk())

        prompt.markAsked()
        try visit(20)
        #expect(!prompt.shouldAsk())
    }

    @Test func withABaselineAsksOnlyWhenCountsGrew() throws {
        try visit(10)
        editor(for: park(0)).setNotes("Already has info")
        let before = try #require(prompt.counts())

        editor(for: park(0)).addMemory("More info on the same place")
        #expect(!prompt.shouldAsk(since: before), "Already due, but this change moved nothing")

        try visit(11)
        #expect(prompt.shouldAsk(since: before))
    }
}
