import Foundation

/// How many places in a category the user has visited, e.g. "42 of 63 parks".
nonisolated struct CategoryProgress: Equatable, Sendable {
    let category: PlaceCategory
    let visited: Int
    let total: Int

    var fraction: Double {
        total == 0 ? 0 : Double(visited) / Double(total)
    }

    /// Counts only places that count toward the total (so Greenland can be
    /// visited without changing "of 197"). Codes that don't match a known
    /// place are ignored.
    init(category: PlaceCategory, places: [Place], visitedCodes: Set<String>) {
        let counted = places.filter { $0.category == category && $0.countsTowardTotal }
        self.category = category
        self.total = counted.count
        self.visited = counted.filter { visitedCodes.contains($0.id.code) }.count
    }
}
