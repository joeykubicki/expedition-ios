import SwiftUI

/// All places or one category, for the Timeline and Bucket List tabs. Raw
/// values are stored in scene storage, so don't rename them.
enum CategoryFilter: String, CaseIterable {
    case all, park, state, country

    var category: PlaceCategory? {
        PlaceCategory(rawValue: rawValue)
    }

    var title: LocalizedStringResource {
        category?.title ?? "All"
    }
}

/// The segmented All / Parks / States / Countries picker.
struct CategoryFilterPicker: View {
    @Binding var selection: CategoryFilter

    var body: some View {
        Picker("Show", selection: $selection) {
            ForEach(CategoryFilter.allCases, id: \.self) { filter in
                Text(filter.title).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}
