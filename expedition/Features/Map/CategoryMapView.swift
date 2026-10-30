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
    /// Visited or on the bucket list.
    @Query private var markedEntries: [PlaceEntry]
    /// States and countries, built once.
    @State private var outlines: [PlaceOutline] = []
    /// The parks map's plain state outlines, built once.
    @State private var shapes: [MapShape] = []
    @State private var mapWidth: Double = 0
    /// Width of the visible area in `MKMapPoint`s, updated when the camera stops.
    @State private var visibleMapPointWidth: Double?
    /// How close (in points) park markers can get before they're grouped: a
    /// bit more than a count marker's size. Scales with Dynamic Type, like
    /// the markers themselves.
    @ScaledMetric(relativeTo: .caption) private var clusterSpacingWidth = 44.0
    @ScaledMetric(relativeTo: .caption) private var clusterSpacingHeight = 30.0

    init(category: PlaceCategory, position: Binding<MapCameraPosition>, selectedPlace: Binding<Place?>) {
        self.category = category
        _position = position
        _selectedPlace = selectedPlace
        let raw = category.rawValue
        _markedEntries = Query(filter: #Predicate<PlaceEntry> {
            $0.categoryRaw == raw && ($0.isVisited || $0.isOnBucketList)
        })
    }

    var body: some View {
        let visitedCodes = Set(markedEntries.filter(\.isVisited).map(\.placeCode))
        let bucketListCodes = Set(markedEntries.filter(\.wantsToVisit).map(\.placeCode))
        Group {
            if category == .park {
                parkMap(visitedCodes: visitedCodes, bucketListCodes: bucketListCodes)
            } else {
                OutlineMapView(
                    outlines: outlines,
                    places: referenceData.places(in: category),
                    visitedCodes: visitedCodes,
                    bucketListCodes: bucketListCodes,
                    selectedPlaceID: selectedPlace?.id,
                    visitedColor: category.visitedColor,
                    position: $position
                ) { selectedPlace = $0 }
                .ignoresSafeArea()
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
        .modifier(OutlineMapAccessibility(category: category, visitedCount: visitedCodes.count, bucketListCount: bucketListCodes.count))
        .task {
            switch category {
            case .park where shapes.isEmpty:
                shapes = await MapShape.build(for: referenceData.states)
            case .state where outlines.isEmpty, .country where outlines.isEmpty:
                outlines = await PlaceOutline.outlines(for: referenceData.places(in: category))
            default:
                break
            }
        }
    }

    /// Parks sit on plain parchment states, which never change, so the
    /// SwiftUI `Map` (with its SwiftUI markers) stays quick here.
    private func parkMap(visitedCodes: Set<String>, bucketListCodes: Set<String>) -> some View {
        Map(position: $position) {
            ForEach(shapes) { shape in
                MapPolygon(shape.polygon)
                    .foregroundStyle(Color.land.opacity(0.6))
                    .stroke(shape.seamlessOutline == nil ? Color.boundary : .clear, lineWidth: 0.5)
                if let outline = shape.seamlessOutline {
                    ForEach(outline.indices, id: \.self) { index in
                        MapPolyline(outline[index])
                            .stroke(Color.boundary, lineWidth: 0.5)
                    }
                }
            }
            .mapOverlayLevel(level: .aboveRoads)

            ForEach(parkClusters) { cluster in
                Annotation(
                    cluster.parks.map(\.name).formatted(.list(type: .and)),
                    coordinate: cluster.coordinate.clLocationCoordinate,
                    anchor: .center
                ) {
                    if cluster.isSingle {
                        let park = cluster.parks[0]
                        parkButton(park, isVisited: visitedCodes.contains(park.id.code),
                                   isOnBucketList: bucketListCodes.contains(park.id.code))
                    } else {
                        clusterButton(cluster, visitedCodes: visitedCodes, bucketListCodes: bucketListCodes)
                    }
                }
            }
            .annotationTitles(.hidden)
        }
        .mapStyle(.standard(emphasis: .muted, pointsOfInterest: .excludingAll))
        .onMapCameraChange(frequency: .onEnd) { context in
            visibleMapPointWidth = context.rect.size.width
        }
        .onGeometryChange(for: Double.self) { $0.size.width } action: { mapWidth = $0 }
    }

    /// Parks grouped by how crowded they'd look at the current zoom. The
    /// selected park always stands alone so its marker stays visible.
    private var parkClusters: [ParkCluster] {
        let pointsPerMapPoint = visibleMapPointWidth.map { mapWidth / $0 }
        let others = referenceData.parks.filter { $0.id != selectedPlace?.id }
        let selected = referenceData.parks.filter { $0.id == selectedPlace?.id }
        return ParkClusterer.clusters(
            for: others,
            pointsPerMapPoint: pointsPerMapPoint,
            spacing: CGSize(width: clusterSpacingWidth, height: clusterSpacingHeight)
        )
            + selected.map { ParkCluster(parks: [$0]) }
    }

    private func parkButton(_ park: Place, isVisited: Bool, isOnBucketList: Bool) -> some View {
        Button {
            selectedPlace = park
        } label: {
            ParkMarker(isVisited: isVisited, isOnBucketList: isOnBucketList, isSelected: selectedPlace?.id == park.id)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(park.name)
        .accessibilityValue(isVisited ? "Visited" : isOnBucketList ? "On bucket list" : "Not visited")
        .accessibilityHint("Shows details and memories")
    }

    private func clusterButton(_ cluster: ParkCluster, visitedCodes: Set<String>, bucketListCodes: Set<String>) -> some View {
        let visitedCount = cluster.parks.count { visitedCodes.contains($0.id.code) }
        let bucketListCount = cluster.parks.count { bucketListCodes.contains($0.id.code) }
        return Button {
            withAnimation {
                position = .region(cluster.zoomRegion)
            }
        } label: {
            ParkClusterMarker(count: cluster.parks.count, visitedCount: visitedCount, bucketListCount: bucketListCount)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(cluster.parks.count) parks: \(cluster.parks.map(\.name).formatted(.list(type: .and)))")
        .accessibilityValue(bucketListCount > 0 ? "\(visitedCount) visited, \(bucketListCount) on bucket list" : "\(visitedCount) visited")
        .accessibilityHint("Zooms in to show these parks")
    }
}

/// State and country outlines aren't individually accessible, so VoiceOver
/// gets a summary and a pointer to the list, which has every place.
private struct OutlineMapAccessibility: ViewModifier {
    let category: PlaceCategory
    let visitedCount: Int
    let bucketListCount: Int

    func body(content: Content) -> some View {
        if category == .park {
            content
        } else {
            content
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(bucketListCount > 0
                    ? "Map of \(category.pluralNoun), \(visitedCount) visited, \(bucketListCount) on your bucket list"
                    : "Map of \(category.pluralNoun), \(visitedCount) visited")
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
