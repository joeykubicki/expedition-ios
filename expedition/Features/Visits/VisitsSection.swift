import SwiftUI

/// A place's visits in the detail sheet, newest first. Tap one to edit it.
struct VisitsSection: View {
    let editor: MemoriesEditor
    /// Called when adding a visit marks the place visited, for haptics.
    let onMarkedVisited: () -> Void

    @State private var editing: EditingVisit?

    /// What the editor sheet is showing: a new visit or an existing one.
    private struct EditingVisit: Identifiable {
        let id: UUID
        let draft: VisitDraft
        let isNew: Bool
    }

    var body: some View {
        Section {
            ForEach(editor.visits) { visit in
                Button {
                    editing = EditingVisit(id: visit.id, draft: VisitDraft(visit), isNew: false)
                } label: {
                    Label(visit.formatted(), systemImage: "calendar")
                        .foregroundStyle(Color.ink)
                }
                .accessibilityHint("Edits this visit")
            }
            .onDelete { offsets in
                let visits = editor.visits
                for index in offsets {
                    editor.removeVisit(id: visits[index].id)
                }
            }

            Button {
                editing = EditingVisit(id: UUID(), draft: VisitDraft(today: .now), isNew: true)
            } label: {
                Label("Add Visit", systemImage: "plus.circle.fill")
            }
        } header: {
            Text("Visits")
        } footer: {
            if !editor.isVisited, !editor.visits.isEmpty {
                Text("Mark as visited to show these on your timeline.")
            }
        }
        .sheet(item: $editing) { item in
            VisitEditor(
                title: item.isNew ? "Add Visit" : "Edit Visit",
                draft: item.draft,
                onSave: { draft in save(draft, id: item.id, isNew: item.isNew) },
                onDelete: item.isNew ? nil : { editor.removeVisit(id: item.id) }
            )
        }
    }

    private func save(_ draft: VisitDraft, id: UUID, isNew: Bool) {
        guard let visit = draft.visit(id: id) else { return }
        if isNew {
            if editor.addVisit(visit) {
                onMarkedVisited()
            }
        } else {
            editor.updateVisit(visit)
        }
    }
}
