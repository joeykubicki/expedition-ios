import Foundation
import SwiftData

typealias PlacePhoto = SchemaV1.PlacePhoto

nonisolated extension SchemaV1 {
    /// A photo the user added to a place, already compressed by
    /// `PhotoCompressor`. Synced via CloudKit, under the same rules as
    /// `PlaceEntry`.
    ///
    /// Linked to its place by category and code rather than a relationship to
    /// `PlaceEntry`, so duplicate entries arriving from sync never split a
    /// place's photos. Create and delete photos through `PhotoLibrary`.
    @Model
    final class PlacePhoto {
        var photoID: UUID = UUID()
        /// `PlaceCategory` raw value, stored as a string so `#Predicate` works.
        var categoryRaw: String = PlaceCategory.park.rawValue
        /// Park slug, USPS state code, or ISO country code.
        var placeCode: String = ""
        var addedAt: Date = Date.now
        /// A small image for the detail sheet's photo row, stored inline.
        var thumbnailData: Data?
        /// The full image, at most `PhotoCompressor.maxPixelSize` on its long
        /// side. Kept in a separate file on device and synced as a CloudKit
        /// asset, so it's only loaded when the viewer shows it.
        @Attribute(.externalStorage) var imageData: Data?
        var pixelWidth: Int = 0
        var pixelHeight: Int = 0

        init(placeID: PlaceID, photo: CompressedPhoto, addedAt: Date = .now) {
            self.categoryRaw = placeID.category.rawValue
            self.placeCode = placeID.code
            self.addedAt = addedAt
            self.thumbnailData = photo.thumbnail
            self.imageData = photo.image
            self.pixelWidth = photo.pixelWidth
            self.pixelHeight = photo.pixelHeight
        }
    }
}
