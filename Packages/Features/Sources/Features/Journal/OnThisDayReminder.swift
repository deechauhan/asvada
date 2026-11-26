import Foundation
import Model
import SwiftData
import SwiftUI
import UserNotifications

/// The optional morning reminder for "on this day" (#69), off unless turned on in Settings. It's
/// a local notification set for 9 tomorrow morning, only when tomorrow has something to remember,
/// and set again whenever the Journal opens. Nothing leaves the phone.
enum OnThisDayReminder {
    static let identifier = "onThisDay"
    static let enabledKey = "onThisDay.reminders"
    /// The hour of the morning it arrives.
    static let hour = 9

    /// The reminder's words for `anniversaries`, or nil when there's nothing to remember.
    static func text(for anniversaries: [Anniversary]) -> (title: String, body: String)? {
        guard let headline = OnThisDay.headline(anniversaries) else { return nil }
        return ("On this day", headline)
    }

    /// When tomorrow's reminder arrives: 9 in the morning, the day after `now`.
    static func fireDate(after now: Date, calendar: Calendar = .current) -> DateComponents? {
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) else { return nil }
        var when = calendar.dateComponents([.year, .month, .day], from: tomorrow)
        when.hour = hour
        return when
    }

    /// Clears the pending reminder and, when they're on, sets tomorrow's if there's anything to
    /// remember.
    @MainActor
    static func reschedule(entries: [Entry], enabled: Bool, now: Date = .now, calendar: Calendar = .current) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        guard
            enabled,
            let when = fireDate(after: now, calendar: calendar),
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
            let words = text(for: OnThisDay.anniversaries(in: entries, on: tomorrow, calendar: calendar))
        else { return }
        let content = UNMutableNotificationContent()
        content.title = words.title
        content.body = words.body
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: false),
        )
        try? await center.add(request)
    }

    /// Asks to show notifications; false if refused.
    @MainActor
    static func requestPermission() async -> Bool {
        let granted = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        return granted ?? false
    }
}

/// Settings' switch for the "on this day" reminder: asks permission when turned on, and turns
/// itself off again if notifications are refused.
struct OnThisDayReminderToggle: View {
    @AppStorage(OnThisDayReminder.enabledKey) private var enabled = false
    @Query private var entries: [Entry]

    var body: some View {
        Toggle("On this day reminders", isOn: $enabled)
            .accessibilityIdentifier("onThisDayReminders")
            .onChange(of: enabled) { _, isOn in
                Task { @MainActor in
                    if isOn {
                        let allowed = await OnThisDayReminder.requestPermission()
                        if !allowed {
                            enabled = false
                        }
                    }
                    await OnThisDayReminder.reschedule(entries: entries, enabled: enabled)
                }
            }
    }
}
