import MapKit
import SwiftData
import SwiftUI

/// The root of a category's tab: a map or a searchable list (remembered per
/// tab), sharing one detail sheet.
struct CategoryScreen: View {
    let category: PlaceCategory
    @SceneStorage private var showsMap: Bool
    @SceneStorage private var visitFilter: VisitFilter
    @State private var searchText = ""
    @State private var cameraPosition: MapCameraPosition
    @State private var selectedPlace: Place?

    @Environment(ReferenceDataStore.self) private var referenceData
    @Environment(\.modelContext) private var modelContext

    init(category: PlaceCategory) {
        self.category = category
        _showsMap = SceneStorage(wrappedValue: true, "showsMap.\(category.rawValue)")
        _visitFilter = SceneStorage(wrappedValue: .all, "visitFilter.\(category.rawValue)")
        _cameraPosition = State(initialValue: category.initialCameraPosition)
        #if DEBUG
        // Launch with `-MapCenter "lat,lon"` to start the map elsewhere, for
        // simulator screenshots (e.g. "60,180" to check the antimeridian).
        if let center = UserDefaults.standard.string(forKey: "MapCenter")?.split(separator: ","),
           center.count == 2, let latitude = Double(center[0]), let longitude = Double(center[1]) {
            _cameraPosition = State(initialValue: .camera(MapCamera(
                centerCoordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                distance: 12_000_000
            )))
        }
        #endif
    }

    private var searchPrompt: LocalizedStringResource {
        switch category {
        case .park: "Search parks"
        case .state: "Search states"
        case .country: "Search countries"
        }
    }

    var body: some View {
        NavigationStack {
            content
                .tabScreenChrome()
                .navigationTitle(category.title)
                .navigationBarTitleDisplayMode(showsMap ? .inline : .large)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(showsMap ? "Show List" : "Show Map",
                               systemImage: showsMap ? "list.bullet" : "map") {
                            showsMap.toggle()
                        }
                    }
                }
                .sheet(item: $selectedPlace) { place in
                    PlaceDetailSheet(place: place, store: PlaceEntryStore(context: modelContext))
                }
                #if DEBUG
                .onAppear(perform: openPlaceFromLaunchArgument)
                #endif
        }
    }

    @ViewBuilder
    private var content: some View {
        if showsMap {
            CategoryMapView(category: category, position: $cameraPosition, selectedPlace: $selectedPlace)
        } else {
            PlaceList(category: category, searchText: searchText, visitFilter: $visitFilter,
                      selectedPlace: $selectedPlace)
                .searchable(text: $searchText, prompt: Text(searchPrompt))
        }
    }

    #if DEBUG
    /// Launch with `-OpenPlace <code>` (and `-selectedTab <category>`) to open
    /// a place's sheet directly, for simulator screenshots.
    private func openPlaceFromLaunchArgument() {
        guard let code = UserDefaults.standard.string(forKey: "OpenPlace") else { return }
        selectedPlace = referenceData.place(for: PlaceID(category: category, code: code))
    }
    #endif
}

#if DEBUG
#Preview {
    CategoryScreen(category: .park)
        .previewEnvironment()
}
#endif
