import SwiftData
import SwiftUI

/// Bottom sheet for one place: visited state and memories. Opened from the
/// list (and later the map). Edits save as you go. Visits, photos, and
/// memories only show once the place is visited; unmarking hides them but
/// keeps them, so re-marking brings them back.
struct PlaceDetailSheet: View {
    let place: Place
    @State private var editor: MemoriesEditor
    @Environment(ReferenceDataStore.self) private var referenceData
    @Environment(\.dismiss) private var dismiss
    @State private var feedbackTrigger = 0
    @State private var checkedOffTrigger = 0
    /// Shows "Checked off your bucket list" for a moment after visiting a
    /// bucket-list place, however it was marked (button or new visit).
    @State private var isShowingCheckedOff = false
    @State private var viewingPhoto: PlacePhoto?
    @State private var detent: PresentationDetent = .medium
    @Environment(\.windowHorizontalSizeClass) private var windowSizeClass
    @State private var editMode: EditMode = .inactive
    private let reviewPrompt: ReviewPrompt
    /// Taken when the sheet opens, so closing it only asks for a rating if
    /// something changed here.
    @State private var countsAtOpen: ReviewPrompt.Counts?

    init(place: Place, store: PlaceEntryStore) {
        self.place = place
        _editor = State(initialValue: MemoriesEditor(placeID: place.id, store: store))
        reviewPrompt = ReviewPrompt(context: store.context)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    PlaceDetailHeader(place: place, stateSummary: referenceData.stateSummary(for: place))
                        .padding(.top, 12) // keep the eyebrow clear of the row's rounded corner
                    visitedButton
                    if isShowingCheckedOff {
                        checkedOffMessage
                    } else if !editor.isVisited {
                        bucketListButton
                        unvisitedHint
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))

                if editor.isVisited {
                    VisitsSection(editor: editor)
                    PhotosSection(placeID: place.id) { viewingPhoto = $0 }
                    NotesSection(editor: editor)
                    FavoritesSection(editor: editor, category: place.category)
                    MemoriesSection(editor: editor)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.paper)
            .scrollDismissesKeyboard(.interactively)
            .navigationBarTitleDisplayMode(.inline)
            .contentMargins(.top, 0, for: .scrollContent)
            .toolbar {
                if hasEditableItems {
                    ToolbarItem(placement: .topBarLeading) {
                        EditButton()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: feedbackTrigger)
            .sensoryFeedback(.success, trigger: checkedOffTrigger)
            .onChange(of: editor.isOnBucketList) { wasOnList, isOnList in
                if wasOnList, !isOnList, editor.isVisited {
                    celebrateCheckOff()
                }
            }
            .onChange(of: hasEditableItems) { _, hasItems in
                if !hasItems { editMode = .inactive }
            }
            .environment(\.editMode, $editMode)
            // The photo viewer's full-screen cover also fires these; only
            // count the sheet opening and closing.
            .onAppear {
                if countsAtOpen == nil { countsAtOpen = reviewPrompt.counts() }
            }
            .onDisappear {
                if viewingPhoto == nil { reviewPrompt.requestIfDue(since: countsAtOpen) }
            }
        }
        .fullScreenCover(item: $viewingPhoto) { photo in
            PhotoViewer(placeID: place.id, startingAt: photo)
        }
        // A tall centered card on iPad, opened full height since there's
        // room; a half-height bottom sheet on iPhone and narrow iPad windows.
        .presentationSizing(.page)
        .presentationDetents(
            windowSizeClass == .regular ? [.large] : [.medium, .large],
            selection: windowSizeClass == .regular ? .constant(.large) : $detent
        )
        .presentationDragIndicator(.visible)
    }

    /// Whether Edit has anything to delete or reorder. Notes and photos
    /// don't respond to edit mode, so they don't count. Leaves edit mode
    /// when this goes false, so the next item isn't added mid-edit.
    private var hasEditableItems: Bool {
        editor.isVisited && !(editor.visits.isEmpty && editor.favorites.isEmpty && editor.memories.isEmpty)
    }

    /// Marking visited reveals the info sections and grows the sheet so
    /// they're in view.
    private var visitedButton: some View {
        Button {
            withAnimation(.snappy) {
                editor.toggleVisited()
                if editor.isVisited { detent = .large }
            }
            feedbackTrigger += 1
        } label: {
            Label(
                editor.isVisited ? "Visited" : "Mark as Visited",
                systemImage: editor.isVisited ? "checkmark.circle.fill" : "circle"
            )
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(VisitedButtonStyle(isVisited: editor.isVisited, color: place.category.visitedColor))
        .accessibilityHint(editor.isVisited ? "Double-tap to mark as not visited" : "")
    }
}

extension PlaceDetailSheet {
    private var bucketListButton: some View {
        Button {
            editor.toggleBucketList()
        } label: {
            Label(
                editor.isOnBucketList ? "On Your Bucket List" : "Add to Bucket List",
                systemImage: editor.isOnBucketList ? "bookmark.fill" : "bookmark"
            )
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .tint(place.category.visitedColor)
        .accessibilityValue(editor.isOnBucketList ? "On" : "Off")
        .accessibilityHint(editor.isOnBucketList ? "Double-tap to remove from your bucket list" : "")
    }

    private var unvisitedHint: some View {
        Text("Mark as visited to add trips, photos, and notes.")
            .font(.subheadline)
            .foregroundStyle(Color.inkSoft)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
    }

    private var checkedOffMessage: some View {
        Label("Checked off your bucket list", systemImage: "checkmark.seal.fill")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(place.category.visitedColor)
            .frame(maxWidth: .infinity)
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }

    private func celebrateCheckOff() {
        checkedOffTrigger += 1
        AccessibilityNotification.Announcement("Checked off your bucket list").post()
        withAnimation(.snappy) { isShowingCheckedOff = true }
        Task {
            try? await Task.sleep(for: .seconds(3))
            withAnimation(.snappy) { isShowingCheckedOff = false }
        }
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
