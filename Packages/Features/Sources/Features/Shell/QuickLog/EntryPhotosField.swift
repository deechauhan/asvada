import DesignSystem
import PhotosUI
import Storage
import SwiftUI
#if canImport(UIKit)
    import UIKit
#else
    import AppKit
#endif

/// Photos for an entry: pick several at once; each is downscaled, given a thumbnail and has its
/// date and place read, off the main actor, then kept in the app (not as a Photos reference).
struct EntryPhotosField: View {
    /// Thumbnails already shown (kept photos, or processed ones waiting to be sealed).
    let thumbnails: [PhotoThumbnail]
    /// Called with each batch of newly processed photos.
    let onAdd: ([ProcessedPhoto]) -> Void
    let onRemove: (PhotoThumbnail) -> Void

    @State private var picked: [PhotosPickerItem] = []
    @State private var isProcessing = false

    /// The most photos picked in one go.
    static let maximumPick = 10

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("Photos")
                .typeToken(.caption)
                .foregroundStyle(Palette.textSecondary.color)
            if !thumbnails.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.small) {
                        ForEach(thumbnails) { thumbnail in
                            thumbnailView(thumbnail)
                        }
                    }
                }
            }
            HStack(spacing: Spacing.small) {
                PhotosPicker(selection: $picked, maxSelectionCount: Self.maximumPick, matching: .images) {
                    // PhotosPicker's label isn't main-actor isolated, so a plain font, not typeToken.
                    Label("Add photos", systemImage: "photo.on.rectangle.angled")
                        .font(.callout)
                }
                .accessibilityIdentifier("addPhotosButton")
                if isProcessing {
                    ProgressView()
                        .accessibilityLabel("Adding photos")
                }
            }
        }
        .onChange(of: picked) { _, items in
            guard !items.isEmpty else { return }
            picked = []
            Task { await process(items) }
        }
    }

    private func thumbnailView(_ thumbnail: PhotoThumbnail) -> some View {
        ZStack(alignment: .topTrailing) {
            thumbnail.image
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: Radius.small))
            Button {
                onRemove(thumbnail)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Palette.onBrand.color, Palette.brand.color)
            }
            .buttonStyle(.plain)
            .padding(2)
            .accessibilityLabel("Remove photo")
        }
        .accessibilityIdentifier("entryPhoto")
    }

    /// Loads and processes the picked photos away from the main actor.
    private func process(_ items: [PhotosPickerItem]) async {
        isProcessing = true
        defer { isProcessing = false }
        var processed: [ProcessedPhoto] = []
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            let work = Task.detached(priority: .userInitiated) { try PhotoProcessor.process(data) }
            if let photo = try? await work.value {
                processed.append(photo)
            }
        }
        if !processed.isEmpty {
            onAdd(processed)
        }
    }
}

/// A photo's thumbnail, for showing: either a kept photo's or a processed one waiting to be sealed.
struct PhotoThumbnail: Identifiable {
    let id: String
    let data: Data

    var image: Image {
        #if canImport(UIKit)
            UIImage(data: data).map(Image.init(uiImage:)) ?? Image(systemName: "photo")
        #else
            NSImage(data: data).map(Image.init(nsImage:)) ?? Image(systemName: "photo")
        #endif
    }
}
