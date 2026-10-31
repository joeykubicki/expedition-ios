import SwiftUI

/// Settings → Share Map Image: one row per category, each opening that
/// category's map poster.
struct ShareMapSection: View {
    @Environment(ReferenceDataStore.self) private var referenceData
    @State private var sharing: SharedCategory?

    /// `sheet(item:)` needs an `Identifiable` value.
    private struct SharedCategory: Identifiable {
        let category: PlaceCategory
        var id: PlaceCategory { category }
    }

    var body: some View {
        Section("Share Map Image") {
            ForEach(PlaceCategory.allCases, id: \.self) { category in
                Button {
                    sharing = SharedCategory(category: category)
                } label: {
                    Label("\(Text(category.title)) Map", systemImage: category.symbolName)
                }
                .accessibilityHint("Opens a shareable image of your \(category.pluralNoun) map")
            }
            .disabled(!referenceData.isLoaded)
        }
        .sheet(item: $sharing) { item in
            SharePreviewSheet(category: item.category)
        }
    }
}

#if DEBUG
#Preview {
    Form {
        ShareMapSection()
    }
    .previewEnvironment()
}
#endif
