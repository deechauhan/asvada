import Foundation
import Geo
import Photos
import Storage
#if os(iOS)
    import UIKit
#endif

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
    /// Small pictures of the photos with these ids, as JPEG data, for showing a suggestion. Photos
    /// that can't be loaded quickly (in iCloud, say) are left out.
    func thumbnails(for ids: [String]) async -> [Data]
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

    func thumbnails(for ids: [String]) async -> [Data] {
        await Task.detached(priority: .utility) {
            loadThumbnails(ids)
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

/// A holder for what the photo library hands back, so it can be gathered inside its callback.
private final class ThumbnailBox: @unchecked Sendable {
    var pictures: [Data] = []
}

/// Loads small pictures of the photos with these ids, on this thread. Only on iOS, where the
/// system hands back a `UIImage`; the Mac builds (package tests only) show none.
private func loadThumbnails(_ ids: [String]) -> [Data] {
    #if os(iOS)
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        let options = PHImageRequestOptions()
        options.isSynchronous = true
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = false
        let box = ThumbnailBox()
        assets.enumerateObjects { asset, _, _ in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 200, height: 200),
                contentMode: .aspectFill,
                options: options,
            ) { image, _ in
                if let data = image?.jpegData(compressionQuality: 0.7) {
                    box.pictures.append(data)
                }
            }
        }
        return box.pictures
    #else
        return []
    #endif
}
