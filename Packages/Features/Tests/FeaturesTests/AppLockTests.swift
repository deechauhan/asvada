import Foundation
import SwiftUI
import Testing
@testable import Features

/// Passes or fails on demand, and counts how often it was asked.
@MainActor
private final class StubAuthenticator: Authenticating {
    var available = true
    var passes = true
    var promptsAutomatically = false
    private(set) var asked = 0

    func canAuthenticate() -> Bool {
        available
    }

    func authenticate(reason _: String) async -> Bool {
        asked += 1
        return passes
    }
}

@MainActor
struct AppLockTests {
    private let start = Date(timeIntervalSinceReferenceDate: 1_000_000)

    /// A model on its own defaults and clock.
    private func model(
        _ authenticator: StubAuthenticator = StubAuthenticator(),
        enabled: Bool = false,
        delay: AppLockDelay = .immediately,
        clock: WindableClock = WindableClock(),
    ) -> AppLockModel {
        let defaults = UserDefaults(suiteName: "AppLockTests-\(UUID().uuidString)") ?? .standard
        defaults.set(enabled, forKey: AppLockDefaults.enabledKey)
        defaults.set(delay.rawValue, forKey: AppLockDefaults.delayKey)
        return AppLockModel(authenticator: authenticator, defaults: defaults, now: { clock.now })
    }

    /// A clock the tests wind forward by hand.
    @MainActor
    final class WindableClock {
        var now = Date(timeIntervalSinceReferenceDate: 1_000_000)
    }

    // MARK: - The policy

    @Test func theLockFallsOnceTheDelayHasPassed() {
        let left = start
        #expect(AppLockPolicy.shouldLock(backgroundedAt: left, now: left, delay: .immediately))
        #expect(!AppLockPolicy.shouldLock(backgroundedAt: left, now: left.addingTimeInterval(59), delay: .oneMinute))
        #expect(AppLockPolicy.shouldLock(backgroundedAt: left, now: left.addingTimeInterval(60), delay: .oneMinute))
        #expect(!AppLockPolicy.shouldLock(backgroundedAt: left, now: left.addingTimeInterval(299), delay: .fiveMinutes))
        #expect(AppLockPolicy.shouldLock(backgroundedAt: left, now: left.addingTimeInterval(901), delay: .fifteenMinutes))
    }

    @Test func aClockThatWentBackwardsLocks() {
        #expect(AppLockPolicy.shouldLock(backgroundedAt: start, now: start.addingTimeInterval(-10), delay: .fifteenMinutes))
    }

    @Test func everyDelayHasATitleAndAStableValue() {
        #expect(AppLockDelay.allCases.map(\.rawValue) == [0, 60, 300, 900])
        #expect(Set(AppLockDelay.allCases.map(\.title)).count == AppLockDelay.allCases.count)
    }

    // MARK: - The model

    @Test func aFreshInstallIsNotLocked() {
        let lock = model()
        #expect(!lock.isEnabled && !lock.isLocked && !lock.showsCover)
    }

    @Test func aColdLaunchWithTheLockOnStartsLocked() {
        let lock = model(enabled: true, delay: .fiveMinutes)
        #expect(lock.isEnabled && lock.isLocked && lock.showsCover)
        #expect(lock.delay == .fiveMinutes)
    }

    @Test func turningItOnAsksFirstAndKeepsTheAppOpen() async {
        let stub = StubAuthenticator()
        let lock = model(stub)
        #expect(await lock.enable() == .enabled)
        #expect(stub.asked == 1)
        #expect(lock.isEnabled && !lock.isLocked)
    }

    @Test func turningItOnFailsWithoutAPasscodeOrWhenTheyCancel() async {
        let stub = StubAuthenticator()
        stub.available = false
        let lock = model(stub)
        #expect(await lock.enable() == .unavailable)
        #expect(stub.asked == 0 && !lock.isEnabled)

        stub.available = true
        stub.passes = false
        #expect(await lock.enable() == .cancelled)
        #expect(!lock.isEnabled)
    }

    @Test func theChoiceIsRemembered() async {
        let defaults = UserDefaults(suiteName: "AppLockTests-\(UUID().uuidString)") ?? .standard
        let first = AppLockModel(authenticator: StubAuthenticator(), defaults: defaults)
        _ = await first.enable()
        first.setDelay(.oneMinute)
        let second = AppLockModel(authenticator: StubAuthenticator(), defaults: defaults)
        #expect(second.isEnabled && second.delay == .oneMinute)
        second.disable()
        #expect(!AppLockModel(authenticator: StubAuthenticator(), defaults: defaults).isEnabled)
    }

    @Test func leavingForLongerThanTheDelayLocks() async {
        let clock = WindableClock()
        let lock = model(enabled: true, delay: .fiveMinutes, clock: clock)
        await lock.unlock()
        lock.scenePhaseChanged(to: .background)
        clock.now = clock.now.addingTimeInterval(299)
        lock.scenePhaseChanged(to: .active)
        #expect(!lock.isLocked)

        lock.scenePhaseChanged(to: .background)
        clock.now = clock.now.addingTimeInterval(301)
        lock.scenePhaseChanged(to: .active)
        #expect(lock.isLocked)
    }

    @Test func theAppSwitcherOnlySeesTheCover() async {
        let lock = model(enabled: true)
        await lock.unlock()
        #expect(!lock.showsCover)
        lock.scenePhaseChanged(to: .inactive)
        #expect(lock.showsCover && !lock.isLocked)
        lock.scenePhaseChanged(to: .active)
        #expect(!lock.showsCover)
    }

    @Test func aBriefInactiveSpellDoesNotStartTheWindableClock() async {
        let clock = WindableClock()
        let lock = model(enabled: true, delay: .immediately, clock: clock)
        await lock.unlock()
        lock.scenePhaseChanged(to: .inactive)
        lock.scenePhaseChanged(to: .active)
        #expect(!lock.isLocked)
    }

    @Test func unlockingNeedsThePromptToPass() async {
        let stub = StubAuthenticator()
        stub.passes = false
        let lock = model(stub, enabled: true)
        await lock.unlock()
        #expect(lock.isLocked && stub.asked == 1)
        stub.passes = true
        await lock.unlock()
        #expect(!lock.isLocked && !lock.showsCover)
        // Nothing to unlock any more, so nothing is asked.
        await lock.unlock()
        #expect(stub.asked == 2)
    }

    @Test func turningTheLockOffClearsIt() {
        let lock = model(enabled: true)
        lock.disable()
        #expect(!lock.isEnabled && !lock.isLocked && !lock.showsCover)
    }
}
