import Foundation
import LocalAuthentication
import SwiftUI

/// How long the app may sit in the background before it locks again.
enum AppLockDelay: Int, CaseIterable, Identifiable {
    case immediately = 0
    case oneMinute = 60
    case fiveMinutes = 300
    case fifteenMinutes = 900

    var id: Int {
        rawValue
    }

    var seconds: TimeInterval {
        TimeInterval(rawValue)
    }

    var title: String {
        switch self {
        case .immediately: "Immediately"
        case .oneMinute: "After 1 minute"
        case .fiveMinutes: "After 5 minutes"
        case .fifteenMinutes: "After 15 minutes"
        }
    }
}

/// When the lock falls, kept apart from the views so it's unit-tested.
enum AppLockPolicy {
    /// Whether coming back at `now` finds the app locked, having left at `backgroundedAt`. A clock
    /// that went backwards counts as locked: better to ask than to trust it.
    static func shouldLock(backgroundedAt: Date, now: Date, delay: AppLockDelay) -> Bool {
        let away = now.timeIntervalSince(backgroundedAt)
        return away < 0 || away >= delay.seconds
    }
}

/// Asks the person to prove it's them: Face ID, or the passcode when Face ID is off the table.
@MainActor
protocol Authenticating {
    /// Whether the phone can ask at all (it has a passcode set).
    func canAuthenticate() -> Bool
    /// Shows the system prompt; true once they pass it.
    func authenticate(reason: String) async -> Bool
    /// Whether the lock screen should prompt the moment it appears, instead of waiting for a tap.
    var promptsAutomatically: Bool { get }
}

/// The real thing: LocalAuthentication, so Face ID with the passcode as the fallback. Nothing
/// is stored and nothing leaves the phone.
struct SystemAuthenticator: Authenticating {
    let promptsAutomatically = true

    func canAuthenticate() -> Bool {
        var error: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        return await (try? context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)) ?? false
    }
}

/// A stand-in for UI tests (`-fakeAuthenticator`), which can't show Face ID: it passes, and waits
/// to be asked, so a test can see the lock screen before it unlocks.
struct FakeAuthenticator: Authenticating {
    let promptsAutomatically = false

    func canAuthenticate() -> Bool {
        true
    }

    func authenticate(reason _: String) async -> Bool {
        true
    }
}

/// Whether the app is locked, and when it locks (#76). The lock covers everything: it's up from
/// a cold launch, it falls after the chosen delay in the background, and the app switcher only
/// ever sees the cover. Turning it on asks first, so a phone that can't authenticate can't lock
/// you out.
@MainActor
@Observable
final class AppLockModel {
    static let enabledKey = "appLock.enabled"
    static let delayKey = "appLock.delay"

    enum EnableResult: Equatable {
        case enabled
        /// The phone has no passcode, so there's nothing to unlock with.
        case unavailable
        case cancelled
    }

    private(set) var isEnabled: Bool
    private(set) var delay: AppLockDelay
    private(set) var isLocked: Bool
    private(set) var isAuthenticating = false
    private(set) var isActive = true
    private var backgroundedAt: Date?
    private let authenticator: any Authenticating
    private let defaults: UserDefaults
    private let now: () -> Date

    init(authenticator: any Authenticating, defaults: UserDefaults = .standard, now: @escaping () -> Date = { .now }) {
        self.authenticator = authenticator
        self.defaults = defaults
        self.now = now
        let enabled = defaults.bool(forKey: Self.enabledKey)
        isEnabled = enabled
        isLocked = enabled
        delay = AppLockDelay(rawValue: defaults.integer(forKey: Self.delayKey)) ?? .immediately
    }

    /// The model the app uses: the system's authenticator, or the test one under `-fakeAuthenticator`.
    static func standard(arguments: [String] = ProcessInfo.processInfo.arguments) -> AppLockModel {
        AppLockModel(authenticator: arguments.contains("-fakeAuthenticator") ? FakeAuthenticator() : SystemAuthenticator())
    }

    /// Whether the cover is up: while locked, and whenever the app isn't in front (so the app
    /// switcher's snapshot shows the cover, not your keepsakes).
    var showsCover: Bool {
        isEnabled && (isLocked || !isActive)
    }

    var promptsAutomatically: Bool {
        authenticator.promptsAutomatically
    }

    /// Follows the scene: leaving starts the clock, coming back checks it.
    func scenePhaseChanged(to phase: ScenePhase) {
        isActive = phase == .active
        guard isEnabled else { return }
        switch phase {
        case .background:
            backgroundedAt = backgroundedAt ?? now()
        case .active:
            if let left = backgroundedAt, AppLockPolicy.shouldLock(backgroundedAt: left, now: now(), delay: delay) {
                isLocked = true
            }
            backgroundedAt = nil
        default:
            break
        }
    }

    /// Asks to unlock; the cover goes away when they pass.
    func unlock() async {
        guard isLocked, !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }
        if await authenticator.authenticate(reason: "Unlock Asvada") {
            isLocked = false
        }
    }

    /// Turns the lock on, after they prove they can open it.
    func enable() async -> EnableResult {
        guard authenticator.canAuthenticate() else { return .unavailable }
        guard await authenticator.authenticate(reason: "Turn on the lock for Asvada") else { return .cancelled }
        isEnabled = true
        isLocked = false
        defaults.set(true, forKey: Self.enabledKey)
        return .enabled
    }

    func disable() {
        isEnabled = false
        isLocked = false
        backgroundedAt = nil
        defaults.set(false, forKey: Self.enabledKey)
    }

    func setDelay(_ delay: AppLockDelay) {
        self.delay = delay
        defaults.set(delay.rawValue, forKey: Self.delayKey)
    }
}

/// Clears the lock's stored choices (UI tests start with `-resetState`).
public enum AppLockDefaults {
    public static func reset(_ defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: AppLockModel.enabledKey)
        defaults.removeObject(forKey: AppLockModel.delayKey)
    }
}
