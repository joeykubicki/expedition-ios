import ImageIO
import SwiftUI
import UniformTypeIdentifiers

/// The share image: an atlas plate with the title, progress, and map. Laid
/// out at a fixed point size and rendered at `scale` for a 2160 × 2700 pixel
/// (4:5) image. Always light, and with Dynamic Type pinned, so every shared
/// image looks the same whatever the device's settings.
struct MapPoster: View {
    static let size = CGSize(width: 400, height: 500)
    static let scale: CGFloat = 5.4
    /// The world is wide and short, so it gets nearly the full plate.
    static func mapWidth(for category: PlaceCategory) -> CGFloat {
        category == .country ? 368 : 356
    }

    let category: PlaceCategory
    let progress: CategoryProgress
    let map: PosterMap
    let date: Date

    init(category: PlaceCategory, referenceData: ReferenceDataStore, visitedCodes: Set<String>, date: Date = .now) {
        let places = referenceData.places(in: category)
        self.category = category
        progress = CategoryProgress(category: category, places: places, visitedCodes: visitedCodes)
        map = PosterMap(category: category, places: places, states: referenceData.states, visitedCodes: visitedCodes, width: Self.mapWidth(for: category))
        self.date = date
    }

    var title: LocalizedStringResource {
        switch category {
        case .park: "My National Parks"
        case .state: "My States"
        case .country: "My Countries"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 30)
                .padding(.top, 32)
            Spacer(minLength: 12)
            PosterMapCanvas(map: map, category: category)
                .frame(width: map.size.width, height: map.size.height)
            if !map.outlying.isEmpty {
                outlyingParks
                    .frame(width: map.size.width, alignment: .trailing)
                    .padding(.top, 6)
            }
            Spacer(minLength: 12)
            footer
                .padding(.horizontal, 30)
                .padding(.bottom, 28)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .background(Color.paper)
        .overlay {
            // A double rule around the plate, like an old atlas page.
            Rectangle().strokeBorder(Color.boundary, lineWidth: 1).padding(10)
            Rectangle().strokeBorder(Color.boundary.opacity(0.6), lineWidth: 0.5).padding(14)
        }
        .environment(\.colorScheme, .light)
        .dynamicTypeSize(.large)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("EXPEDITION")
                .font(.caption2.weight(.semibold))
                .tracking(2)
                .foregroundStyle(Color.inkSoft)
            Text(title)
                .font(.title.weight(.semibold))
                .fontDesign(.serif)
                .foregroundStyle(Color.ink)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(progress.visited, format: .number)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(category.visitedColor)
                Text("of \(progress.total) \(category.pluralNoun)")
                    .font(.title3)
                    .foregroundStyle(Color.inkSoft)
                Spacer(minLength: 0)
                Text(progress.fraction, format: .percent.precision(.fractionLength(0)))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.ink)
            }
            .fontDesign(.serif)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var outlyingParks: some View {
        HStack(spacing: 10) {
            ForEach(map.outlying, id: \.place.id) { park in
                HStack(spacing: 4) {
                    PosterDot(isVisited: park.isVisited, color: category.visitedColor, radius: map.dotRadius)
                    Text(park.place.name)
                        .font(.caption2)
                        .foregroundStyle(Color.inkSoft)
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 14) {
            legendItem(isVisited: true, label: "Visited")
            legendItem(isVisited: false, label: "Not yet")
            Spacer(minLength: 0)
            Text(date, format: .dateTime.month(.wide).year())
                .font(.caption)
                .foregroundStyle(Color.inkSoft)
        }
    }

    private func legendItem(isVisited: Bool, label: LocalizedStringResource) -> some View {
        HStack(spacing: 5) {
            if category == .park {
                PosterDot(isVisited: isVisited, color: category.visitedColor, radius: map.dotRadius)
            } else {
                RoundedRectangle(cornerRadius: 2)
                    .fill(isVisited ? category.visitedColor : Color.land)
                    .strokeBorder(Color.boundary, lineWidth: 0.5)
                    .frame(width: 14, height: 10)
            }
            Text(label)
                .font(.caption)
                .foregroundStyle(Color.ink)
        }
    }
}

/// The map itself: land, visited fills, inset frames, and dots on top.
private struct PosterMapCanvas: View {
    let map: PosterMap
    let category: PlaceCategory

    var body: some View {
        Canvas { context, _ in
            for inset in map.insets {
                context.stroke(Path(roundedRect: inset, cornerRadius: 3), with: .color(.boundary), lineWidth: 0.6)
            }
            for area in map.areas {
                var path = Path()
                for ring in area.rings where ring.count > 2 {
                    path.addLines(ring)
                    path.closeSubpath()
                }
                context.fill(path, with: .color(area.isVisited ? category.visitedColor : .land), style: FillStyle(eoFill: true))
                context.stroke(path, with: .color(.boundary), lineWidth: 0.35)
            }
            // Visited dots on top where parks crowd together.
            for dot in map.dots.sorted(by: { !$0.isVisited && $1.isVisited }) {
                PosterDot.draw(in: context, at: dot.center, radius: map.dotRadius, isVisited: dot.isVisited, color: category.visitedColor)
            }
        }
    }
}

/// Filled with a check when visited, hollow when not: a shape difference,
/// not just a color one.
private struct PosterDot: View {
    let isVisited: Bool
    let color: Color
    let radius: CGFloat

    var body: some View {
        Canvas { context, size in
            Self.draw(in: context, at: CGPoint(x: size.width / 2, y: size.height / 2), radius: radius, isVisited: isVisited, color: color)
        }
        .frame(width: radius * 2 + 2, height: radius * 2 + 2)
    }

    static func draw(in context: GraphicsContext, at center: CGPoint, radius: CGFloat, isVisited: Bool, color: Color) {
        let circle = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        if isVisited {
            context.fill(circle, with: .color(color))
            context.stroke(circle, with: .color(.paper), lineWidth: 0.6)
            guard radius >= 3 else { return }
            var check = Path()
            check.move(to: CGPoint(x: center.x - radius * 0.45, y: center.y + radius * 0.02))
            check.addLine(to: CGPoint(x: center.x - radius * 0.12, y: center.y + radius * 0.35))
            check.addLine(to: CGPoint(x: center.x + radius * 0.45, y: center.y - radius * 0.32))
            context.stroke(check, with: .color(.white), style: StrokeStyle(lineWidth: radius * 0.28, lineCap: .round, lineJoin: .round))
        } else {
            context.fill(circle, with: .color(.paper))
            context.stroke(circle, with: .color(color), lineWidth: 1)
        }
    }
}

/// Turns a poster into a PNG.
enum PosterRenderer {
    static func image(of poster: MapPoster) -> CGImage? {
        let renderer = ImageRenderer(content: poster)
        renderer.scale = MapPoster.scale
        renderer.isOpaque = true
        return renderer.cgImage
    }

    @concurrent
    nonisolated static func png(_ image: CGImage) async -> Data? {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination) ? output as Data : nil
    }
}

#if DEBUG
private struct MapPosterPreview: View {
    let category: PlaceCategory
    var visited = true
    @Environment(ReferenceDataStore.self) private var referenceData

    var body: some View {
        let codes = visited ? Set(PreviewSupport.visitedSample.filter { $0.category == category }.map(\.code)) : []
        MapPoster(category: category, referenceData: referenceData, visitedCodes: codes)
            .scaleEffect(0.8)
    }
}

#Preview("Parks") {
    MapPosterPreview(category: .park)
        .previewEnvironment()
}

#Preview("States") {
    MapPosterPreview(category: .state)
        .previewEnvironment()
}

#Preview("Countries") {
    MapPosterPreview(category: .country)
        .previewEnvironment()
}

#Preview("Nothing visited") {
    MapPosterPreview(category: .park, visited: false)
        .previewEnvironment()
}
#endif
