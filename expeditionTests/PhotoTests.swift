import CoreGraphics
import Foundation
import ImageIO
import SwiftData
import Testing
import UniformTypeIdentifiers
@testable import expedition

struct PhotoCompressorTests {
    /// A JPEG of the given stored size, optionally with an EXIF orientation
    /// and a GPS location, like a phone camera writes.
    private func jpeg(width: Int, height: Int, orientation: Int? = nil, withLocation: Bool = false) throws -> Data {
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        context.setFillColor(red: 0.8, green: 0.4, blue: 0.2, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(context.makeImage())

        var properties: [CFString: Any] = [:]
        if let orientation {
            properties[kCGImagePropertyOrientation] = orientation
        }
        if withLocation {
            properties[kCGImagePropertyGPSDictionary] = [
                kCGImagePropertyGPSLatitude: 37.2982, kCGImagePropertyGPSLatitudeRef: "N",
                kCGImagePropertyGPSLongitude: 113.0263, kCGImagePropertyGPSLongitudeRef: "W",
            ]
        }
        let output = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
        return output as Data
    }

    private func properties(of data: Data) throws -> [CFString: Any] {
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        return try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
    }

    private func pixelSize(of data: Data) throws -> (width: Int, height: Int) {
        let properties = try properties(of: data)
        return (try #require(properties[kCGImagePropertyPixelWidth] as? Int), try #require(properties[kCGImagePropertyPixelHeight] as? Int))
    }

    @Test func shrinksLargePhotos() throws {
        let photo = try PhotoCompressor.compress(try jpeg(width: 4032, height: 3024))

        #expect((photo.pixelWidth, photo.pixelHeight) == (2048, 1536))
        #expect(try pixelSize(of: photo.image) == (2048, 1536))
        #expect(try pixelSize(of: photo.thumbnail) == (400, 300))
    }

    @Test func neverEnlargesSmallPhotos() throws {
        let photo = try PhotoCompressor.compress(try jpeg(width: 300, height: 200))

        #expect(try pixelSize(of: photo.image) == (300, 200))
        #expect(try pixelSize(of: photo.thumbnail) == (300, 200))
    }

    /// Phones store portrait photos sideways with an orientation flag; the
    /// output is turned upright instead, since the flag isn't kept.
    @Test func appliesOrientation() throws {
        let photo = try PhotoCompressor.compress(try jpeg(width: 400, height: 300, orientation: 6))

        #expect((photo.pixelWidth, photo.pixelHeight) == (300, 400))
        #expect(try pixelSize(of: photo.image) == (300, 400))
        let orientation = try properties(of: photo.image)[kCGImagePropertyOrientation] as? Int
        #expect(orientation == nil || orientation == 1)
    }

    @Test func dropsLocation() throws {
        let original = try jpeg(width: 400, height: 300, withLocation: true)
        #expect(try properties(of: original)[kCGImagePropertyGPSDictionary] != nil, "The fixture has a location")

        let photo = try PhotoCompressor.compress(original)

        #expect(try properties(of: photo.image)[kCGImagePropertyGPSDictionary] == nil)
        #expect(try properties(of: photo.thumbnail)[kCGImagePropertyGPSDictionary] == nil)
    }

    @Test func storesMuchLessThanTheOriginal() throws {
        let photo = try PhotoCompressor.compress(try jpeg(width: 4032, height: 3024))
        #expect(photo.image.count < 1_000_000)
        #expect(photo.thumbnail.count < 100_000)
    }

    @Test func rejectsDataThatIsNotAnImage() {
        #expect(throws: PhotoCompressor.Failure.self) {
            try PhotoCompressor.compress(Data("not a photo".utf8))
        }
    }
}

@MainActor
struct PhotoLibraryTests {
    let container: ModelContainer
    let library: PhotoLibrary
    let zion = PlaceID(category: .park, code: "zion")
    let arches = PlaceID(category: .park, code: "arches")
    let photo = CompressedPhoto(image: Data([1]), thumbnail: Data([2]), pixelWidth: 4, pixelHeight: 3)

    init() throws {
        container = try ModelContainerFactory.make(inMemory: true)
        library = PhotoLibrary(context: container.mainContext)
    }

    @Test func keepsPhotosPerPlaceInTheOrderAdded() throws {
        library.now = { Date(timeIntervalSince1970: 1_000) }
        let first = CompressedPhoto(image: Data([10]), thumbnail: Data(), pixelWidth: 1, pixelHeight: 1)
        let second = CompressedPhoto(image: Data([20]), thumbnail: Data(), pixelWidth: 1, pixelHeight: 1)
        try library.add([first, second], to: zion)
        library.now = { Date(timeIntervalSince1970: 2_000) }
        let third = CompressedPhoto(image: Data([30]), thumbnail: Data(), pixelWidth: 1, pixelHeight: 1)
        try library.add([third], to: zion)
        try library.add([photo], to: arches)

        #expect(try library.photos(for: zion).map(\.imageData) == [Data([10]), Data([20]), Data([30])])
        #expect(try library.photos(for: arches).count == 1)
    }

    @Test func stopsAtTheLimit() throws {
        try library.add(Array(repeating: photo, count: PhotoLibrary.limit - 2), to: zion)
        #expect(try library.remainingSlots(for: zion) == 2)

        #expect(try library.add(Array(repeating: photo, count: 5), to: zion) == 2)
        #expect(try library.photos(for: zion).count == PhotoLibrary.limit)
        #expect(try library.remainingSlots(for: zion) == 0)
        #expect(try library.add([photo], to: zion) == 0)
        #expect(try library.remainingSlots(for: arches) == PhotoLibrary.limit, "The limit is per place")
    }

    @Test func deletes() throws {
        try library.add([photo, photo], to: zion)
        try library.delete(try #require(try library.photos(for: zion).first))

        #expect(try library.photos(for: zion).count == 1)
        #expect(try library.remainingSlots(for: zion) == PhotoLibrary.limit - 1)
    }

    @Test func photosStayWhenThePlaceIsUnmarked() throws {
        let store = PlaceEntryStore(context: container.mainContext)
        try store.setVisited(true, for: zion)
        try library.add([photo], to: zion)
        try store.setVisited(false, for: zion)

        #expect(try library.photos(for: zion).count == 1)
    }

    @Test func sampleDataHasPhotos() throws {
        let sample = PreviewSupport.container()
        let photos = try PhotoLibrary(context: sample.mainContext).photos(for: zion)
        #expect(photos.count == PreviewSupport.samplePhotos.count)
        #expect(photos.allSatisfy { $0.thumbnailData != nil && $0.imageData != nil })
    }
}
