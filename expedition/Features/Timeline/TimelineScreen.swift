import SwiftData
import SwiftUI

/// The Timeline tab: every visit across all categories, grouped by year,
/// then the visited places that still need dates.
struct TimelineScreen: View {
    @Query private var entries: [PlaceEntry]
    @Environment(ReferenceDataStore.self) private var referenceData
    @Environment(\.modelContext) private var modelContext
    @SceneStorage("timeline.filter") private var filter = TimelineFilter.all
    @State private var selectedPlace: Place?

    var body: some View {
        let timeline = Timeline(entries: entries, category: filter.category, place: referenceData.place(for:))
        NavigationStack {
            List {
                Section {
                    Picker("Show", selection: $filter) {
                        ForEach(TimelineFilter.allCases, id: \.self) { filter in
                            Text(filter.title).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                if timeline.isEmpty {
                    emptyState
                        .listRowBackground(Color.clear)
                }

                ForEach(timeline.years) { year in
                    Section {
                        ForEach(year.items) { item in
                            TimelineRow(place: item.place, detail: item.visit.formatted()) {
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
                            TimelineRow(place: place, detail: nil) {
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

enum TimelineFilter: String, CaseIterable {
    case all, park, state, country

    var category: PlaceCategory? {
        PlaceCategory(rawValue: rawValue)
    }

    var title: LocalizedStringResource {
        category?.title ?? "All"
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

/// A place on the timeline: its flag or category icon, name, and the visit's
/// dates (or its category, for places without dates).
private struct TimelineRow: View {
    let place: Place
    /// The visit's dates; `nil` in the No Dates Yet section.
    let detail: String?
    let onSelect: () -> Void

    @ScaledMetric(relativeTo: .title2) private var iconWidth = 32.0

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                icon
                    .frame(width: iconWidth)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(place.name)
                        .foregroundStyle(Color.ink)
                    Text(detail ?? place.category.eyebrow)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([place.name, place.category.eyebrow, detail].compactMap { $0 }.joined(separator: ", "))
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(detail == nil ? "Shows details, where you can add visit dates" : "Shows details and memories")
    }

    @ViewBuilder
    private var icon: some View {
        if place.category == .country, let flag = FlagEmoji.forRegionCode(place.id.code) {
            Text(flag)
                .font(.title2)
        } else {
            Image(systemName: place.category.symbolName)
                .font(.title3)
                .foregroundStyle(place.category.visitedColor)
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
