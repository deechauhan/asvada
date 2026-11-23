import Foundation

/// The app's marketing version and build number, read from an Info.plist dictionary.
public struct AppVersion: Equatable, Sendable {
    public let version: String
    public let build: String

    public init(infoDictionary: [String: Any]?) {
        version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        build = infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }

    /// "Version 0.1.0 (12)"
    public var displayString: String {
        "Version \(version) (\(build))"
    }

    public static var current: AppVersion {
        AppVersion(infoDictionary: Bundle.main.infoDictionary)
    }
}
