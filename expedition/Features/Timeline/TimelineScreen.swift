import SwiftData
import SwiftUI

/// The Timeline tab: every visit across all categories, grouped by year,
/// then the visited places that still need dates.
struct TimelineScreen: View {
    @Query private var entries: [PlaceEntry]
    @Environment(ReferenceDataStore.self) private var referenceData
    @Environment(\.modelContext) private var modelContext
    @SceneStorage("timeline.filter") private var filter = CategoryFilter.all
    @State private var selectedPlace: Place?

    var body: some View {
        let timeline = Timeline(entries: entries, category: filter.category, place: referenceData.place(for:))
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
                        ForEach(year.items) { item in
                            PlaceSummaryRow(place: item.place, detail: item.visit.formatted(), hint: "Shows details and memories") {
                                selectedPlace = item.place
                            }
                        }
                    } header: {
                        TimelineYearHeader(year: year)
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
            .sheet(item: $selectedPlace) { place in
                PlaceDetailSheet(place: place, store: PlaceEntryStore(context: modelContext))
            }
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

/// "2024" in the display serif, with how many places that year.
private struct TimelineYearHeader: View {
    let year: Timeline.Year

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(verbatim: String(year.year))
                .font(.title2.weight(.semibold))
                .fontDesign(.serif)
                .foregroundStyle(Color.ink)
            Spacer()
            Text("^[\(year.placeCount) place](inflect: true)")
                .font(.subheadline)
                .foregroundStyle(Color.inkSoft)
        }
        .textCase(nil)
        .accessibilityElement(children: .combine)
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
