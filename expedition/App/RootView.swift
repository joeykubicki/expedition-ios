import OSLog
import SwiftData
import SwiftUI

/// Loads reference data, keeps duplicate entries merged, and shows the tabs.
struct RootView: View {
    @Environment(ReferenceDataStore.self) private var referenceData
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if referenceData.isLoaded {
                CategoryTabView()
            } else if referenceData.loadError != nil {
                ContentUnavailableView(
                    "Couldn't Load Places",
                    systemImage: "exclamationmark.triangle",
                    description: Text("The list of parks, states, and countries is missing or damaged. Reinstalling the app should fix it.")
                )
            } else {
                ProgressView()
            }
        }
        .task {
            await referenceData.load()
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active {
                mergeDuplicates()
            }
        }
    }

    /// Duplicates can arrive from other devices via iCloud; fold them together
    /// at launch and whenever the app comes back to the foreground.
    private func mergeDuplicates() {
        do {
            let removed = try PlaceEntryStore(context: modelContext).mergeAllDuplicates()
            if removed > 0 {
                Logger.data.info("Merged \(removed) duplicate place entries")
            }
        } catch {
            Logger.data.error("Merging duplicates failed: \(error)")
        }
    }
}

/// One tab per place category.
struct CategoryTabView: View {
    var body: some View {
        TabView {
            ForEach(PlaceCategory.allCases, id: \.self) { category in
                Tab(category.title, systemImage: category.symbolName) {
                    CategoryScreen(category: category)
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    RootView()
        .previewEnvironment()
}
#endif
