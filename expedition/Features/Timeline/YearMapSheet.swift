import MapKit
import SwiftData
import SwiftUI

/// One year on a map, with that year's trips listed below (oldest first,
/// numbered like the pins). Shows exactly what the Timeline shows for the
/// year: the same category filter and return-visit setting.
struct YearMapSheet: View {
    let category: PlaceCategory?
    let showsReturnVisits: Bool

    @Query private var entries: [PlaceEntry]
    @Environment(ReferenceDataStore.self) private var referenceData
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var year: Int
    @State private var position: MapCameraPosition = .automatic
    @State private var shapes: [MapShape] = []
    @State private var selectedPlace: Place?
    @State private var sharing: YearReview?

    init(year: Int, category: PlaceCategory?, showsReturnVisits: Bool) {
        self.category = category
        self.showsReturnVisits = showsReturnVisits
        _year = State(initialValue: year)
    }

    var body: some View {
        let years = Timeline(
            entries: entries,
            category: category,
            showsReturnVisits: showsReturnVisits,
            place: referenceData.place(for:)
        ).years
        NavigationStack {
            Group {
                if let current = years.first(where: { $0.year == year }) {
                    content(YearMap(year: current))
                } else {
                    ContentUnavailableView("No Visits in \(String(year))", systemImage: "calendar")
                }
            }
            .background(Color.paper)
            .navigationTitle(Text(verbatim: String(year)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    yearButton(to: years.map(\.year).first { $0 < year }, label: "Previous Year", systemImage: "chevron.left")
                    yearButton(to: years.map(\.year).last { $0 > year }, label: "Next Year", systemImage: "chevron.right")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Share Year in Review", systemImage: "square.and.arrow.up") {
                        sharing = years.first { $0.year == year }.map { YearReview(year: $0) }
                    }
                    .disabled(!years.contains { $0.year == year })
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $selectedPlace) { place in
                PlaceDetailSheet(place: place, store: PlaceEntryStore(context: modelContext))
            }
            .sheet(item: $sharing) { review in
                PosterShareSheet(
                    fileName: String(localized: "Expedition – \(String(review.year))"),
                    accessibilityLabel: String(localized: "Year in review poster: \(String(review.year)), \(review.placeCount) places, \(review.newPlaceCount) new")
                ) { format in
                    YearPoster(review: review, format: format, referenceData: referenceData)
                }
            }
            #if DEBUG
            .onAppear {
                // Launch with `-OpenYearReview YES` (and `-OpenYearMap <year>`) for screenshots.
                if UserDefaults.standard.bool(forKey: "OpenYearReview") {
                    sharing = years.first { $0.year == year }.map { YearReview(year: $0) }
                }
            }
            #endif
        }
    }

    private func content(_ map: YearMap) -> some View {
        VStack(spacing: 0) {
            YearMapView(map: map, shapes: shapes, position: $position) { selectedPlace = $0 }
                .containerRelativeFrame(.vertical) { height, _ in height * 0.5 }
            List {
                ForEach(Array(map.trips.enumerated()), id: \.element.id) { index, trip in
                    Section {
                        TimelineTripRow(trip: trip) { selectedPlace = $0 }
                    } header: {
                        HStack(spacing: 8) {
                            TripNumberBadge(numbers: [index + 1])
                            Text("Trip \(index + 1)")
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Trip \(index + 1)")
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        // Rebuild the outlines and reframe when the year (or what's in it) changes.
        .task(id: map.stops.map(\.id)) {
            // Countries first, so states draw on top when both are there.
            let outlined = map.places.filter { $0.boundary != nil }.sorted { $0.category == .country && $1.category != .country }
            shapes = MapShape.shapes(for: outlined)
            position = .rect(map.mapRect ?? .world)
        }
    }

    private func yearButton(to target: Int?, label: LocalizedStringResource, systemImage: String) -> some View {
        Button {
            if let target {
                withAnimation { year = target }
            }
        } label: {
            Label(label, systemImage: systemImage)
        }
        .disabled(target == nil)
        .accessibilityLabel(target.map { Text("\(label), \(String($0))") } ?? Text(label))
    }
}

/// The year's places: filled outlines for states and countries, tree markers
/// for parks, and each place's trip number.
private struct YearMapView: View {
    let map: YearMap
    let shapes: [MapShape]
    @Binding var position: MapCameraPosition
    let onSelect: (Place) -> Void

    var body: some View {
        MapReader { proxy in
            Map(position: $position) {
                ForEach(shapes) { shape in
                    MapPolygon(shape.polygon)
                        .foregroundStyle(Color.visited.opacity(0.75))
                        .stroke(shape.seamlessOutline == nil ? Color.boundary : .clear, lineWidth: 0.5)
                    if let outline = shape.seamlessOutline {
                        ForEach(outline.indices, id: \.self) { index in
                            MapPolyline(outline[index])
                                .stroke(Color.boundary, lineWidth: 0.5)
                        }
                    }
                }
                .mapOverlayLevel(level: .aboveRoads)

                ForEach(map.stops) { stop in
                    Annotation(stop.place.name, coordinate: stop.place.labelCoordinate.clLocationCoordinate, anchor: .center) {
                        stopButton(stop)
                    }
                }
                .annotationTitles(.hidden)
            }
            .mapStyle(.standard(emphasis: .muted, pointsOfInterest: .excludingAll))
            .onTapGesture { point in
                guard let coordinate = proxy.convert(point, from: .local),
                      let place = PlaceHitTester.place(
                          at: Coordinate(latitude: coordinate.latitude, longitude: coordinate.longitude),
                          in: map.places.filter { $0.boundary != nil }
                      )
                else { return }
                onSelect(place)
            }
        }
    }

    private func stopButton(_ stop: YearMap.Stop) -> some View {
        Button {
            onSelect(stop.place)
        } label: {
            if stop.place.category == .park {
                ParkMarker(isVisited: true, isSelected: false)
                    .overlay(alignment: .bottom) {
                        TripNumberBadge(numbers: stop.tripNumbers)
                            .fixedSize()
                            .offset(y: 16)
                    }
            } else {
                TripNumberBadge(numbers: stop.tripNumbers)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(stop.tripNumbers.count == 1
            ? "\(stop.place.name), trip \(stop.tripNumbers[0])"
            : "\(stop.place.name), trips \(stop.tripNumbers.map(String.init).formatted(.list(type: .and)))")
        .accessibilityHint("Shows details and memories")
    }
}

/// "1" or "1, 3" in a dark capsule, matching the map pins to the list.
struct TripNumberBadge: View {
    let numbers: [Int]

    var body: some View {
        Text(numbers.map(String.init).joined(separator: ", "))
            .font(.caption2.weight(.bold))
            .monospacedDigit()
            .foregroundStyle(Color.paper)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .frame(minWidth: 20)
            .background(Color.ink, in: .capsule)
            .overlay(Capsule().strokeBorder(Color.paper, lineWidth: 1))
    }
}

#if DEBUG
#Preview("2023") {
    Color.clear.sheet(isPresented: .constant(true)) {
        YearMapSheet(year: 2023, category: nil, showsReturnVisits: true)
    }
    .previewEnvironment()
}

#Preview("2024, abroad") {
    Color.clear.sheet(isPresented: .constant(true)) {
        YearMapSheet(year: 2024, category: nil, showsReturnVisits: true)
    }
    .previewEnvironment()
}
#endif
