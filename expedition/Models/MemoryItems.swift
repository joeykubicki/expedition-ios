import Foundation

/// A favorite hike (with an optional AllTrails link) or a favorite city.
nonisolated struct FavoriteItem: Codable, Hashable, Identifiable, Sendable {
    var id: UUID = UUID()
    var name: String
    var url: URL?
}

/// One of a place's "Favorite Memories".
nonisolated struct Memory: Codable, Hashable, Identifiable, Sendable {
    var id: UUID = UUID()
    var text: String
    var createdAt: Date = .now
}
