import Foundation
import ImageIO
import UniformTypeIdentifiers

/// A picked photo, shrunk and re-encoded for storage.
nonisolated struct CompressedPhoto: Sendable {
    var image: Data
    var thumbnail: Data
    var pixelWidth: Int
    var pixelHeight: Int
}

/// Shrinks picked photos to a size worth syncing. The output is upright
/// (EXIF orientation applied) and carries no metadata, so a photo's location
/// and camera details never leave the device.
nonisolated enum PhotoCompressor {
    static let maxPixelSize = 2048
    static let thumbnailPixelSize = 400

    enum Failure: Error {
        case unreadable
        case encodingFailed
    }

    /// Compresses off the main actor; decoding a 48 MP photo takes a moment.
    @concurrent
    static func compressed(_ data: Data) async throws -> CompressedPhoto {
        try compress(data)
    }

    static func compress(_ data: Data) throws -> CompressedPhoto {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int
        else { throw Failure.unreadable }

        let longEdge = max(width, height)
        let image = try downsampled(source, to: min(longEdge, maxPixelSize))
        let thumbnail = try downsampled(source, to: min(longEdge, thumbnailPixelSize))
        return CompressedPhoto(
            image: try encoded(image, quality: 0.75),
            thumbnail: try encoded(thumbnail, quality: 0.7),
            pixelWidth: image.width,
            pixelHeight: image.height
        )
    }

    /// Never enlarges: callers pass at most the original long edge.
    private static func downsampled(_ source: CGImageSource, to pixelSize: Int) throws -> CGImage {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: pixelSize,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw Failure.unreadable
        }
        return image
    }

    /// HEIC where the device can encode it (about half the size of JPEG),
    /// otherwise JPEG. No metadata is written.
    private static func encoded(_ image: CGImage, quality: Double) throws -> Data {
        for type in [UTType.heic, .jpeg] {
            let output = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(output, type.identifier as CFString, 1, nil) else {
                continue
            }
            let options = [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
            CGImageDestinationAddImage(destination, image, options)
            if CGImageDestinationFinalize(destination) {
                return output as Data
            }
        }
        throw Failure.encodingFailed
    }
}
