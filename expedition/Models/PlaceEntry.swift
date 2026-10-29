import Foundation
import SwiftData

typealias PlaceEntry = SchemaV1.PlaceEntry

nonisolated enum SchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [PlaceEntry.self]
    }

    /// What the user has recorded about one place. Synced via CloudKit, so:
    /// every property has a default, nothing is unique, and after the first
    /// App Store release properties may be added but never renamed or removed.
    ///
    /// Create entries only through `PlaceEntryStore`, which looks up an
    /// existing entry first. Duplicates can still arrive from other devices;
    /// `DuplicateMerger` folds them together.
    @Model
    final class PlaceEntry {
        /// Synced, stable identity used to pick the same survivor on every
        /// device when merging duplicates.
        var entryID: UUID = UUID()
        /// `PlaceCategory` raw value, stored as a string so `#Predicate` works.
        var categoryRaw: String = PlaceCategory.park.rawValue
        /// Park slug, USPS state code, or ISO country code.
        var placeCode: String = ""
        var isVisited: Bool = false
        /// Not shown in v1; reserved for the v1.1 timeline.
        var visitDates: [Date] = []
        var notes: String = ""
        /// Favorite hikes (parks) or favorite cities (states and countries).
        var favorites: [FavoriteItem] = []
        var memories: [Memory] = []
        var createdAt: Date = Date.now
        var updatedAt: Date = Date.now

        init(placeID: PlaceID, createdAt: Date = .now) {
            self.categoryRaw = placeID.category.rawValue
            self.placeCode = placeID.code
            self.createdAt = createdAt
            self.updatedAt = createdAt
        }

        /// `nil` only if the stored raw value is unrecognized.
        var category: PlaceCategory? {
            PlaceCategory(rawValue: categoryRaw)
        }

        var placeID: PlaceID? {
            category.map { PlaceID(category: $0, code: placeCode) }
        }
    }
}

nonisolated enum ExpeditionMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
