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
                            if trip.isSingle {
                                let item = trip.items[0]
                                PlaceSummaryRow(
                                    place: item.place,
                                    detail: item.visit.formatted(),
                                    isReturnVisit: item.isReturn,
                                    hint: "Shows details and memories"
                                ) {
                                    selectedPlace = item.place
                                }
                            } else {
                                TripCard(trip: trip) { selectedPlace = $0 }
                            }
                        }
                    } header: {
                        TimelineYearHeader(year: year, showsCountryCount: filter == .all)
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

/// "2024" in the display serif, with that year's stats: "5 places · 3 new
/// · 2 countries".
private struct TimelineYearHeader: View {
    let year: Timeline.Year
    /// Only with All selected; within a category it would repeat the count.
    let showsCountryCount: Bool

    var body: some View {
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
        .textCase(nil)
        .accessibilityElement(children: .combine)
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

/// Places visited on overlapping dates: the trip's dates, then each place
/// (with its own dates when they differ), each opening its details.
private struct TripCard: View {
    let trip: Timeline.Trip
    let onSelect: (Place) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Label(trip.span.formatted(), systemImage: "suitcase.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.ink)
                Spacer()
                Text("Trip")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.inkSoft)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Trip, \(trip.span.formatted()), \(trip.items.count) places")
            .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(trip.items) { item in
                    PlaceSummaryRow(
                        place: item.place,
                        detail: coversTheWholeTrip(item) ? item.place.category.eyebrow : item.visit.formatted(),
                        isReturnVisit: item.isReturn,
                        accessibilityContext: context(for: item),
                        hint: "Shows details and memories"
                    ) {
                        onSelect(item.place)
                    }
                }
            }
            .padding(.leading, 12)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(Color.boundary)
                    .frame(width: 2)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
    }

    private func coversTheWholeTrip(_ item: Timeline.Item) -> Bool {
        item.visit.start == trip.span.start && item.visit.end == trip.span.end
    }

    /// "October 12–15, 2023, trip with Utah", so each place reads on its own.
    private func context(for item: Timeline.Item) -> String {
        let others = trip.items.map(\.place).filter { $0.id != item.place.id }
        var names: [String] = []
        for place in others where !names.contains(place.name) {
            names.append(place.name)
        }
        let dates = coversTheWholeTrip(item) ? "\(trip.span.formatted()), " : ""
        return String(localized: "\(dates)trip with \(names.formatted(.list(type: .and)))")
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
