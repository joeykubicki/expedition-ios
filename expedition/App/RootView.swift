import OSLog
import SwiftData
import SwiftUI

/// Loads reference data, keeps duplicate entries merged, and shows the tabs.
struct RootView: View {
    @Environment(ReferenceDataStore.self) private var referenceData
    @Environment(SyncMonitor.self) private var syncMonitor
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

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
        .environment(\.windowHorizontalSizeClass, horizontalSizeClass)
        .task {
            await referenceData.load()
        }
        .task {
            await syncMonitor.start()
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

/// One tab per place category, then the bucket list and the timeline.
/// Remembers the last selected tab.
struct CategoryTabView: View {
    @AppStorage("selectedTab") private var selectedTab = AppTab.park

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(PlaceCategory.allCases, id: \.self) { category in
                Tab(category.title, systemImage: category.symbolName, value: AppTab(category)) {
                    CategoryScreen(category: category)
                }
            }
            Tab("Bucket List", systemImage: "bookmark", value: AppTab.bucketList) {
                BucketListScreen()
            }
            Tab("Timeline", systemImage: "calendar", value: AppTab.timeline) {
                TimelineScreen()
            }
        }
    }
}

/// Raw values match `PlaceCategory`'s, so the remembered tab from before the
/// timeline existed still restores.
nonisolated enum AppTab: String, Sendable {
    case park, state, country, bucketList, timeline

    init(_ category: PlaceCategory) {
        self = switch category {
        case .park: .park
        case .state: .state
        case .country: .country
        }
    }
}

#if DEBUG
#Preview {
    RootView()
        .previewEnvironment()
}
#endif
