import SwiftUI

/// A place's "Favorite Memories".
struct MemoriesSection: View {
    let editor: MemoriesEditor

    @State private var newText = ""
    @State private var editing: Memory?
    @State private var editText = ""

    var body: some View {
        Section("Favorite Memories") {
            ForEach(editor.memories) { memory in
                Text(memory.text)
                    .swipeActions(edge: .trailing) {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            if let index = editor.memories.firstIndex(of: memory) {
                                editor.removeMemories(at: [index])
                            }
                        }
                        Button("Edit", systemImage: "pencil") { beginEditing(memory) }
                    }
                    .accessibilityAction(named: "Edit") { beginEditing(memory) }
            }
            .onMove(perform: editor.moveMemories)

            VStack(alignment: .leading, spacing: 8) {
                TextField("A moment you loved", text: $newText, axis: .vertical)
                    .lineLimit(1...4)
                Button(action: add) {
                    Label("Add Memory", systemImage: "plus.circle.fill")
                }
                .disabled(newText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.vertical, 4)
        }
        .alert("Edit Memory", isPresented: isEditingBinding, presenting: editing) { memory in
            TextField("Memory", text: $editText, axis: .vertical)
            Button("Save") { editor.updateMemory(id: memory.id, text: editText) }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var isEditingBinding: Binding<Bool> {
        Binding(get: { editing != nil }, set: { if !$0 { editing = nil } })
    }

    private func add() {
        if editor.addMemory(newText) {
            newText = ""
        }
    }

    private func beginEditing(_ memory: Memory) {
        editText = memory.text
        editing = memory
    }
}
