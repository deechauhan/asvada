import Foundation
import Geo
import Photos
import Storage

/// How far the app may read the photo library.
enum PhotoAccess: Equatable {
    case notDetermined
    /// Refused, or blocked by Screen Time or a profile.
    case denied
    /// Only the photos the owner picked.
    case limited
    case full

    var canRead: Bool {
        self == .limited || self == .full
    }
}

/// One page of the library's photos that have a place, and where the next page starts.
struct PhotoPage: Equatable {
    var sightings: [PhotoSighting]
    /// Where to ask for the page after this one: a position in the library, oldest first.
    var next: Int
    /// How many photos the library holds, with or without a place.
    var total: Int
}

/// Where the scan reads photos from: the real library, or a stand-in in tests (#64).
@MainActor
protocol PhotoLibrarySource {
    func access() -> PhotoAccess
    func requestAccess() async -> PhotoAccess
    /// Up to `limit` photos from position `index` (oldest first). Only photos with a place and a
    /// date are returned, but `next` counts every photo looked at.
    func page(from index: Int, limit: Int) async -> PhotoPage
}

/// The device's photo library, read through PhotoKit. Only where and when each photo was taken is
/// read: no pictures are loaded, and nothing leaves the phone.
@MainActor
struct SystemPhotoLibrary: PhotoLibrarySource {
    func access() -> PhotoAccess {
        Self.access(for: PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    func requestAccess() async -> PhotoAccess {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return Self.access(for: status)
    }

    func page(from index: Int, limit: Int) async -> PhotoPage {
        await Task.detached(priority: .utility) {
            readPhotoPage(from: index, limit: limit)
        }.value
    }

    private static func access(for status: PHAuthorizationStatus) -> PhotoAccess {
        switch status {
        case .notDetermined: .notDetermined
        case .authorized: .full
        case .limited: .limited
        case .denied, .restricted: .denied
        @unknown default: .denied
        }
    }
}

/// Reads one page of the library. Not tied to the main actor: it can take a moment on a big library.
private func readPhotoPage(from index: Int, limit: Int) -> PhotoPage {
    let options = PHFetchOptions()
    options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
    let assets = PHAsset.fetchAssets(with: .image, options: options)
    let end = min(index + limit, assets.count)
    var sightings: [PhotoSighting] = []
    if index < end {
        for position in index ..< end {
            let asset = assets.object(at: position)
            guard let date = asset.creationDate, let location = asset.location else { continue }
            sightings.append(PhotoSighting(
                id: asset.localIdentifier,
                date: date,
                point: GeoPoint(longitude: location.coordinate.longitude, latitude: location.coordinate.latitude),
            ))
        }
    }
    return PhotoPage(sightings: sightings, next: max(end, index), total: assets.count)
}
