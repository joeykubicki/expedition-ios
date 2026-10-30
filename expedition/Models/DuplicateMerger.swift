import Foundation

/// Folds duplicate `PlaceEntry` records (same category and place code) into
/// one. Duplicates arise when two devices create an entry for the same place
/// before syncing, since CloudKit can't enforce uniqueness.
///
/// The result depends only on the entries' contents, never on input order or
/// which device runs it, so every device converges on the same survivor and
/// the same merged data.
enum DuplicateMerger {
    /// Merges each group of duplicates into its survivor and returns the
    /// entries that should be deleted.
    static func mergeAll(_ entries: [PlaceEntry]) -> [PlaceEntry] {
        let groups = Dictionary(grouping: entries) { [$0.categoryRaw, $0.placeCode] }
        return groups.values.filter { $0.count > 1 }.flatMap { merge($0).duplicates }
    }

    /// Merges a group of entries for the same place into the oldest one.
    static func merge(_ entries: [PlaceEntry]) -> (survivor: PlaceEntry, duplicates: [PlaceEntry]) {
        precondition(!entries.isEmpty, "Nothing to merge")
        let ordered = entries.sorted(by: isOrderedBefore)
        let survivor = ordered[0]
        let duplicates = Array(ordered.dropFirst())
        guard !duplicates.isEmpty else { return (survivor, []) }

        survivor.isVisited = ordered.contains { $0.isVisited }
        survivor.visits = mergedVisits(ordered.map(\.visits))
        survivor.notes = mergedNotes(ordered.map(\.notes))
        survivor.favorites = mergedFavorites(ordered.map(\.favorites))
        survivor.memories = mergedMemories(ordered.map(\.memories))
        survivor.createdAt = ordered.map(\.createdAt).min() ?? survivor.createdAt
        survivor.updatedAt = ordered.map(\.updatedAt).max() ?? survivor.updatedAt
        return (survivor, duplicates)
    }

    /// Oldest first; ties broken by the synced `entryID`.
    private static func isOrderedBefore(_ a: PlaceEntry, _ b: PlaceEntry) -> Bool {
        if a.createdAt != b.createdAt { return a.createdAt < b.createdAt }
        return a.entryID.uuidString < b.entryID.uuidString
    }

    /// Keeps every distinct note, separated by a blank line, so no text is lost.
    private static func mergedNotes(_ notes: [String]) -> String {
        var result = ""
        for note in notes.map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }) where !note.isEmpty {
            if result.contains(note) { continue }
            result += result.isEmpty ? note : "\n\n" + note
        }
        return result
    }

    /// Unions by ID, and treats the same name (ignoring case and accents) as
    /// one item, since both devices may have typed the same city.
    private static func mergedFavorites(_ lists: [[FavoriteItem]]) -> [FavoriteItem] {
        var result: [FavoriteItem] = []
        var seenIDs: Set<UUID> = []
        var indexByName: [String: Int] = [:]
        for item in lists.joined() {
            guard seenIDs.insert(item.id).inserted else { continue }
            let key = normalized(item.name)
            if let index = indexByName[key] {
                if result[index].url == nil, let url = item.url {
                    result[index].url = url
                }
                continue
            }
            indexByName[key] = result.count
            result.append(item)
        }
        return result
    }

    private static func mergedMemories(_ lists: [[Memory]]) -> [Memory] {
        var result: [Memory] = []
        var seenIDs: Set<UUID> = []
        var seenTexts: Set<String> = []
        for memory in lists.joined() {
            guard seenIDs.insert(memory.id).inserted,
                  seenTexts.insert(normalized(memory.text)).inserted
            else { continue }
            result.append(memory)
        }
        return result
    }

    /// Unions by ID, and treats the same dates as one visit, since both devices
    /// may have entered the same trip. Sorted newest first so every device
    /// stores the same order.
    private static func mergedVisits(_ lists: [[Visit]]) -> [Visit] {
        var result: [Visit] = []
        var seenIDs: Set<UUID> = []
        var seenDates: Set<[VisitDate?]> = []
        for visit in lists.joined() {
            guard seenIDs.insert(visit.id).inserted,
                  seenDates.insert([visit.start, visit.end]).inserted
            else { continue }
            result.append(visit)
        }
        return result.sorted(by: Visit.newestFirst)
    }

    private static func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}
