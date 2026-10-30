import Foundation
import OSLog
import SwiftData
import SwiftUI

/// Reads and edits one place's visited state and memories for the detail
/// sheet. Doesn't create a `PlaceEntry` until the first real change, so
/// opening and closing a sheet leaves nothing behind.
@Observable
final class MemoriesEditor {
    let placeID: PlaceID
    private let store: PlaceEntryStore
    private(set) var entry: PlaceEntry?

    init(placeID: PlaceID, store: PlaceEntryStore) {
        self.placeID = placeID
        self.store = store
        do {
            entry = try store.entry(for: placeID)
        } catch {
            Logger.data.error("Loading entry for \(placeID.code) failed: \(error)")
        }
    }

    var isVisited: Bool { entry?.isVisited ?? false }
    var notes: String { entry?.notes ?? "" }
    var favorites: [FavoriteItem] { entry?.favorites ?? [] }
    var memories: [Memory] { entry?.memories ?? [] }

    // MARK: Visited

    func toggleVisited() {
        edit { $0.isVisited.toggle() }
    }

    // MARK: Visits

    /// Newest first.
    var visits: [Visit] { (entry?.visits ?? []).sorted(by: Visit.newestFirst) }

    /// Adds a visit, marking the place visited if it wasn't. Returns whether
    /// it did, so the caller can give the same feedback as the Visited button.
    @discardableResult
    func addVisit(_ visit: Visit) -> Bool {
        let marksVisited = !isVisited
        edit {
            $0.visits.append(visit)
            $0.isVisited = true
        }
        return marksVisited
    }

    func updateVisit(_ visit: Visit) {
        guard let index = entry?.visits.firstIndex(where: { $0.id == visit.id }) else { return }
        edit { $0.visits[index] = visit }
    }

    func removeVisit(id: Visit.ID) {
        guard entry?.visits.contains(where: { $0.id == id }) == true else { return }
        edit { $0.visits.removeAll { $0.id == id } }
    }

    // MARK: Notes

    /// Stores notes as typed (trimming mid-typing would eat spaces).
    func setNotes(_ text: String) {
        guard text != notes else { return }
        if entry == nil && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return }
        edit { $0.notes = text }
    }

    // MARK: Favorites

    /// Adds a favorite hike or city. Returns `false` (and adds nothing) if the
    /// link was filled in but isn't a valid web address.
    @discardableResult
    func addFavorite(name: String, link: String = "") -> Bool {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let linkInput = LinkInput(link)
        guard !name.isEmpty, linkInput != .invalid else { return false }
        edit { $0.favorites.append(FavoriteItem(name: name, url: linkInput.url)) }
        return true
    }

    /// Updates a favorite. Returns `false` (and changes nothing) if the name is
    /// blank or the link is invalid.
    @discardableResult
    func updateFavorite(id: FavoriteItem.ID, name: String, link: String) -> Bool {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let linkInput = LinkInput(link)
        guard !name.isEmpty, linkInput != .invalid,
              let index = favorites.firstIndex(where: { $0.id == id })
        else { return false }
        edit {
            $0.favorites[index].name = name
            $0.favorites[index].url = linkInput.url
        }
        return true
    }

    func removeFavorites(at offsets: IndexSet) {
        edit { $0.favorites.remove(atOffsets: offsets) }
    }

    func moveFavorites(from source: IndexSet, to destination: Int) {
        edit { $0.favorites.move(fromOffsets: source, toOffset: destination) }
    }

    // MARK: Memories

    @discardableResult
    func addMemory(_ text: String) -> Bool {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return false }
        edit { $0.memories.append(Memory(text: text, createdAt: store.now())) }
        return true
    }

    @discardableResult
    func updateMemory(id: Memory.ID, text: String) -> Bool {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let index = memories.firstIndex(where: { $0.id == id }) else { return false }
        edit { $0.memories[index].text = text }
        return true
    }

    func removeMemories(at offsets: IndexSet) {
        edit { $0.memories.remove(atOffsets: offsets) }
    }

    func moveMemories(from source: IndexSet, to destination: Int) {
        edit { $0.memories.move(fromOffsets: source, toOffset: destination) }
    }

    // MARK: Saving

    private func edit(_ change: (PlaceEntry) -> Void) {
        do {
            let entry = try self.entry ?? store.entryOrCreate(for: placeID)
            self.entry = entry
            change(entry)
            entry.updatedAt = store.now()
            try store.context.save()
        } catch {
            Logger.data.error("Saving changes to \(self.placeID.code) failed: \(error)")
        }
    }
}

private extension LinkInput {
    var url: URL? {
        if case .valid(let url) = self { url } else { nil }
    }
}
