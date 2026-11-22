/// The app's top-level tabs.
public enum AppTab: String, CaseIterable, Identifiable, Sendable {
    case timeline
    case collections
    case map
    case settings

    /// Storage key for the selected tab (persists across relaunches).
    public static let storageKey = "selectedTab"

    public var id: String {
        rawValue
    }

    public var title: String {
        switch self {
        case .timeline: "Timeline"
        case .collections: "Collections"
        case .map: "Map"
        case .settings: "Settings"
        }
    }

    public var symbol: String {
        switch self {
        case .timeline: "clock.arrow.circlepath"
        case .collections: "square.grid.2x2"
        case .map: "map"
        case .settings: "gearshape"
        }
    }

    /// Restores a tab from storage, falling back to the timeline for unknown or missing values.
    public static func restored(from rawValue: String?) -> AppTab {
        rawValue.flatMap(AppTab.init(rawValue:)) ?? .timeline
    }
}
