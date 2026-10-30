import SwiftUI

struct NotesSection: View {
    let editor: MemoriesEditor

    var body: some View {
        Section("Notes") {
            TextField(
                "Notes",
                text: Binding(get: { editor.notes }, set: { editor.setNotes($0) }),
                prompt: Text("What do you want to remember?"),
                axis: .vertical
            )
            .lineLimit(3...)
        }
    }
}
