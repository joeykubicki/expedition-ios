import SwiftUI

/// Favorite hikes (with optional links) or favorite cities.
struct FavoritesSection: View {
    let editor: MemoriesEditor
    let category: PlaceCategory

    @State private var newName = ""
    @State private var newLink = ""
    @State private var showsLinkError = false

    @State private var editing: FavoriteItem?
    @State private var editName = ""
    @State private var editLink = ""

    var body: some View {
        Section {
            ForEach(editor.favorites) { item in
                FavoriteRow(item: item)
                    .swipeActions(edge: .trailing) {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            if let index = editor.favorites.firstIndex(of: item) {
                                editor.removeFavorites(at: [index])
                            }
                        }
                        Button("Edit", systemImage: "pencil") { beginEditing(item) }
                    }
                    .accessibilityAction(named: "Edit") { beginEditing(item) }
            }
            .onMove(perform: editor.moveFavorites)

            addRow
        } header: {
            Text(category.favoritesTitle)
        } footer: {
            if showsLinkError {
                Text("That link doesn't look like a web address.")
                    .foregroundStyle(.red)
            }
        }
        .alert(Text(category.favoritesTitle), isPresented: isEditingBinding, presenting: editing) { item in
            TextField(String(localized: category.favoriteNamePrompt), text: $editName)
            if category.favoritesHaveLinks {
                TextField("AllTrails link (optional)", text: $editLink)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
            }
            Button("Save") {
                showsLinkError = !editor.updateFavorite(id: item.id, name: editName, link: editLink)
                    && LinkInput(editLink) == .invalid
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var addRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(String(localized: category.favoriteNamePrompt), text: $newName)
                .submitLabel(.done)
                .onSubmit(add)
            if category.favoritesHaveLinks {
                TextField("AllTrails link (optional)", text: $newLink)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.subheadline)
                    .onSubmit(add)
            }
            Button(action: add) {
                Label(String(localized: category.addFavoriteTitle), systemImage: "plus.circle.fill")
            }
            .padding(.top, 12)
            .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.vertical, 4)
    }

    private var isEditingBinding: Binding<Bool> {
        Binding(get: { editing != nil }, set: { if !$0 { editing = nil } })
    }

    private func add() {
        if editor.addFavorite(name: newName, link: newLink) {
            newName = ""
            newLink = ""
            showsLinkError = false
        } else {
            showsLinkError = LinkInput(newLink) == .invalid
        }
    }

    private func beginEditing(_ item: FavoriteItem) {
        editName = item.name
        editLink = item.url?.absoluteString ?? ""
        editing = item
    }
}

private struct FavoriteRow: View {
    let item: FavoriteItem

    var body: some View {
        if let url = item.url {
            Link(destination: url) {
                HStack {
                    Text(item.name)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityHint("Opens the trail link")
        } else {
            Text(item.name)
        }
    }
}
