import CoreGraphics
import Foundation

/// The share image's map, laid out in points for a given width (y down):
/// filled areas for states or countries, dots for parks, and inset boxes for
/// Alaska and Hawaii. Parks too far away for an inset (American Samoa, the
/// Virgin Islands) are listed as `outlying` for the poster to label.
nonisolated struct PosterMap: Sendable {
    struct Area: Sendable {
        let placeID: PlaceID
        /// Exterior and hole rings; fill even-odd.
        let rings: [[CGPoint]]
        let isVisited: Bool
    }

    struct Dot: Sendable {
        let placeID: PlaceID
        let center: CGPoint
        let isVisited: Bool
    }

    struct Outlying: Sendable {
        let place: Place
        let isVisited: Bool
    }

    let size: CGSize
    let areas: [Area]
    let dots: [Dot]
    let dotRadius: CGFloat
    /// Alaska and Hawaii, framed on the US maps.
    let insets: [CGRect]
    let outlying: [Outlying]

    /// - Parameters:
    ///   - places: The category's places.
    ///   - states: State outlines, drawn under the parks.
    init(category: PlaceCategory, places: [Place], states: [Place], visitedCodes: Set<String>, width: CGFloat) {
        switch category {
        case .country:
            self = Self.world(places, visitedCodes: visitedCodes, width: width)
        case .state:
            self = Self.unitedStates(states: places, visitedStates: visitedCodes, parks: [], visitedParks: [], width: width)
        case .park:
            self = Self.unitedStates(states: states, visitedStates: [], parks: places, visitedParks: visitedCodes, width: width)
        }
    }

    /// Whether a year's places fit the US map: some states or parks, and no
    /// country but the US itself.
    static func isUnitedStatesOnly(_ places: [Place]) -> Bool {
        places.contains { $0.category != .country }
            && !places.contains { $0.category == .country && $0.id.code != "US" }
    }

    /// One year's places, all filled: the US map (with only that year's
    /// parks) when they fit it, otherwise the world, where states and parks
    /// light up the United States.
    static func year(_ places: [Place], states: [Place], countries: [Place], width: (_ isUnitedStates: Bool) -> CGFloat) -> PosterMap {
        let codes = { (category: PlaceCategory) in Set(places.filter { $0.category == category }.map(\.id.code)) }
        if isUnitedStatesOnly(places) {
            let parks = places.filter { $0.category == .park }
            return unitedStates(states: states, visitedStates: codes(.state), parks: parks, visitedParks: codes(.park), width: width(true))
        }
        var visitedCountries = codes(.country)
        if places.contains(where: { $0.category != .country }) {
            visitedCountries.insert("US")
        }
        return world(countries, visitedCodes: visitedCountries, width: width(false))
    }

    private init(size: CGSize, areas: [Area], dots: [Dot], dotRadius: CGFloat, insets: [CGRect], outlying: [Outlying]) {
        self.size = size
        self.areas = areas
        self.dots = dots
        self.dotRadius = dotRadius
        self.insets = insets
        self.outlying = outlying
    }

    // MARK: World

    /// Countries too small to see at this width (narrower than this many
    /// points) get a dot when visited.
    static let smallestVisibleArea: CGFloat = 3

    private static func world(_ countries: [Place], visitedCodes: Set<String>, width: CGFloat) -> PosterMap {
        // Antarctica takes a lot of room; only show it to people who went.
        let shown = countries.filter { $0.id.code != "AQ" || visitedCodes.contains("AQ") }
        let projected = shown.map { (place: $0, rings: rings(of: $0, MapProjection.equalEarth)) }
        let fit = Fit(bounds: bounds(of: projected.flatMap(\.rings)), width: width)

        var areas: [Area] = []
        var dots: [Dot] = []
        for (place, rings) in projected {
            let isVisited = visitedCodes.contains(place.id.code)
            let placed = rings.map { $0.map(fit.point) }
            areas.append(Area(placeID: place.id, rings: placed, isVisited: isVisited))
            let extent = bounds(of: placed)
            if isVisited, max(extent.width, extent.height) < smallestVisibleArea {
                dots.append(Dot(placeID: place.id, center: fit.point(MapProjection.equalEarth(place.labelCoordinate)), isVisited: true))
            }
        }
        return PosterMap(size: fit.size, areas: areas, dots: dots, dotRadius: 2, insets: [], outlying: [])
    }

    // MARK: United States

    enum Region: Equatable {
        case lower48, alaska, hawaii, outlying

        init(stateCode: String?) {
            switch stateCode {
            case "AK": self = .alaska
            case "HI": self = .hawaii
            case "AS", "VI": self = .outlying
            default: self = .lower48
            }
        }

        var projection: MapProjection.Albers {
            switch self {
            case .alaska: .alaska
            case .hawaii: .hawaii
            case .lower48, .outlying: .lower48
            }
        }
    }

    private static func unitedStates(states: [Place], visitedStates statesVisited: Set<String>, parks: [Place], visitedParks visitedCodes: Set<String>, width: CGFloat) -> PosterMap {
        let dotRadius = (width * 0.0125).rounded(.up)
        func region(of place: Place) -> Region {
            Region(stateCode: place.category == .state ? place.id.code : place.stateCodes.first)
        }

        // The lower 48 span the full width.
        let mainStates = states.filter { region(of: $0) == .lower48 }
        let mainRings = mainStates.map { rings(of: $0, Region.lower48.projection.project) }
        let main = Fit(bounds: bounds(of: mainRings.flatMap { $0 }), width: width)

        var areas = zip(mainStates, mainRings).map { state, rings in
            Area(placeID: state.id, rings: rings.map { $0.map(main.point) }, isVisited: statesVisited.contains(state.id.code))
        }
        var dots = parks.filter { region(of: $0) == .lower48 }.map { park in
            Dot(placeID: park.id, center: main.point(Region.lower48.projection.project(park.labelCoordinate)), isVisited: visitedCodes.contains(park.id.code))
        }

        // Alaska and Hawaii sit in boxes under the southwest, raised as high
        // as they go without covering anything.
        let obstacles = areas.flatMap { $0.rings.joined() } + dots.map(\.center)
        let insetRegions: [(region: Region, maxSize: CGSize)] = [
            (.alaska, CGSize(width: width * 0.27, height: main.size.height * 0.3)),
            (.hawaii, CGSize(width: width * 0.19, height: main.size.height * 0.16)),
        ]
        var boxes: [(region: Region, fit: Fit)] = []
        for (insetRegion, maxSize) in insetRegions {
            let regionStates = states.filter { region(of: $0) == insetRegion }
            let regionRings = regionStates.flatMap { rings(of: $0, insetRegion.projection.project) }
            guard !regionRings.isEmpty else { continue }
            boxes.append((insetRegion, Fit(bounds: bounds(of: regionRings), fitting: maxSize, padding: 4)))
        }
        let frames = insetFrames(sizes: boxes.map(\.fit.size), below: main.size.height, avoiding: obstacles, margin: dotRadius + 3)

        for ((insetRegion, fit), frame) in zip(boxes, frames) {
            let offset = CGPoint(x: frame.minX, y: frame.minY)
            func place(_ coordinate: Coordinate) -> CGPoint {
                let point = fit.point(insetRegion.projection.project(coordinate))
                return CGPoint(x: point.x + offset.x, y: point.y + offset.y)
            }
            for state in states where region(of: state) == insetRegion {
                let placed = (state.boundary ?? []).flatMap { [$0.exterior] + $0.holes }.map { $0.map(place) }
                areas.append(Area(placeID: state.id, rings: placed, isVisited: statesVisited.contains(state.id.code)))
            }
            for park in parks where region(of: park) == insetRegion {
                dots.append(Dot(placeID: park.id, center: place(park.labelCoordinate), isVisited: visitedCodes.contains(park.id.code)))
            }
        }

        let outlying = parks.filter { region(of: $0) == .outlying }.map {
            Outlying(place: $0, isVisited: visitedCodes.contains($0.id.code))
        }
        let height = max(main.size.height, frames.map(\.maxY).max() ?? 0).rounded(.up)
        return PosterMap(
            size: CGSize(width: width, height: height),
            areas: areas,
            dots: dots,
            dotRadius: dotRadius,
            insets: frames,
            outlying: outlying
        )
    }

    /// Lays boxes left to right, bottom-aligned, starting just below the main
    /// map and moving up a point at a time until one would cover an obstacle.
    static func insetFrames(sizes: [CGSize], below mainHeight: CGFloat, avoiding obstacles: [CGPoint], margin: CGFloat) -> [CGRect] {
        guard let rowHeight = sizes.map(\.height).max() else { return [] }
        let gap: CGFloat = 6
        func frames(top: CGFloat) -> [CGRect] {
            var x: CGFloat = 0
            return sizes.map { size in
                defer { x += size.width + gap }
                return CGRect(x: x, y: top + rowHeight - size.height, width: size.width, height: size.height)
            }
        }
        func isClear(_ frames: [CGRect]) -> Bool {
            let padded = frames.map { $0.insetBy(dx: -margin, dy: -margin) }
            return !obstacles.contains { point in padded.contains { $0.contains(point) } }
        }

        var top = mainHeight + gap
        while top > mainHeight * 0.3, isClear(frames(top: top - 1)) {
            top -= 1
        }
        return frames(top: top)
    }

    // MARK: Helpers

    private static func rings(of place: Place, _ project: (Coordinate) -> CGPoint) -> [[CGPoint]] {
        (place.boundary ?? []).flatMap { [$0.exterior] + $0.holes }.map { $0.map(project) }
    }

    private static func bounds(of rings: [[CGPoint]]) -> CGRect {
        let points = rings.joined()
        guard let first = points.first else { return .zero }
        var minX = first.x, maxX = first.x, minY = first.y, maxY = first.y
        for point in points {
            minX = min(minX, point.x); maxX = max(maxX, point.x)
            minY = min(minY, point.y); maxY = max(maxY, point.y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// Scales projected (y-up) bounds into a box of points (y-down).
    private struct Fit {
        let bounds: CGRect
        let scale: CGFloat
        let padding: CGFloat
        let size: CGSize

        /// Fills `width`; the height follows.
        init(bounds: CGRect, width: CGFloat) {
            self.bounds = bounds
            scale = bounds.width > 0 ? width / bounds.width : 0
            padding = 0
            size = CGSize(width: width, height: bounds.height * scale)
        }

        /// As large as fits in `maxSize`, keeping the shape.
        init(bounds: CGRect, fitting maxSize: CGSize, padding: CGFloat) {
            self.bounds = bounds
            let inner = CGSize(width: maxSize.width - 2 * padding, height: maxSize.height - 2 * padding)
            scale = min(inner.width / max(bounds.width, .ulpOfOne), inner.height / max(bounds.height, .ulpOfOne))
            self.padding = padding
            size = CGSize(width: bounds.width * scale + 2 * padding, height: bounds.height * scale + 2 * padding)
        }

        func point(_ projected: CGPoint) -> CGPoint {
            CGPoint(x: padding + (projected.x - bounds.minX) * scale, y: padding + (bounds.maxY - projected.y) * scale)
        }
    }
}
