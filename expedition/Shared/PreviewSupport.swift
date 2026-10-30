#if DEBUG
import ImageIO
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// In-memory data for SwiftUI Previews.
enum PreviewSupport {
    static let visitedSample: [PlaceID] = [
        PlaceID(category: .park, code: "zion"),
        PlaceID(category: .park, code: "yosemite"),
        PlaceID(category: .park, code: "grand-canyon"),
        PlaceID(category: .park, code: "arches"),
        PlaceID(category: .state, code: "UT"),
        PlaceID(category: .state, code: "CA"),
        PlaceID(category: .state, code: "AZ"),
        PlaceID(category: .state, code: "CO"),
        PlaceID(category: .country, code: "JP"),
        PlaceID(category: .country, code: "FR"),
        PlaceID(category: .country, code: "PE"),
        PlaceID(category: .country, code: "IS"),
    ]

    /// One of each precision, single dates and ranges.
    static let sampleVisits: [(PlaceID, [Visit])] = [
        (PlaceID(category: .park, code: "zion"), [
            Visit(start: VisitDate(year: 2023, month: 10, day: 12), end: VisitDate(year: 2023, month: 10, day: 15)),
            Visit(start: VisitDate(year: 2016)),
        ]),
        (PlaceID(category: .park, code: "yosemite"), [Visit(start: VisitDate(year: 2021, month: 6))]),
        (PlaceID(category: .park, code: "grand-canyon"), [Visit(start: VisitDate(year: 2019))]),
        (PlaceID(category: .state, code: "UT"), [Visit(start: VisitDate(year: 2023, month: 10))]),
        (PlaceID(category: .state, code: "AZ"), [Visit(start: VisitDate(year: 2019))]),
        (PlaceID(category: .country, code: "JP"), [
            Visit(start: VisitDate(year: 2024, month: 4, day: 2), end: VisitDate(year: 2024, month: 4, day: 12)),
        ]),
        (PlaceID(category: .country, code: "FR"), [
            Visit(start: VisitDate(year: 2019, month: 5), end: VisitDate(year: 2019, month: 6)),
        ]),
        (PlaceID(category: .country, code: "IS"), [Visit(start: VisitDate(year: 2022, month: 9, day: 8))]),
    ]

    /// An in-memory container, optionally filled with sample visited places.
    static func container(withSampleData: Bool = true) -> ModelContainer {
        do {
            let container = try ModelContainerFactory.make(inMemory: true)
            if withSampleData {
                let store = PlaceEntryStore(context: container.mainContext)
                for id in visitedSample {
                    try store.setVisited(true, for: id)
                }
                let zion = try store.entryOrCreate(for: PlaceID(category: .park, code: "zion"))
                zion.notes = "Hiked the Narrows in October. Cold water, golden cottonwoods."
                zion.favorites = [
                    FavoriteItem(name: "The Narrows", url: URL(string: "https://www.alltrails.com/trail/us/utah/the-narrows-bottom-up-to-big-springs")),
                    FavoriteItem(name: "Angels Landing"),
                ]
                zion.memories = [Memory(text: "Bighorn sheep on the switchbacks")]
                // Some visited places are left undated to fill "No Dates Yet".
                for (id, visits) in sampleVisits {
                    try store.entryOrCreate(for: id).visits = visits
                }
                try container.mainContext.save()
                try PhotoLibrary(context: container.mainContext).add(
                    samplePhotos.map(PhotoCompressor.compress),
                    to: PlaceID(category: .park, code: "zion")
                )
            }
            return container
        } catch {
            fatalError("Preview container failed: \(error)")
        }
    }

    /// Drawn in code so no sample images ship in the app: a portrait and two
    /// landscapes, as JPEG like the photo picker would hand over.
    static var samplePhotos: [Data] {
        [(0.05, CGSize(width: 1200, height: 900)), (0.55, CGSize(width: 900, height: 1200)), (0.3, CGSize(width: 1600, height: 900))]
            .map { hue, size in samplePhoto(hue: hue, size: size) }
    }

    /// Core Graphics only: UIKit drawing here would run during app launch
    /// (with `-UseSampleData`) and settle the tint before the accent color.
    private static func samplePhoto(hue: CGFloat, size: CGSize) -> Data {
        let width = Int(size.width), height = Int(size.height)
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return Data() }

        // Sky, bottom to top (Core Graphics' origin is the bottom left).
        let sky = [color(hue: hue + 0.05, saturation: 0.7, brightness: 0.45), color(hue: hue, saturation: 0.45, brightness: 0.95)]
        if let gradient = CGGradient(colorsSpace: nil, colors: sky as CFArray, locations: nil) {
            context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
        }
        // Two ridges.
        for (peak, shade) in [(0.35, 0.3), (0.7, 0.18)] {
            context.setFillColor(color(hue: hue + 0.08, saturation: 0.5, brightness: shade))
            context.move(to: CGPoint(x: size.width * (peak - 0.45), y: 0))
            context.addLine(to: CGPoint(x: size.width * peak, y: size.height * 0.6))
            context.addLine(to: CGPoint(x: size.width * (peak + 0.45), y: 0))
            context.fillPath()
        }

        let output = NSMutableData()
        guard let image = context.makeImage(),
              let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil)
        else { return Data() }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination) ? output as Data : Data()
    }

    private static func color(hue: CGFloat, saturation: CGFloat, brightness: CGFloat) -> CGColor {
        // HSB to RGB, enough for sample art.
        let h = (hue.truncatingRemainder(dividingBy: 1)) * 6
        let c = brightness * saturation
        let x = c * (1 - abs(h.truncatingRemainder(dividingBy: 2) - 1))
        let (r, g, b): (CGFloat, CGFloat, CGFloat) = switch Int(h) {
        case 0: (c, x, 0)
        case 1: (x, c, 0)
        case 2: (0, c, x)
        case 3: (0, x, c)
        case 4: (x, 0, c)
        default: (c, 0, x)
        }
        let m = brightness - c
        return CGColor(red: r + m, green: g + m, blue: b + m, alpha: 1)
    }

    static func referenceData() -> ReferenceDataStore {
        let store = ReferenceDataStore()
        do {
            try store.loadSynchronously()
        } catch {
            fatalError("Preview reference data failed: \(error)")
        }
        return store
    }
}

extension View {
    /// Supplies the model container and reference data views expect.
    func previewEnvironment(withSampleData: Bool = true) -> some View {
        modelContainer(PreviewSupport.container(withSampleData: withSampleData))
            .environment(PreviewSupport.referenceData())
            .environment(SyncMonitor())
    }
}
#endif
