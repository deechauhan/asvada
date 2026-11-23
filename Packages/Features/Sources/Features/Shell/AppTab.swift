/// The app's top-level tabs (Keepsakes shell): Journal, Collections, Atlas.
/// Settings lives behind the ā avatar in the Journal's toolbar.
public enum AppTab: String, CaseIterable, Identifiable, Sendable {
    case journal
    case collections
    case atlas

    /// Storage key for the selected tab (persists across relaunches).
    public static let storageKey = "selectedTab"

    public var id: String {
        rawValue
    }

    public var title: String {
        switch self {
        case .journal: "Journal"
        case .collections: "Collections"
        case .atlas: "Atlas"
        }
    }

    public var symbol: String {
        switch self {
        case .journal: "book.pages"
        case .collections: "square.grid.2x2"
        case .atlas: "map"
        }
    }

    /// Restores a tab from storage. v1 values map onto the new tabs (timeline → journal,
    /// map → atlas, settings → journal); unknown or missing values fall back to the journal.
    public static func restored(from rawValue: String?) -> AppTab {
        switch rawValue {
        case "timeline", "settings": .journal
        case "map": .atlas
        default: rawValue.flatMap(AppTab.init(rawValue:)) ?? .journal
        }
    }
}
