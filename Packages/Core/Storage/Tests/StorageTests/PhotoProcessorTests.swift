import CoreGraphics
import Foundation
import ImageIO
import Model
import SwiftData
import Testing
import UniformTypeIdentifiers
@testable import Storage

/// Builds real image files in memory, with whatever metadata a test needs.
enum TestImage {
    /// A `width` × `height` JPEG (or PNG), optionally carrying EXIF/GPS/orientation properties.
    static func make(width: Int, height: Int, type: UTType = .jpeg, properties: [CFString: Any] = [:]) throws -> Data {
        let context = try #require(CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue,
        ))
        // Plum top half, saffron bottom half: enough structure to survive compression.
        context.setFillColor(CGColor(red: 0.42, green: 0.18, blue: 0.55, alpha: 1))
        context.fill(CGRect(x: 0, y: height / 2, width: width, height: height - height / 2))
        context.setFillColor(CGColor(red: 0.95, green: 0.66, blue: 0.23, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height / 2))
        let image = try #require(context.makeImage())
        let output = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(output, type.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
        return output as Data
    }

    /// The pixel size of encoded image data.
    static func size(of data: Data) throws -> (width: Int, height: Int) {
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        return (image.width, image.height)
    }

    /// The top-level metadata dictionaries of encoded image data.
    static func properties(of data: Data) throws -> [CFString: Any] {
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        return CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
    }
}

struct PhotoProcessorTests {
    private let lisbon: [CFString: Any] = [
        kCGImagePropertyExifDictionary: [
            kCGImagePropertyExifDateTimeOriginal: "2024:05:17 18:42:07",
            kCGImagePropertyExifOffsetTimeOriginal: "+01:00",
        ] as [CFString: Any],
        kCGImagePropertyGPSDictionary: [
            kCGImagePropertyGPSLatitude: 38.7139,
            kCGImagePropertyGPSLatitudeRef: "N",
            kCGImagePropertyGPSLongitude: 9.1394,
            kCGImagePropertyGPSLongitudeRef: "W",
        ] as [CFString: Any],
    ]

    @Test func downscalesTheKeptCopyAndTheThumbnail() throws {
        let data = try TestImage.make(width: 4000, height: 3000)
        let photo = try PhotoProcessor.process(data)
        let kept = try TestImage.size(of: photo.imageData)
        let thumbnail = try TestImage.size(of: photo.thumbnailData)
        #expect(max(kept.width, kept.height) == PhotoProcessor.maximumPixelSize)
        #expect(kept.width == 2048 && kept.height == 1536)
        #expect(max(thumbnail.width, thumbnail.height) == PhotoProcessor.thumbnailPixelSize)
    }

    @Test func neverUpscalesASmallPhoto() throws {
        let photo = try PhotoProcessor.process(TestImage.make(width: 640, height: 480, type: .png))
        let kept = try TestImage.size(of: photo.imageData)
        #expect(kept.width == 640 && kept.height == 480)
    }

    @Test func readsWhenAndWhereFromMetadata() throws {
        let photo = try PhotoProcessor.process(TestImage.make(width: 800, height: 600, properties: lisbon))
        // 18:42:07 at UTC+1 is 17:42:07 UTC.
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = try #require(TimeZone(identifier: "UTC"))
        let expected = utc.date(from: DateComponents(year: 2024, month: 5, day: 17, hour: 17, minute: 42, second: 7))
        #expect(photo.takenAt == expected)
        let latitude = try #require(photo.latitude)
        let longitude = try #require(photo.longitude)
        #expect(abs(latitude - 38.7139) < 0.0001)
        #expect(abs(longitude + 9.1394) < 0.0001, "West is negative")
    }

    @Test func keptCopiesCarryNoCameraOrLocationMetadata() throws {
        let photo = try PhotoProcessor.process(TestImage.make(width: 800, height: 600, properties: lisbon))
        for data in [photo.imageData, photo.thumbnailData] {
            let properties = try TestImage.properties(of: data)
            #expect(properties[kCGImagePropertyGPSDictionary] == nil)
            let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
            #expect(exif[kCGImagePropertyExifDateTimeOriginal] == nil)
        }
    }

    @Test func appliesOrientationToThePixels() throws {
        // Stored landscape, but the camera says "rotate 90° clockwise to view" (EXIF 6).
        let rotated: [CFString: Any] = [kCGImagePropertyOrientation: CGImagePropertyOrientation.right.rawValue]
        let photo = try PhotoProcessor.process(TestImage.make(width: 3000, height: 2000, properties: rotated))
        let kept = try TestImage.size(of: photo.imageData)
        #expect(kept.width < kept.height, "Upright portrait, got \(kept.width)×\(kept.height)")
        let orientation = try TestImage.properties(of: photo.imageData)[kCGImagePropertyOrientation] as? UInt32
        #expect(orientation == nil || orientation == CGImagePropertyOrientation.up.rawValue)
    }

