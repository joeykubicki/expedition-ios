import OSLog
import SwiftData
import SwiftUI

/// A category's searchable, filterable list of places. Everything possible on
/// the map must also be possible here.
struct PlaceList: View {
    let category: PlaceCategory
    let searchText: String
    @Binding var visitFilter: VisitFilter

    @Environment(ReferenceDataStore.self) private var referenceData
    @Environment(\.modelContext) private var modelContext
    @Query private var visitedEntries: [PlaceEntry]
    @State private var feedbackTrigger = 0

    init(category: PlaceCategory, searchText: String, visitFilter: Binding<VisitFilter>) {
        self.category = category
        self.searchText = searchText
        _visitFilter = visitFilter
        let raw = category.rawValue
        _visitedEntries = Query(filter: #Predicate<PlaceEntry> { $0.categoryRaw == raw && $0.isVisited })
    }

    /// Parks are few enough not to need an A–Z index.
    private var showsIndex: Bool {
        category != .park
    }

    private var visitedCodes: Set<String> {
        Set(visitedEntries.map(\.placeCode))
    }

    private var sections: [(initial: String, places: [Place])] {
        let places = PlaceListFilter.filter(
            referenceData.places(in: category),
            searchText: searchText,
            visitFilter: visitFilter,
            visitedCodes: visitedCodes,
            stateNames: referenceData.stateNames
        )
        if showsIndex {
            return PlaceListFilter.sectionedByInitial(places)
        }
        return places.isEmpty ? [] : [("", places)]
    }

    var body: some View {
        let sections = sections
        let visitedCodes = visitedCodes
        List {
            Section {
                CategoryProgressHeader(category: category)
                Picker("Show", selection: $visitFilter) {
                    Text("All").tag(VisitFilter.all)
                    Text("Visited").tag(VisitFilter.visited)
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
                            onToggleVisited: { toggleVisited(place) }
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

    private func toggleVisited(_ place: Place) {
        do {
            try PlaceEntryStore(context: modelContext).toggleVisited(for: place.id)
            feedbackTrigger += 1
        } catch {
            Logger.data.error("Toggling visited for \(place.id.code) failed: \(error)")
        }
    }
}

#if DEBUG
private struct PlaceListPreview: View {
    let category: PlaceCategory
    var initialSearch = ""
    @State private var visitFilter = VisitFilter.all
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            PlaceList(category: category, searchText: searchText, visitFilter: $visitFilter)
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
