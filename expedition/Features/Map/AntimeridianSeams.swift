/// Natural Earth cuts shapes that cross 180° (Chukotka, Fiji, Antarctica) into
/// pieces that meet along the antimeridian. Stroking those pieces would draw a
/// border down the cut, so their outlines skip edges that lie on it.
nonisolated enum AntimeridianSeams {
    /// The ring's outline as runs of connected points, with edges along ±180°
    /// left out. `nil` if the ring has no such edges, so it can be stroked whole.
    static func outlineRuns(of ring: [Coordinate]) -> [[Coordinate]]? {
        var points = ring
        if points.count > 1, points.first == points.last {
            points.removeLast()
        }
        let count = points.count
        guard count > 1 else { return nil }

        func isSeam(_ edge: Int) -> Bool {
            let a = points[edge], b = points[(edge + 1) % count]
            return abs(a.longitude) == 180 && a.longitude == b.longitude
        }
        guard let firstSeam = (0..<count).first(where: isSeam) else { return nil }

        // Walk every edge once, starting just after a seam, so no run wraps
        // around the ring's start.
        var runs: [[Coordinate]] = []
        var current: [Coordinate] = []
        for offset in 1...count {
            let edge = (firstSeam + offset) % count
            if isSeam(edge) {
                if current.count > 1 { runs.append(current) }
                current = []
            } else {
                if current.isEmpty { current.append(points[edge]) }
                current.append(points[(edge + 1) % count])
            }
        }
        if current.count > 1 { runs.append(current) }
        return runs
    }
}
