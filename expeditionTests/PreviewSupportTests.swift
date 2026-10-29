import SwiftData
import Testing
@testable import expedition

@MainActor
struct PreviewSupportTests {
    @Test func sampleContainerHasVisitedPlaces() throws {
        let container = PreviewSupport.container()
        let store = PlaceEntryStore(context: container.mainContext)

        #expect(try store.visitedCodes(in: .park) == ["zion", "yosemite", "grand-canyon", "arches"])
        #expect(try store.entry(for: PlaceID(category: .park, code: "zion"))?.favorites.count == 2)
    }

    @Test func emptyContainerHasNoEntries() throws {
        let container = PreviewSupport.container(withSampleData: false)

        #expect(try container.mainContext.fetch(FetchDescriptor<PlaceEntry>()).isEmpty)
    }

    @Test func sampleCodesMatchReferenceData() {
        let referenceData = PreviewSupport.referenceData()

        #expect(referenceData.isLoaded)
        for id in PreviewSupport.visitedSample {
            #expect(referenceData.place(for: id) != nil, "\(id.code)")
        }
    }
}
