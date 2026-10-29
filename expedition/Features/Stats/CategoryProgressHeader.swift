import SwiftData
import SwiftUI

/// "42 of 63 parks" with a progress bar.
struct CategoryProgressHeader: View {
    let category: PlaceCategory
    @Environment(ReferenceDataStore.self) private var referenceData
    @Query private var visitedEntries: [PlaceEntry]

    init(category: PlaceCategory) {
        self.category = category
        let raw = category.rawValue
        _visitedEntries = Query(filter: #Predicate<PlaceEntry> { $0.categoryRaw == raw && $0.isVisited })
    }

    private var progress: CategoryProgress {
        CategoryProgress(
            category: category,
            places: referenceData.places(in: category),
            visitedCodes: Set(visitedEntries.map(\.placeCode))
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(progress.visited) of \(progress.total) \(category.pluralNoun)")
                .font(.title2.weight(.semibold))
                .fontDesign(.serif)
                .foregroundStyle(Color.ink)
            ProgressView(value: progress.fraction)
                .tint(category.visitedColor)
            Text(progress.fraction, format: .percent.precision(.fractionLength(0)))
                .font(.subheadline)
                .foregroundStyle(Color.inkSoft)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Visited \(progress.visited) of \(progress.total) \(category.pluralNoun)")
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 32) {
        ForEach(PlaceCategory.allCases, id: \.self) { category in
            CategoryProgressHeader(category: category)
        }
    }
    .padding()
    .previewEnvironment()
}
#endif
