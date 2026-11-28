import DesignSystem
import SwiftUI

/// The poster itself (#71), laid out at A4: the aubergine field, the title in serif, the muted map
/// with a plum pin at each place, a collage of up to six photos, and the ā colophon at the foot.
struct PosterView: View {
    let subject: PosterSubject
    let map: PosterMap?

    var body: some View {
        VStack(spacing: Spacing.large) {
            VStack(spacing: Spacing.xs) {
                Text("Artifacts")
                    .font(.system(size: 11, weight: .semibold, design: .serif))
                    .textCase(.uppercase)
                    .tracking(3)
                    .foregroundStyle(Palette.onAubergine.color.opacity(0.8))
                Text(subject.title)
                    .font(.system(size: 40, weight: .semibold, design: .serif))
                    .foregroundStyle(Palette.onAubergine.color)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .multilineTextAlignment(.center)
                MacronBar(progress: 1, height: 3)
                    .frame(width: 60)
                Text(subject.subtitle)
                    .font(.system(size: 14, design: .serif).italic())
                    .foregroundStyle(Palette.onAubergine.color.opacity(0.85))
            }
            mapView
            if !subject.photos.isEmpty {
                collage
            }
            Spacer(minLength: 0)
            HStack(spacing: Spacing.small) {
                AMark(size: 28)
                Text("savoured with Artifacts")
                    .font(.system(size: 11, design: .serif).italic())
                    .foregroundStyle(Palette.onAubergine.color.opacity(0.8))
            }
        }
        .padding(40)
        .frame(width: PosterRenderer.pageSize.width, height: PosterRenderer.pageSize.height)
        .background(
            LinearGradient(
                colors: [Palette.aubergineTop.color, Palette.aubergineBottom.color],
                startPoint: .top,
                endPoint: .bottom,
            ),
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Poster: \(subject.title), \(subject.subtitle)")
    }

    @ViewBuilder
    private var mapView: some View {
        let size = PosterRenderer.mapSize
        ZStack(alignment: .topLeading) {
            if let map {
                Image(decorative: map.image, scale: CGFloat(map.image.width) / size.width)
                    .resizable()
                    .frame(width: size.width, height: size.height)
                ForEach(Array(map.pins.enumerated()), id: \.offset) { _, pin in
                    Circle()
                        .fill(Palette.brand.color)
                        .overlay(Circle().stroke(Palette.onAubergine.color, lineWidth: 1.5))
                        .frame(width: 10, height: 10)
                        .position(pin)
                }
            } else {
                Rectangle()
                    .fill(Palette.onAubergine.color.opacity(0.08))
                Text("The map couldn't be drawn")
                    .font(.system(size: 12, design: .serif).italic())
                    .foregroundStyle(Palette.onAubergine.color.opacity(0.7))
                    .frame(width: size.width, height: size.height)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: Radius.small))
        .overlay(RoundedRectangle(cornerRadius: Radius.small).stroke(Palette.saffron.color.opacity(0.5), lineWidth: 1))
    }

    private var collage: some View {
        let columns = Array(repeating: GridItem(.fixed(160), spacing: 10), count: 3)
        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(Array(subject.photos.enumerated()), id: \.offset) { index, data in
                PhotoThumbnail(id: "poster-\(index)", data: data).image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 160, height: 110)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.keepsake))
                    .rotationEffect(.degrees(index.isMultiple(of: 2) ? -1.5 : 1.5))
            }
        }
    }
}

/// Makes a poster and offers it to share as an image or a PDF.
struct PosterSheet: View {
    let subject: PosterSubject
    @Environment(\.dismiss) private var dismiss
    @State private var map: PosterMap?
    @State private var files: (png: URL?, pdf: URL?)?

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.large) {
                PosterView(subject: subject, map: map)
                    .scaleEffect(0.5)
                    .frame(width: PosterRenderer.pageSize.width / 2, height: PosterRenderer.pageSize.height / 2)
                    .shadow(color: Palette.textPrimary.color.opacity(0.25), radius: 12, y: 6)
                    .accessibilityIdentifier("posterPreview")
                if let files {
                    HStack(spacing: Spacing.medium) {
                        if let png = files.png {
                            ShareLink(item: png) {
                                Label("Image", systemImage: "photo")
                            }
                            .accessibilityIdentifier("posterSharePNG")
                        }
                        if let pdf = files.pdf {
                            ShareLink(item: pdf) {
                                Label("PDF", systemImage: "doc.richtext")
                            }
                            .accessibilityIdentifier("posterSharePDF")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Palette.brand.color)
                } else {
                    ProgressView("Drawing the map…")
                }
            }
            .padding(Spacing.large)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.background.color)
            .navigationTitle("Poster")
            .navigationBarTitleDisplayModeInline()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                map = await PosterRenderer.snapshot(of: subject.points)
                files = PosterRenderer.files(for: subject, map: map)
            }
        }
    }
}
