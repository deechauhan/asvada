import DesignSystem
import Model
import SwiftData
import SwiftUI

/// Year in review (#70): the year as the Tasting Menu, one course a page to swipe through, then
/// the whole menu printed on cream with the ā seal at its foot. Share sends every page as an
/// image. Reached from Look back.
struct YearInReviewScreen: View {
    @Query private var collections: [ExperienceCollection]
    @State private var year: Int?
    @State private var page = 0
    @State private var images: [Image] = []
    @State private var isMakingPoster = false

    private var shownYear: Int {
        year ?? TastingMenu.defaultYear(collections: collections)
    }

    var body: some View {
        let menu = TastingMenu(year: shownYear, collections: collections)
        let pages = MenuPage.pages(of: menu)
        TabView(selection: $page) {
            ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                MenuPageView(page: page, menu: menu)
                    .frame(width: ShareCard.size.width, height: ShareCard.size.height)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.medium))
                    .shadow(color: Palette.textPrimary.color.opacity(0.18), radius: 14, y: 8)
                    .tag(index)
            }
        }
        .pagedTabStyle()
        .background(Palette.background.color)
        .navigationTitle("The Tasting Menu")
        .navigationBarTitleDisplayModeInline()
        .accessibilityIdentifier("tastingMenu")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Poster", systemImage: "photo.artframe") { isMakingPoster = true }
                    .accessibilityIdentifier("yearPosterButton")
                let years = TastingMenu.years(collections: collections)
                if years.count > 1 {
                    Menu {
                        Picker("Year", selection: Binding(get: { shownYear }, set: { year = $0; page = 0 })) {
                            ForEach(years, id: \.self) { Text(String($0)).tag($0) }
                        }
                    } label: {
                        Label(String(shownYear), systemImage: "calendar")
                    }
                    .accessibilityIdentifier("tastingMenuYear")
                }
                if let first = images.first {
                    ShareLink(
                        items: images,
                        preview: { _ in SharePreview("The Tasting Menu \(shownYear)", image: first) },
                        label: { Label("Share", systemImage: "square.and.arrow.up") },
                    )
                    .accessibilityIdentifier("tastingMenuShare")
                }
            }
        }
        .sheet(isPresented: $isMakingPoster) {
            PosterSheet(subject: PosterSubject(year: shownYear, collections: collections))
        }
        .task(id: shownYear) {
            images = pages.compactMap { ShareCard.render(MenuPageView(page: $0, menu: menu)) }
        }
    }
}

/// One page of the year's story: the cover, a course, or the whole printed menu.
enum MenuPage: Equatable {
    case cover
    case course(Course)
    case menu

    /// The cover, each course, then the menu; an empty year is just the cover.
    static func pages(of menu: TastingMenu) -> [MenuPage] {
        guard !menu.isEmpty else { return [.cover] }
        return [.cover] + menu.courses.map(MenuPage.course) + [.menu]
    }
}

/// A page laid out at share-card size, on cream like a printed menu.
private struct MenuPageView: View {
    let page: MenuPage
    let menu: TastingMenu

    var body: some View {
        VStack(spacing: Spacing.large) {
            switch page {
            case .cover: cover
            case let .course(course): courseView(course)
            case .menu: printedMenu
            }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.keepsakePaper.color)
        .overlay(
            RoundedRectangle(cornerRadius: Radius.small)
                .inset(by: 10)
                .stroke(Palette.brand.color.opacity(0.25), lineWidth: 1),
        )
        .accessibilityElement(children: .combine)
    }

    private var cover: some View {
        VStack(spacing: Spacing.medium) {
            Spacer(minLength: 0)
            Text("The Tasting Menu")
                .font(.system(.largeTitle, design: .serif, weight: .semibold))
                .foregroundStyle(Palette.textPrimary.color)
                .multilineTextAlignment(.center)
            Text(String(menu.year))
                .font(.system(.title, design: .serif))
                .foregroundStyle(Palette.brand.color)
            MacronBar(progress: 1, height: 3)
                .frame(width: 56)
            Text(YearText.cover(menu))
                .font(.system(.callout, design: .serif).italic())
                .foregroundStyle(Palette.textSecondary.color)
                .multilineTextAlignment(.center)
            Spacer(minLength: 0)
            Seal()
        }
    }

    private func courseView(_ course: Course) -> some View {
        VStack(spacing: Spacing.medium) {
            Spacer(minLength: 0)
            Text(course.title)
                .font(.system(.footnote, design: .serif, weight: .semibold))
                .textCase(.uppercase)
                .tracking(2)
                .foregroundStyle(Palette.brand.color)
            Text(course.dish)
                .font(.system(.title, design: .serif, weight: .semibold))
                .foregroundStyle(Palette.textPrimary.color)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
            Text(course.note)
                .font(.system(.callout, design: .serif).italic())
                .foregroundStyle(Palette.textSecondary.color)
                .multilineTextAlignment(.center)
            Spacer(minLength: 0)
            Seal()
        }
    }

    private var printedMenu: some View {
        VStack(spacing: Spacing.medium) {
            Text("— \(String(menu.year)) —")
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(Palette.textPrimary.color)
            ForEach(menu.courses) { course in
                VStack(spacing: 2) {
                    Text(course.title)
                        .font(.system(.caption, design: .serif, weight: .semibold))
                        .textCase(.uppercase)
                        .tracking(1.5)
                        .foregroundStyle(Palette.brand.color)
                    Text(course.dish)
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(Palette.textPrimary.color)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    Text(course.note)
                        .font(.system(.caption2, design: .serif).italic())
                        .foregroundStyle(Palette.textSecondary.color)
                }
                .multilineTextAlignment(.center)
            }
            Spacer(minLength: 0)
            Seal()
        }
    }
}

/// The ā seal at the foot of every page.
private struct Seal: View {
    var body: some View {
        Text("ā")
            .font(.system(size: 22, weight: .heavy, design: .serif))
            .foregroundStyle(Palette.onBrand.color)
            .frame(width: 38, height: 38)
            .background(Palette.brand.color, in: Circle())
            .accessibilityHidden(true)
    }
}

/// The words the year in review uses.
enum YearText {
    /// "42 things savoured, in five courses." / "Nothing savoured yet this year."
    static func cover(_ menu: TastingMenu) -> String {
        guard menu.total > 0 else { return "Nothing savoured in \(menu.year) yet." }
        let things = menu.total == 1 ? "1 thing savoured" : "\(menu.total) things savoured"
        let courses = menu.courses.count == 1 ? "one course" : "\(menu.courses.count) courses"
        return menu.courses.isEmpty ? "\(things)." : "\(things), in \(courses)."
    }
}
