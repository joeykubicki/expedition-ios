import SwiftData
import SwiftUI

/// The Timeline tab: every visit across all categories, grouped into trips
/// and years, then the visited places that still need dates.
struct TimelineScreen: View {
    @Query private var entries: [PlaceEntry]
    @Environment(ReferenceDataStore.self) private var referenceData
    @Environment(\.modelContext) private var modelContext
    @SceneStorage("timeline.filter") private var filter = CategoryFilter.all
    /// Off shows only each place's first visit.
    @AppStorage("timeline.showsReturnVisits") private var showsReturnVisits = true
    @State private var selectedPlace: Place?
    @State private var mapYear: MapYear?

    /// The year whose map is showing.
    private struct MapYear: Identifiable {
        let year: Int
        var id: Int { year }
    }

    var body: some View {
        let timeline = Timeline(
            entries: entries,
            category: filter.category,
            showsReturnVisits: showsReturnVisits,
            place: referenceData.place(for:)
        )
        NavigationStack {
            List {
                Section {
                    CategoryFilterPicker(selection: $filter)
                }

                if timeline.isEmpty {
                    emptyState
                        .listRowBackground(Color.clear)
                }

                ForEach(timeline.years) { year in
                    Section {
                        ForEach(year.trips) { trip in
                            TimelineTripRow(trip: trip) { selectedPlace = $0 }
                        }
                    } header: {
                        TimelineYearHeader(year: year, showsCountryCount: filter == .all) {
                            mapYear = MapYear(year: year.year)
                        }
                    }
                }

                if !timeline.undated.isEmpty {
                    Section {
                        ForEach(timeline.undated) { place in
                            PlaceSummaryRow(place: place, detail: place.category.eyebrow, hint: "Shows details, where you can add visit dates") {
                                selectedPlace = place
                            }
                        }
                    } header: {
                        Text("No Dates Yet")
                    } footer: {
                        Text("Open a place and tap Add Visit to put it on your timeline.")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.paper)
            .tabScreenChrome()
            .navigationTitle("Timeline")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu("Options", systemImage: "line.3.horizontal.decrease") {
                        Toggle("Show Return Visits", systemImage: "arrow.counterclockwise", isOn: $showsReturnVisits)
                    }
                    .accessibilityValue(showsReturnVisits ? "" : String(localized: "First visits only"))
                }
            }
            .sheet(item: $selectedPlace) { place in
                PlaceDetailSheet(place: place, store: PlaceEntryStore(context: modelContext))
            }
            .sheet(item: $mapYear) { mapYear in
                YearMapSheet(year: mapYear.year, category: filter.category, showsReturnVisits: showsReturnVisits)
            }
            #if DEBUG
            .onAppear {
                // Launch with `-OpenYearMap <year>` for simulator screenshots.
                let year = UserDefaults.standard.integer(forKey: "OpenYearMap")
                if year > 0 { mapYear = MapYear(year: year) }
            }
            #endif
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if let category = filter.category {
            ContentUnavailableView(
                "No \(category.pluralNoun) visited yet",
                systemImage: category.symbolName,
                description: Text("Places you mark as visited show up here.")
            )
        } else {
            ContentUnavailableView(
                "No Visits Yet",
                systemImage: "calendar",
                description: Text("Mark places as visited, then add the dates you went to build your timeline.")
            )
        }
    }
}

/// "2024" in the display serif, with that year's stats ("5 places · 3 new
/// · 2 countries") and a button to see the year on a map.
private struct TimelineYearHeader: View {
    let year: Timeline.Year
    /// Only with All selected; within a category it would repeat the count.
    let showsCountryCount: Bool
    let onShowMap: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: String(year.year))
                    .font(.title2.weight(.semibold))
                    .fontDesign(.serif)
                    .foregroundStyle(Color.ink)
                Spacer()
                stats
                    .font(.subheadline)
                    .foregroundStyle(Color.inkSoft)
                    .multilineTextAlignment(.trailing)
            }
            .accessibilityElement(children: .combine)
            Button(action: onShowMap) {
                Label("Show \(String(year.year)) on a Map", systemImage: "map")
                    .labelStyle(.iconOnly)
                    .font(.body)
            }
            .buttonStyle(.borderless)
        }
        .textCase(nil)
    }

    private var stats: Text {
        let countries = showsCountryCount ? year.countryCount : 0
        return switch (year.newPlaceCount > 0, countries > 0) {
        case (true, true):
            Text("^[\(year.placeCount) place](inflect: true) · \(year.newPlaceCount) new · ^[\(countries) country](inflect: true)")
        case (true, false):
            Text("^[\(year.placeCount) place](inflect: true) · \(year.newPlaceCount) new")
        case (false, true):
            Text("^[\(year.placeCount) place](inflect: true) · ^[\(countries) country](inflect: true)")
        case (false, false):
            Text("^[\(year.placeCount) place](inflect: true)")
        }
    }
}

#if DEBUG
#Preview("Sample data") {
    TimelineScreen()
        .previewEnvironment()
}

#Preview("Empty") {
    TimelineScreen()
        .previewEnvironment(withSampleData: false)
}
#endif
