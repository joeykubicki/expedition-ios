import Foundation
import SwiftData

/// The only way to add or delete `PlacePhoto` records. Views read photos with
/// `@Query` (using `PhotoLibrary.descriptor(for:)`) and write through this.
final class PhotoLibrary {
    /// Photos per place. Keeps a well-used library from filling iCloud.
    static let limit = 12

    let context: ModelContext
    var now: () -> Date = { .now }

    init(context: ModelContext) {
        self.context = context
    }

    /// Oldest first, the order they were added.
    static func descriptor(for id: PlaceID) -> FetchDescriptor<PlacePhoto> {
        let category = id.category.rawValue
        let code = id.code
        return FetchDescriptor(
            predicate: #Predicate { $0.categoryRaw == category && $0.placeCode == code },
            sortBy: [SortDescriptor(\.addedAt), SortDescriptor(\.photoID)]
        )
    }

    func photos(for id: PlaceID) throws -> [PlacePhoto] {
        try context.fetch(Self.descriptor(for: id))
    }

    /// How many more photos the place can take. Never negative, though a
    /// place can end up over the limit when two devices add photos at once.
    func remainingSlots(for id: PlaceID) throws -> Int {
        max(0, Self.limit - (try context.fetchCount(Self.descriptor(for: id))))
    }

    /// Adds photos in order, stopping at the limit. Returns how many were added.
    @discardableResult
    func add(_ photos: [CompressedPhoto], to id: PlaceID) throws -> Int {
        let accepted = photos.prefix(try remainingSlots(for: id))
        let start = now()
        for (offset, photo) in accepted.enumerated() {
            // Distinct times keep a batch in the order it was picked.
            context.insert(PlacePhoto(placeID: id, photo: photo, addedAt: start.addingTimeInterval(Double(offset) / 1000)))
        }
        try context.save()
        return accepted.count
    }

    func delete(_ photo: PlacePhoto) throws {
        context.delete(photo)
        try context.save()
    }
}
