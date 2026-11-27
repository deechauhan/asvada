import CoreLocation
import Foundation
import Geo
import ImageIO
import MapKit
import SwiftUI
import UniformTypeIdentifiers
#if canImport(UIKit)
    import UIKit
#else
    import AppKit
#endif

/// The poster's map, drawn by MapKit: the image and where each place lands on it.
struct PosterMap: @unchecked Sendable {
    let image: CGImage
    /// Each place's position on the map, in points of `PosterRenderer.mapSize`.
    let pins: [CGPoint]
}

/// Draws a poster (#71): a muted MapKit snapshot of the places, then the whole page rendered at
/// print resolution (A4 at 300 dpi) as a PNG and a PDF.
enum PosterRenderer {
    /// The page, A4 portrait, in points.
    static let pageSize = CGSize(width: 595, height: 842)
    /// 300 dpi.
    static let printScale: CGFloat = 300.0 / 72.0
    /// The map's place on the page.
    static let mapSize = CGSize(width: 515, height: 400)

    /// A muted map around `points`, or nil if MapKit couldn't draw one (offline, say).
    @MainActor
    static func snapshot(of points: [GeoPoint]) async -> PosterMap? {
        let region = PosterRegion.fitting(points)
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: region.centre.latitude, longitude: region.centre.longitude),
            span: MKCoordinateSpan(latitudeDelta: region.latitudeSpan, longitudeDelta: region.longitudeSpan),
        )
        options.size = mapSize
        options.mapType = .mutedStandard
        options.pointOfInterestFilter = .excludingAll
        let snapshotter = MKMapSnapshotter(options: options)
        let map: PosterMap? = await withCheckedContinuation { continuation in
            snapshotter.start(with: .main) { snapshot, _ in
                guard let snapshot, let image = cgImage(of: snapshot.image) else {
                    continuation.resume(returning: nil)
                    return
                }
                let pins = points.map {
                    snapshot.point(for: CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude))
                }
                continuation.resume(returning: PosterMap(image: image, pins: pins))
            }
        }
        // MapKit needs the snapshotter until it has called back.
        withExtendedLifetime(snapshotter) {}
        return map
    }

    /// Writes the poster as a PNG and a PDF in a temporary folder; nil for any that failed.
    @MainActor
    static func files(for subject: PosterSubject, map: PosterMap?) -> (png: URL?, pdf: URL?) {
        let folder = FileManager.default.temporaryDirectory.appending(path: "posters-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let name = PosterText.fileName(for: subject.title)
        let renderer = ImageRenderer(content: PosterView(subject: subject, map: map))
        renderer.scale = printScale

        var png: URL?
        if let image = renderer.cgImage {
            let url = folder.appending(path: "\(name).png")
            if let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) {
                CGImageDestinationAddImage(destination, image, nil)
                if CGImageDestinationFinalize(destination) {
                    png = url
                }
            }
        }

        let pdfURL = folder.appending(path: "\(name).pdf")
        var wrote = false
        renderer.render { size, draw in
            var box = CGRect(origin: .zero, size: size)
            guard let context = CGContext(pdfURL as CFURL, mediaBox: &box, nil) else { return }
            context.beginPDFPage(nil)
            draw(context)
            context.endPDFPage()
            context.closePDF()
            wrote = true
        }
        return (png, wrote ? pdfURL : nil)
    }

    #if canImport(UIKit)
        private static func cgImage(of image: UIImage) -> CGImage? {
            image.cgImage
        }

    #else
        private static func cgImage(of image: NSImage) -> CGImage? {
            image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        }
    #endif
}
