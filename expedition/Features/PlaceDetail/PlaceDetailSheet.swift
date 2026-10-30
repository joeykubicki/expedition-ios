import SwiftData
import SwiftUI

/// Bottom sheet for one place: visited state and memories. Opened from the
/// list (and later the map). Edits save as you go.
struct PlaceDetailSheet: View {
    let place: Place
    @State private var editor: MemoriesEditor
    @Environment(ReferenceDataStore.self) private var referenceData
    @Environment(\.dismiss) private var dismiss
    @State private var feedbackTrigger = 0
    @State private var viewingPhoto: PlacePhoto?

    init(place: Place, store: PlaceEntryStore) {
        self.place = place
        _editor = State(initialValue: MemoriesEditor(placeID: place.id, store: store))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    PlaceDetailHeader(place: place, stateSummary: referenceData.stateSummary(for: place))
                        .padding(.top, 12) // keep the eyebrow clear of the row's rounded corner
                    visitedButton
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))

                VisitsSection(editor: editor) { feedbackTrigger += 1 }
                PhotosSection(placeID: place.id) { viewingPhoto = $0 }
                NotesSection(editor: editor)
                FavoritesSection(editor: editor, category: place.category)
                MemoriesSection(editor: editor)
            }
            .scrollContentBackground(.hidden)
            .background(Color.paper)
            .scrollDismissesKeyboard(.interactively)
            .navigationBarTitleDisplayMode(.inline)
            .contentMargins(.top, 0, for: .scrollContent)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: feedbackTrigger)
        }
        .fullScreenCover(item: $viewingPhoto) { photo in
            PhotoViewer(placeID: place.id, startingAt: photo)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var visitedButton: some View {
        Button {
            editor.toggleVisited()
            feedbackTrigger += 1
        } label: {
            Label(
                editor.isVisited ? "Visited" : "Mark as Visited",
                systemImage: editor.isVisited ? "checkmark.circle.fill" : "circle"
            )
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(VisitedButtonStyle(isVisited: editor.isVisited, color: place.category.visitedColor))
        .accessibilityHint(editor.isVisited ? "Double-tap to mark as not visited" : "")
    }
}

/// Filled when visited, outlined when not.
private struct VisitedButtonStyle: ButtonStyle {
    let isVisited: Bool
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isVisited ? Color.white : color)
            .background(isVisited ? color : Color.clear, in: .capsule)
            .overlay(Capsule().strokeBorder(color, lineWidth: 2))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(.capsule)
    }
}

private struct PlaceDetailHeader: View {
    let place: Place
    let stateSummary: String?

    private var eyebrow: String {
        let parts = [place.category.eyebrow, stateSummary].compactMap { $0 }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(eyebrow.uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.inkSoft)
                Text(place.name)
                    .font(.largeTitle.weight(.semibold))
                    .fontDesign(.serif)
                    .foregroundStyle(Color.ink)
                if !place.countsTowardTotal {
                    Text("Not counted in total")
                        .font(.subheadline)
                        .foregroundStyle(Color.inkSoft)
                }
            }
            Spacer(minLength: 0)
            if let flag = place.category == .country ? FlagEmoji.forRegionCode(place.id.code) : nil {
                Text(flag)
                    .font(.largeTitle)
                    .accessibilityHidden(true)
            } else if place.category == .park {
                Image(systemName: "tree.fill")
                    .font(.title)
                    .foregroundStyle(Color.parkVisited)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

#if DEBUG
private struct PlaceDetailPreview: View {
    let placeID: PlaceID
    @Environment(ReferenceDataStore.self) private var referenceData
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Color.clear.sheet(isPresented: .constant(true)) {
            if let place = referenceData.place(for: placeID) {
                PlaceDetailSheet(place: place, store: PlaceEntryStore(context: modelContext))
            }
        }
    }
}

#Preview("Zion, with memories") {
    PlaceDetailPreview(placeID: PlaceID(category: .park, code: "zion"))
        .previewEnvironment()
}

#Preview("Country, untouched") {
    PlaceDetailPreview(placeID: PlaceID(category: .country, code: "NZ"))
        .previewEnvironment()
}

#Preview("State, visited") {
    PlaceDetailPreview(placeID: PlaceID(category: .state, code: "UT"))
        .previewEnvironment()
}

#Preview("Large text") {
    PlaceDetailPreview(placeID: PlaceID(category: .park, code: "zion"))
        .previewEnvironment()
        .environment(\.dynamicTypeSize, .accessibility3)
}
#endif
