#if DEBUG
import SwiftData
import SwiftUI

/// In-memory data for SwiftUI Previews.
enum PreviewSupport {
    static let visitedSample: [PlaceID] = [
        PlaceID(category: .park, code: "zion"),
        PlaceID(category: .park, code: "yosemite"),
        PlaceID(category: .park, code: "grand-canyon"),
        PlaceID(category: .park, code: "arches"),
        PlaceID(category: .state, code: "UT"),
        PlaceID(category: .state, code: "CA"),
        PlaceID(category: .state, code: "AZ"),
        PlaceID(category: .state, code: "CO"),
        PlaceID(category: .country, code: "JP"),
        PlaceID(category: .country, code: "FR"),
        PlaceID(category: .country, code: "PE"),
        PlaceID(category: .country, code: "IS"),
    ]

    /// An in-memory container, optionally filled with sample visited places.
    static func container(withSampleData: Bool = true) -> ModelContainer {
        do {
            let container = try ModelContainerFactory.make(inMemory: true)
            if withSampleData {
                let store = PlaceEntryStore(context: container.mainContext)
                for id in visitedSample {
                    try store.setVisited(true, for: id)
                }
                let zion = try store.entryOrCreate(for: PlaceID(category: .park, code: "zion"))
                zion.notes = "Hiked the Narrows in October. Cold water, golden cottonwoods."
                zion.favorites = [
                    FavoriteItem(name: "The Narrows", url: URL(string: "https://www.alltrails.com/trail/us/utah/the-narrows-bottom-up-to-big-springs")),
                    FavoriteItem(name: "Angels Landing"),
                ]
                zion.memories = [Memory(text: "Bighorn sheep on the switchbacks")]
                try container.mainContext.save()
            }
            return container
        } catch {
            fatalError("Preview container failed: \(error)")
        }
    }

    static func referenceData() -> ReferenceDataStore {
        let store = ReferenceDataStore()
        do {
            try store.loadSynchronously()
        } catch {
            fatalError("Preview reference data failed: \(error)")
        }
        return store
    }
}

extension View {
    /// Supplies the model container and reference data views expect.
    func previewEnvironment(withSampleData: Bool = true) -> some View {
        modelContainer(PreviewSupport.container(withSampleData: withSampleData))
            .environment(PreviewSupport.referenceData())
    }
}
#endif
