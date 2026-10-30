import SwiftData
import SwiftUI

/// "42 of 63 parks" with a progress bar, and how many are on the bucket list.
struct CategoryProgressHeader: View {
    let category: PlaceCategory
    @Environment(ReferenceDataStore.self) private var referenceData
    /// Visited or on the bucket list.
    @Query private var markedEntries: [PlaceEntry]

    init(category: PlaceCategory) {
        self.category = category
        let raw = category.rawValue
        _markedEntries = Query(filter: #Predicate<PlaceEntry> {
            $0.categoryRaw == raw && ($0.isVisited || $0.isOnBucketList)
        })
    }

    private var progress: CategoryProgress {
        CategoryProgress(
            category: category,
            places: referenceData.places(in: category),
            visitedCodes: Set(markedEntries.filter(\.isVisited).map(\.placeCode))
        )
    }

    private var bucketListCount: Int {
        let known = Set(referenceData.places(in: category).map(\.id.code))
        return Set(markedEntries.filter(\.wantsToVisit).map(\.placeCode)).intersection(known).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(progress.visited) of \(progress.total) \(category.pluralNoun)")
                .font(.title2.weight(.semibold))
                .fontDesign(.serif)
                .foregroundStyle(Color.ink)
            ProgressView(value: progress.fraction)
                .tint(category.visitedColor)
            HStack {
                Text(progress.fraction, format: .percent.precision(.fractionLength(0)))
                Spacer()
                if bucketListCount > 0 {
                    Label("\(bucketListCount) on your bucket list", systemImage: "bookmark.fill")
                }
            }
            .font(.subheadline)
            .foregroundStyle(Color.inkSoft)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(bucketListCount > 0
            ? "Visited \(progress.visited) of \(progress.total) \(category.pluralNoun), \(bucketListCount) on your bucket list"
            : "Visited \(progress.visited) of \(progress.total) \(category.pluralNoun)")
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