    @Test func aPhotoWithoutMetadataHasNoDateOrPlace() throws {
        let photo = try PhotoProcessor.process(TestImage.make(width: 300, height: 200))
        #expect(photo.takenAt == nil)
        #expect(photo.latitude == nil && photo.longitude == nil)
    }

    @Test func notAnImageThrows() {
        #expect(throws: PhotoProcessor.ProcessingError.unreadable) {
            try PhotoProcessor.process(Data("not a photo".utf8))
        }
    }
}

struct PhotoMetadataTests {
    @Test func parsesExifDatesInTheGivenZone() throws {
        let tokyo = try #require(TimeZone(identifier: "Asia/Tokyo"))
        let date = try #require(PhotoMetadata.date(fromExif: "2023:11:02 09:15:00", in: tokyo))
        #expect(date.timeIntervalSince1970 == 1_698_884_100)
    }

    @Test(arguments: ["", "2023:11:02", "2023:13:02 09:15:00", "2023:11:02 25:00:00", "0000:00:00 00:00:00"])
    func rejectsMalformedDates(stamp: String) throws {
        let utc = try #require(TimeZone(identifier: "UTC"))
        #expect(PhotoMetadata.date(fromExif: stamp, in: utc) == nil)
    }

    @Test func fallsBackToTheDeviceZoneWithoutAnOffset() throws {
        let kolkata = try #require(TimeZone(identifier: "Asia/Kolkata"))
        let properties: [CFString: Any] = [
            kCGImagePropertyExifDictionary: [kCGImagePropertyExifDateTimeOriginal: "2023:11:02 09:15:00"] as [CFString: Any],
        ]
        let date = try #require(PhotoMetadata.date(in: properties, timeZone: kolkata))
        #expect(date.timeIntervalSince1970 == 1_698_896_700)
    }

    @Test(arguments: [("+05:30", 19800), ("-03:00", -10800), ("+00:00", 0)])
    func readsOffsets(offset: String, seconds: Int) {
        #expect(PhotoMetadata.timeZone(fromOffset: offset)?.secondsFromGMT() == seconds)
    }

    @Test(arguments: ["05:30", "+5", "+25:00", "Z"])
    func rejectsMalformedOffsets(offset: String) {
        #expect(PhotoMetadata.timeZone(fromOffset: offset) == nil)
    }

    @Test func zeroZeroIsNoPlace() {
        let properties: [CFString: Any] = [
            kCGImagePropertyGPSDictionary: [
                kCGImagePropertyGPSLatitude: 0.0,
                kCGImagePropertyGPSLongitude: 0.0,
            ] as [CFString: Any],
        ]
        #expect(PhotoMetadata.coordinate(in: properties) == nil)
    }

    @Test func southIsNegative() throws {
        let properties: [CFString: Any] = [
            kCGImagePropertyGPSDictionary: [
                kCGImagePropertyGPSLatitude: 33.8568,
                kCGImagePropertyGPSLatitudeRef: "S",
                kCGImagePropertyGPSLongitude: 151.2153,
                kCGImagePropertyGPSLongitudeRef: "E",
            ] as [CFString: Any],
        ]
        let sydney = try #require(PhotoMetadata.coordinate(in: properties))
        #expect(sydney.latitude == -33.8568)
        #expect(sydney.longitude == 151.2153)
    }
}

@MainActor
struct PhotoAttachTests {
    @Test func attachedPhotosBelongToTheEntryInTakenOrder() throws {
        let container = try ArtifactsStore.makeContainer(.inMemory)
        let repository = Repository(context: container.mainContext)
        try BuiltInCollections.seedIfNeeded(in: repository.context)
        let match = try repository.collections().first { $0.kind == .cafes }
        let cafes = try #require(match)
        let entry = repository.addEntry(to: repository.upsertItem(named: "Prufrock", externalRef: nil, in: cafes))
        let image = try TestImage.make(width: 200, height: 100)
        let later = try PhotoProcessor.process(image)
        let earlier = ProcessedPhoto(
            imageData: later.imageData,
            thumbnailData: later.thumbnailData,
            takenAt: Date(timeIntervalSince1970: 1000),
            latitude: 51.52,
            longitude: -0.11,
        )
        let untimed = repository.attach(later, to: entry)
        let first = repository.attach(earlier, to: entry)
        try repository.save()
        let order = repository.photos(of: entry).map(\.id)
        #expect(order == [first.id, untimed.id])
        #expect(first.latitude == 51.52 && first.longitude == -0.11)
        #expect(first.imageData == later.imageData)
    }
}
