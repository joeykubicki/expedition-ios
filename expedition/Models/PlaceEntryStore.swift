import Foundation
import SwiftData

/// The only way to create or change `PlaceEntry` records. Views read entries
/// with `@Query` and write through this store.
final class PlaceEntryStore {
    let context: ModelContext
    var now: () -> Date = { .now }

    init(context: ModelContext) {
        self.context = context
    }

    /// The entry for a place, merging any duplicates found along the way.
    func entry(for id: PlaceID) throws -> PlaceEntry? {
        let category = id.category.rawValue
        let code = id.code
        let matches = try context.fetch(FetchDescriptor<PlaceEntry>(
            predicate: #Predicate { $0.categoryRaw == category && $0.placeCode == code }
        ))
        guard !matches.isEmpty else { return nil }

        let (survivor, duplicates) = DuplicateMerger.merge(matches)
        if !duplicates.isEmpty {
            duplicates.forEach(context.delete)
            try context.save()
        }
        return survivor
    }

    /// The existing entry for a place, or a new one if there is none.
    @discardableResult
    func entryOrCreate(for id: PlaceID) throws -> PlaceEntry {
        if let existing = try entry(for: id) {
            return existing
        }
        let entry = PlaceEntry(placeID: id, createdAt: now())
        context.insert(entry)
        try context.save()
        return entry
    }

    func setVisited(_ visited: Bool, for id: PlaceID) throws {
        let entry = try entryOrCreate(for: id)
        guard entry.isVisited != visited else { return }
        entry.setVisited(visited)
        entry.updatedAt = now()
        try context.save()
    }

    /// Flips the visited state and returns the new value.
    @discardableResult
    func toggleVisited(for id: PlaceID) throws -> Bool {
        let visited = try !(entry(for: id)?.isVisited ?? false)
        try setVisited(visited, for: id)
        return visited
    }

    /// Adds or removes a place from the bucket list. Visited places can't be
    /// added.
    func setOnBucketList(_ onList: Bool, for id: PlaceID) throws {
        if !onList, try entry(for: id) == nil { return }
        let entry = try entryOrCreate(for: id)
        guard entry.isOnBucketList != onList, !(onList && entry.isVisited) else { return }
        entry.setOnBucketList(onList, at: now())
        entry.updatedAt = now()
        try context.save()
    }

    /// Codes of the places in a category that are on the bucket list and not
    /// yet visited.
    func bucketListCodes(in category: PlaceCategory) throws -> Set<String> {
        let raw = category.rawValue
        let listed = try context.fetch(FetchDescriptor<PlaceEntry>(
            predicate: #Predicate { $0.categoryRaw == raw && $0.isOnBucketList && !$0.isVisited }
        ))
        return Set(listed.map(\.placeCode))
    }

    /// Codes of the visited places in a category.
    func visitedCodes(in category: PlaceCategory) throws -> Set<String> {
        let raw = category.rawValue
        let visited = try context.fetch(FetchDescriptor<PlaceEntry>(
            predicate: #Predicate { $0.categoryRaw == raw && $0.isVisited }
        ))
        return Set(visited.map(\.placeCode))
    }

    /// Merges every group of duplicates. Returns how many entries were removed.
    @discardableResult
    func mergeAllDuplicates() throws -> Int {
        let duplicates = DuplicateMerger.mergeAll(try context.fetch(FetchDescriptor<PlaceEntry>()))
        guard !duplicates.isEmpty else { return 0 }
        duplicates.forEach(context.delete)
        try context.save()
        return duplicates.count
    }
}
