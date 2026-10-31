import OSLog
import SwiftData
import SwiftUI

/// The Bucket List tab: every place the user wants to visit, across all
/// categories. Swipe to check one off or remove it.
struct BucketListScreen: View {
    @Query(filter: #Predicate<PlaceEntry> { $0.isOnBucketList && !$0.isVisited })
    private var entries: [PlaceEntry]
    @Environment(ReferenceDataStore.self) private var referenceData
    @Environment(\.modelContext) private var modelContext
    @SceneStorage("bucketList.filter") private var filter = CategoryFilter.all
    @State private var selectedPlace: Place?
    @State private var checkedOffTrigger = 0

    var body: some View {
        let bucketList = BucketList(entries: entries, category: filter.category, place: referenceData.place(for:))
        NavigationStack {
            List {
                Section {
                    CategoryFilterPicker(selection: $filter)
                }

                if bucketList.isEmpty {
                    emptyState
                        .listRowBackground(Color.clear)
                }

                ForEach(bucketList.groups) { group in
                    Section {
                        ForEach(group.items) { item in
                            row(for: item)
                        }
                    } header: {
                        Text(group.category.title)
                    }
                }
            }
            .readableContentWidth()
            .scrollContentBackground(.hidden)
            .background(Color.paper)
            .tabScreenChrome()
            .navigationTitle("Bucket List")
            .sensoryFeedback(.success, trigger: checkedOffTrigger)
            .sheet(item: $selectedPlace) { place in
                PlaceDetailSheet(place: place, store: PlaceEntryStore(context: modelContext))
            }
        }
    }

    private func row(for item: BucketList.Item) -> some View {
        let added = item.addedAt.map { String(localized: "Added \($0.formatted(.dateTime.month(.wide).year()))") }
        return PlaceSummaryRow(
            place: item.place,
            detail: added ?? item.place.category.eyebrow,
            hint: "Shows details and memories"
        ) {
            selectedPlace = item.place
        }
        .swipeActions(edge: .leading) {
            Button("Visited", systemImage: "checkmark.circle") { checkOff(item.place) }
                .tint(item.place.category.visitedColor)
        }
        .swipeActions(edge: .trailing) {
            Button("Remove", systemImage: "bookmark.slash", role: .destructive) { remove(item.place) }
        }
        .accessibilityAction(named: "Mark as Visited") { checkOff(item.place) }
        .accessibilityAction(named: "Remove from Bucket List") { remove(item.place) }
    }

    @ViewBuilder
    private var emptyState: some View {
        if let category = filter.category {
            ContentUnavailableView(
                "No \(category.pluralNoun) on your bucket list",
                systemImage: "bookmark",
                description: Text("Open a place and tap Add to Bucket List.")
            )
        } else {
            ContentUnavailableView(
                "Your Bucket List Is Empty",
                systemImage: "bookmark",
                description: Text("Open a place and tap Add to Bucket List, or swipe left on a place in a list.")
            )
        }
    }

    private func checkOff(_ place: Place) {
        do {
            try PlaceEntryStore(context: modelContext).setVisited(true, for: place.id)
            checkedOffTrigger += 1
            AccessibilityNotification.Announcement("Checked \(place.name) off your bucket list").post()
            ReviewPrompt(context: modelContext).requestIfDue()
        } catch {
            Logger.data.error("Marking \(place.id.code) visited failed: \(error)")
        }
    }

    private func remove(_ place: Place) {
        do {
            try PlaceEntryStore(context: modelContext).setOnBucketList(false, for: place.id)
        } catch {
            Logger.data.error("Removing \(place.id.code) from the bucket list failed: \(error)")
        }
    }
}

#if DEBUG
#Preview("Sample data") {
    BucketListScreen()
        .previewEnvironment()
}

#Preview("Empty") {
    BucketListScreen()
        .previewEnvironment(withSampleData: false)
}
#endif
