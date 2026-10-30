import MapKit

/// A state's or country's whole outline as one overlay, for `OutlineMapView`:
/// a country with 40 islands is still one shape to add and recolor.
nonisolated struct PlaceOutline {
    let placeID: PlaceID
    let fill: MKMultiPolygon
    /// Every ring as lines, skipping antimeridian cuts (see `MapShape.outline`),
    /// for borders drawn on top: the selection and bucket-list dashes.
    let outline: [MKPolyline]
    /// Cut at the antimeridian, so the border is drawn from `outline` rather
    /// than by stroking `fill`.
    let hasSeam: Bool

    /// Builds off the main thread; countries have about 1,400 polygons.
    @concurrent
    static func outlines(for places: [Place]) async -> sending [PlaceOutline] {
        places.compactMap { place in
            let shapes = MapShape.shapes(for: [place])
            guard !shapes.isEmpty else { return nil }
            return PlaceOutline(
                placeID: place.id,
                fill: MKMultiPolygon(shapes.map(\.polygon)),
                outline: shapes.flatMap(\.outline),
                hasSeam: shapes.contains { $0.seamlessOutline != nil }
            )
        }
    }
}
