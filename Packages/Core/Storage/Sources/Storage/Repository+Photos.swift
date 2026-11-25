import Model

public extension Repository {
    /// Keeps a processed photo on an entry. Photos are processed off the main actor first
    /// (`PhotoProcessor.process`), then attached here.
    @discardableResult
    func attach(_ processed: ProcessedPhoto, to entry: Entry) -> Photo {
        let photo = Photo(imageData: processed.imageData, thumbnailData: processed.thumbnailData, takenAt: processed.takenAt)
        photo.latitude = processed.latitude
        photo.longitude = processed.longitude
        context.insert(photo)
        photo.entry = entry
        return photo
    }

    /// Takes a photo off its entry and out of the store.
    func remove(_ photo: Photo) {
        photo.entry = nil
        context.delete(photo)
    }

    /// The entry's photos, oldest first by when they were taken (untimed ones last).
    func photos(of entry: Entry) -> [Photo] {
        (entry.photos ?? []).sorted { lhs, rhs in
            switch (lhs.takenAt, rhs.takenAt) {
            case let (left?, right?): left < right
            case (.some, nil): true
            case (nil, _): false
            }
        }
    }
}
