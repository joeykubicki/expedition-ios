import MapKit
import SwiftData
import SwiftUI

/// A category's map: themed outlines for states and countries, tree markers
/// for parks. Tapping a place selects it, which opens its detail sheet.
struct CategoryMapView: View {
    let category: PlaceCategory
    @Binding var position: MapCameraPosition
    @Binding var selectedPlace: Place?

    @Environment(ReferenceDataStore.self) private var referenceData
    @Query private var visitedEntries: [PlaceEntry]
    @State private var shapes: [MapShape] = []

    init(category: PlaceCategory, position: Binding<MapCameraPosition>, selectedPlace: Binding<Place?>) {
        self.category = category
        _position = position
        _selectedPlace = selectedPlace
        let raw = category.rawValue
        _visitedEntries = Query(filter: #Predicate<PlaceEntry> { $0.categoryRaw == raw && $0.isVisited })
    }

    var body: some View {
        let visitedCodes = Set(visitedEntries.map(\.placeCode))
        MapReader { proxy in
            Map(position: $position) {
                ForEach(shapes) { shape in
                    MapPolygon(shape.polygon)
                        .foregroundStyle(fill(for: shape, visitedCodes: visitedCodes))
                        .stroke(
                            shape.placeID == selectedPlace?.id ? Color.ink : Color.boundary,
                            lineWidth: shape.placeID == selectedPlace?.id ? 2.5 : 0.5
                        )
                }
                .mapOverlayLevel(level: .aboveRoads)

                if category == .park {
                    ForEach(referenceData.parks) { park in
                        Annotation(park.name, coordinate: park.labelCoordinate.clLocationCoordinate, anchor: .center) {
                            parkButton(park, isVisited: visitedCodes.contains(park.id.code))
                        }
                    }
                    .annotationTitles(.hidden)
                }
            }
            .mapStyle(.standard(emphasis: .muted, pointsOfInterest: .excludingAll))
            .onTapGesture { point in
                guard category != .park, let coordinate = proxy.convert(point, from: .local) else { return }
                selectedPlace = PlaceHitTester.place(
                    at: Coordinate(latitude: coordinate.latitude, longitude: coordinate.longitude),
                    in: referenceData.places(in: category)
                )
            }
        }
        .overlay(alignment: .top) {
            CategoryProgressChip(progress: CategoryProgress(
                category: category,
                places: referenceData.places(in: category),
                visitedCodes: visitedCodes
            ))
            .padding(.top, 8)
        }
        .modifier(OutlineMapAccessibility(category: category, visitedCount: visitedCodes.count))
        .task {
            // Parks sit on plain parchment states; the other tabs color their own outlines.
            shapes = MapShape.shapes(for: category == .country ? referenceData.countries : referenceData.states)
        }
    }

    private func fill(for shape: MapShape, visitedCodes: Set<String>) -> Color {
        if category != .park, visitedCodes.contains(shape.placeID.code) {
            return category.visitedColor.opacity(0.75)
        }
        return Color.land.opacity(0.6)
    }

    private func parkButton(_ park: Place, isVisited: Bool) -> some View {
        Button {
            selectedPlace = park
        } label: {
            ParkMarker(isVisited: isVisited, isSelected: selectedPlace?.id == park.id)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(park.name)
        .accessibilityValue(isVisited ? "Visited" : "Not visited")
        .accessibilityHint("Shows details and memories")
    }
}

/// State and country outlines aren't individually accessible, so VoiceOver
/// gets a summary and a pointer to the list, which has every place.
private struct OutlineMapAccessibility: ViewModifier {
    let category: PlaceCategory
    let visitedCount: Int

    func body(content: Content) -> some View {
        if category == .park {
            content
        } else {
            content
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Map of \(category.pluralNoun), \(visitedCount) visited")
                .accessibilityHint("Switch to the list to browse and mark every place.")
        }
    }
}

#if DEBUG
private struct CategoryMapPreview: View {
    let category: PlaceCategory
    @State private var position: MapCameraPosition
    @State private var selectedPlace: Place?

    init(category: PlaceCategory) {
        self.category = category
        _position = State(initialValue: category.initialCameraPosition)
    }

    var body: some View {
        CategoryMapView(category: category, position: $position, selectedPlace: $selectedPlace)
    }
}

#Preview("Parks") {
    CategoryMapPreview(category: .park)
        .previewEnvironment()
}

#Preview("States") {
    CategoryMapPreview(category: .state)
        .previewEnvironment()
}

#Preview("Countries") {
    CategoryMapPreview(category: .country)
        .previewEnvironment()
}
#endif
