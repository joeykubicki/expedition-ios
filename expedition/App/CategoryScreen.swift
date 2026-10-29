import SwiftUI

/// The root of a category's tab: progress, and (in a later step) the map and
/// searchable list.
struct CategoryScreen: View {
    let category: PlaceCategory
    @State private var isShowingSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    CategoryProgressHeader(category: category)
                    ContentUnavailableView(
                        "Map and List Coming Soon",
                        systemImage: category.symbolName,
                        description: Text("You'll browse and mark \(category.pluralNoun) here.")
                    )
                }
                .padding()
            }
            .background(Color.paper)
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
