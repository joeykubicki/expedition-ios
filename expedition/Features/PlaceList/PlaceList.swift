import OSLog
import SwiftData
import SwiftUI

/// A category's searchable, filterable list of places. Everything possible on
/// the map must also be possible here.
struct PlaceList: View {
    let category: PlaceCategory
    let searchText: String
    @Binding var visitFilter: VisitFilter
    @Binding var selectedPlace: Place?

    @Environment(ReferenceDataStore.self) private var referenceData
    @Environment(\.modelContext) private var modelContext
    /// Visited or on the bucket list.
    @Query private var markedEntries: [PlaceEntry]
    @State private var feedbackTrigger = 0
    @State private var checkedOffTrigger = 0

    init(category: PlaceCategory, searchText: String, visitFilter: Binding<VisitFilter>, selectedPlace: Binding<Place?>) {
        self.category = category
        self.searchText = searchText
        _visitFilter = visitFilter
        _selectedPlace = selectedPlace
        let raw = category.rawValue
        _markedEntries = Query(filter: #Predicate<PlaceEntry> {
            $0.categoryRaw == raw && ($0.isVisited || $0.isOnBucketList)
        })
    }

    /// Parks are few enough not to need an A–Z index.
    private var showsIndex: Bool {
        category != .park
    }

    private var visitedCodes: Set<String> {
        Set(markedEntries.filter(\.isVisited).map(\.placeCode))
    }

    private var bucketListCodes: Set<String> {
        Set(markedEntries.filter(\.wantsToVisit).map(\.placeCode))
    }

    private func sections(visitedCodes: Set<String>, bucketListCodes: Set<String>) -> [(initial: String, places: [Place])] {
        let places = PlaceListFilter.filter(
            referenceData.places(in: category),
            searchText: searchText,
            visitFilter: visitFilter,
            visitedCodes: visitedCodes,
            bucketListCodes: bucketListCodes,
            stateNames: referenceData.stateNames
        )
        if showsIndex {
            return PlaceListFilter.sectionedByInitial(places)
        }
        return places.isEmpty ? [] : [("", places)]
    }

    var body: some View {
        let visitedCodes = visitedCodes
        let bucketListCodes = bucketListCodes
        let sections = sections(visitedCodes: visitedCodes, bucketListCodes: bucketListCodes)
        List {
            Section {
                CategoryProgressHeader(category: category)
                Picker("Show", selection: $visitFilter) {
                    Text("All").tag(VisitFilter.all)
                    Text("Visited").tag(VisitFilter.visited)
                    Text("Bucket List").tag(VisitFilter.bucketList)
                    Text("Not Visited").tag(VisitFilter.notVisited)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            if sections.isEmpty {
                emptyState
                    .listRowBackground(Color.clear)
            }

            ForEach(sections, id: \.initial) { section in
                Section {
                    ForEach(section.places) { place in
                        PlaceRow(
                            place: place,
                            subtitle: subtitle(for: place),
                            isVisited: visitedCodes.contains(place.id.code),
                            isOnBucketList: bucketListCodes.contains(place.id.code),
                            onToggleVisited: { toggleVisited(place, wasOnBucketList: bucketListCodes.contains(place.id.code)) },
                            onToggleBucketList: { toggleBucketList(place, isOnList: bucketListCodes.contains(place.id.code)) },
                            onSelect: { selectedPlace = place }
                        )
                    }
                } header: {
                    if showsIndex {
                        Text(section.initial)
                    }
                }
                .sectionIndexLabel(showsIndex ? section.initial : nil)
            }
        }
        .listSectionIndexVisibility(showsIndex ? .visible : .hidden)
        .scrollContentBackground(.hidden)
        .background(Color.paper)
        .sensoryFeedback(.impact(weight: .medium), trigger: feedbackTrigger)
        .sensoryFeedback(.success, trigger: checkedOffTrigger)
    }

    @ViewBuilder
    private var emptyState: some View {
        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else if visitFilter == .visited {
            ContentUnavailableView(
                "No \(category.pluralNoun) visited yet",
                systemImage: category.symbolName,
                description: Text("Tap the circle next to a place to mark it visited.")
            )
        } else if visitFilter == .bucketList {
            ContentUnavailableView(
                "No \(category.pluralNoun) on your bucket list",
                systemImage: "bookmark",
                description: Text("Swipe left on a place, or open it and tap Add to Bucket List.")
            )
        } else {
            ContentUnavailableView(
                "You've visited every one of the \(category.pluralNoun)",
                systemImage: "checkmark.seal.fill"
            )
        }
    }

    private func subtitle(for place: Place) -> String? {
        if !place.countsTowardTotal {
            return String(localized: "Not counted in total")
        }
        // Skip "American Samoa / American Samoa".
        let summary = referenceData.stateSummary(for: place)
        return summary == place.name ? nil : summary
    }

    private func toggleVisited(_ place: Place, wasOnBucketList: Bool) {
        do {
            let isVisited = try PlaceEntryStore(context: modelContext).toggleVisited(for: place.id)
            if isVisited, wasOnBucketList {
                checkedOffTrigger += 1
                AccessibilityNotification.Announcement("Checked \(place.name) off your bucket list").post()
            } else {
                feedbackTrigger += 1
            }
        } catch {
            Logger.data.error("Toggling visited for \(place.id.code) failed: \(error)")
        }
    }

    private func toggleBucketList(_ place: Place, isOnList: Bool) {
        do {
            try PlaceEntryStore(context: modelContext).setOnBucketList(!isOnList, for: place.id)
        } catch {
            Logger.data.error("Changing the bucket list for \(place.id.code) failed: \(error)")
        }
    }
}

#if DEBUG
private struct PlaceListPreview: View {
    let category: PlaceCategory
    var initialSearch = ""
    @State private var visitFilter = VisitFilter.all
    @State private var searchText = ""
    @State private var selectedPlace: Place?

    var body: some View {
        NavigationStack {
            PlaceList(category: category, searchText: searchText, visitFilter: $visitFilter,
                      selectedPlace: $selectedPlace)
                .searchable(text: $searchText)
                .navigationTitle(category.title)
        }
        .onAppear { searchText = initialSearch }
    }
}

#Preview("Parks") {
    PlaceListPreview(category: .park)
        .previewEnvironment()
}

#Preview("States") {
    PlaceListPreview(category: .state)
        .previewEnvironment()
}

#Preview("Countries") {
    PlaceListPreview(category: .country)
        .previewEnvironment()
}

#Preview("No search results") {
    PlaceListPreview(category: .country, initialSearch: "Atlantis")
        .previewEnvironment()
}

#Preview("Large text") {
    PlaceListPreview(category: .park)
        .previewEnvironment()
        .environment(\.dynamicTypeSize, .accessibility3)
}
#endif
