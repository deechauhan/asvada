import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// A photo made ready to keep: a downscaled copy, a thumbnail, and when and where it was taken.
public struct ProcessedPhoto: Sendable, Equatable {
    /// The kept copy, at most `PhotoProcessor.maximumPixelSize` on its long edge.
    public let imageData: Data
    /// A small copy for lists, keepsakes and map pins.
    public let thumbnailData: Data
    /// When it was taken, from the photo's own metadata.
    public let takenAt: Date?
    /// Where it was taken, from the photo's GPS metadata.
    public let latitude: Double?
    public let longitude: Double?
}

/// Turns a picked photo (any format ImageIO reads: HEIC, JPEG, PNG…) into the copies Artifacts keeps.
///
/// Photos are stored in the app, never as Photos-library references, so they survive the
/// original being deleted and travel with backups. The kept copies are re-encoded from pixels
/// alone: camera, GPS and other metadata are not carried over (the date and place are kept as
/// fields instead). Orientation is applied to the pixels. Runs off the main actor.
public enum PhotoProcessor {
    /// The long edge of the kept copy, in pixels: sharp full-screen on any iPhone, about 0.5 MB.
    public static let maximumPixelSize = 2048
    /// The long edge of the thumbnail, in pixels.
    public static let thumbnailPixelSize = 400
    /// JPEG/HEIC quality for both copies.
    static let quality = 0.8

    public enum ProcessingError: Error, Equatable {
        /// The data isn't an image ImageIO can read.
        case unreadable
        /// Encoding the downscaled copy failed.
        case encodingFailed
    }

    /// Downscales `data`, makes its thumbnail and reads its date and place.
    public static func process(_ data: Data) throws -> ProcessedPhoto {
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            CGImageSourceGetCount(source) > 0
        else { throw ProcessingError.unreadable }
        let image = try encoded(source, maximumPixelSize: maximumPixelSize)
        let thumbnail = try encoded(source, maximumPixelSize: thumbnailPixelSize)
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
        let place = PhotoMetadata.coordinate(in: properties)
        return ProcessedPhoto(
            imageData: image,
            thumbnailData: thumbnail,
            takenAt: PhotoMetadata.date(in: properties),
            latitude: place?.latitude,
            longitude: place?.longitude,
        )
    }

    /// The image redrawn upright at no more than `maximumPixelSize` on its long edge (never
    /// upscaled), encoded as HEIC where the device can, otherwise JPEG.
    private static func encoded(_ source: CGImageSource, maximumPixelSize: Int) throws -> Data {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw ProcessingError.unreadable
        }
        for type in [UTType.heic, UTType.jpeg] {
            if let data = encode(image, as: type) {
                return data
            }
        }
        throw ProcessingError.encodingFailed
    }

    private static func encode(_ image: CGImage, as type: UTType) -> Data? {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, type.identifier as CFString, 1, nil) else {
            return nil
        }
        let options: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: quality]
        CGImageDestinationAddImage(destination, image, options as CFDictionary)
        guard CGImageDestinationFinalize(destination), output.length > 0 else { return nil }
        return output as Data
    }
}

/// Reading a photo's date and place from its EXIF and GPS dictionaries.
enum PhotoMetadata {
    /// When the photo was taken: EXIF DateTimeOriginal (or digitised, or TIFF DateTime), in the
    /// offset the camera recorded, or the device's time zone when it recorded none.
    static func date(in properties: [CFString: Any], timeZone: TimeZone = .current) -> Date? {
        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
        let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] ?? [:]
        let stamp = exif[kCGImagePropertyExifDateTimeOriginal] as? String
            ?? exif[kCGImagePropertyExifDateTimeDigitized] as? String
            ?? tiff[kCGImagePropertyTIFFDateTime] as? String
        guard let stamp else { return nil }
        let offset = exif[kCGImagePropertyExifOffsetTimeOriginal] as? String
            ?? exif[kCGImagePropertyExifOffsetTime] as? String
        let zone = offset.flatMap(Self.timeZone(fromOffset:)) ?? timeZone
        return date(fromExif: stamp, in: zone)
    }

    /// Parses "2024:05:17 18:42:07" (EXIF's format) in `zone`.
    static func date(fromExif stamp: String, in zone: TimeZone) -> Date? {
        let parts = stamp.split { $0 == ":" || $0 == " " }.compactMap { Int($0) }
        guard parts.count >= 6 else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let components = DateComponents(
            year: parts[0],
            month: parts[1],
            day: parts[2],
            hour: parts[3],
            minute: parts[4],
            second: parts[5],
        )
        guard
            (1 ... 12).contains(parts[1]), (1 ... 31).contains(parts[2]),
            (0 ... 23).contains(parts[3]), (0 ... 59).contains(parts[4]), (0 ... 60).contains(parts[5])
        else { return nil }
        return calendar.date(from: components)
    }

    /// "+05:30" or "-03:00" as a time zone.
    static func timeZone(fromOffset offset: String) -> TimeZone? {
        let trimmed = offset.trimmingCharacters(in: .whitespaces)
        guard let sign = trimmed.first, sign == "+" || sign == "-" else { return nil }
        let numbers = trimmed.dropFirst().split(separator: ":").compactMap { Int($0) }
        guard numbers.count == 2, (0 ... 14).contains(numbers[0]), (0 ... 59).contains(numbers[1]) else { return nil }
        let seconds = (numbers[0] * 3600 + numbers[1] * 60) * (sign == "-" ? -1 : 1)
        return TimeZone(secondsFromGMT: seconds)
    }

    /// Where the photo was taken, from the GPS dictionary (south and west are negative).
    static func coordinate(in properties: [CFString: Any]) -> (latitude: Double, longitude: Double)? {
        guard
            let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any],
            let latitude = (gps[kCGImagePropertyGPSLatitude] as? NSNumber)?.doubleValue,
            let longitude = (gps[kCGImagePropertyGPSLongitude] as? NSNumber)?.doubleValue
        else { return nil }
        let south = (gps[kCGImagePropertyGPSLatitudeRef] as? String)?.uppercased() == "S"
        let west = (gps[kCGImagePropertyGPSLongitudeRef] as? String)?.uppercased() == "W"
        let signed = (latitude: south ? -abs(latitude) : latitude, longitude: west ? -abs(longitude) : longitude)
        guard (-90 ... 90).contains(signed.latitude), (-180 ... 180).contains(signed.longitude) else { return nil }
        // Cameras without a fix sometimes write 0, 0: not a real place.
        guard signed.latitude != 0 || signed.longitude != 0 else { return nil }
        return signed
    }
}
