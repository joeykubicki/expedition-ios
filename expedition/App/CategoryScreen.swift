import SwiftUI

/// The root of a category's tab: progress, filters, and the searchable list.
/// (The map joins it in a later step.)
struct CategoryScreen: View {
    let category: PlaceCategory
    @SceneStorage private var visitFilter: VisitFilter
    @State private var searchText = ""
    @State private var isShowingSettings = false

    init(category: PlaceCategory) {
        self.category = category
        _visitFilter = SceneStorage(wrappedValue: .all, "visitFilter.\(category.rawValue)")
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
            PlaceList(category: category, searchText: searchText, visitFilter: $visitFilter)
                .searchable(text: $searchText, prompt: Text(searchPrompt))
                .navigationTitle(category.title)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Settings", systemImage: "gearshape") {
                            isShowingSettings = true
                        }
                    }
                }
                .sheet(isPresented: $isShowingSettings) {
                    SettingsView()
                }
        }
    }
}

#if DEBUG
#Preview {
    CategoryScreen(category: .park)
        .previewEnvironment()
}
#endif
