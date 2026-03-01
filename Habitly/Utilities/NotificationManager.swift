import UserNotifications
import Foundation

@MainActor
final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    private let center = UNUserNotificationCenter.current()

    // MARK: - Permission

    /// Requests authorization if not yet determined. Returns true if granted.
    @discardableResult
    func requestAuthorization() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return true
        case .denied: return false
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        @unknown default: return false
        }
    }

    /// Returns true if notifications are currently authorized.
    func isAuthorized() async -> Bool {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }

    // MARK: - Scheduling

    /// Cancels existing notifications for the habit then schedules new ones if enabled.
    func schedule(for habit: Habit) {
        cancel(for: habit)
        guard habit.notificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "\(habit.emoji) \(habit.name)"
        content.body = "Time to log your habit!"
        content.sound = .default

        let cal = Calendar.current
        let hour   = cal.component(.hour,   from: habit.notificationTime)
        let minute = cal.component(.minute, from: habit.notificationTime)

        switch habit.frequency {
        case .daily:
            var comps = DateComponents()
            comps.hour   = hour
            comps.minute = minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            let id = "habitly-\(habit.id.uuidString)"
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            center.add(request)

        case .weekdays(let days):
            for weekday in days {
                var comps = DateComponents()
                comps.weekday = weekday
                comps.hour    = hour
                comps.minute  = minute
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
                let id = "habitly-\(habit.id.uuidString)-wd\(weekday)"
                let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
                center.add(request)
            }
        }
    }

    // MARK: - Cancellation

    /// Removes all pending notifications for this habit (handles both daily and weekday patterns).
    func cancel(for habit: Habit) {
        let base = "habitly-\(habit.id.uuidString)"
        var ids = [base]
        for wd in 1...7 { ids.append("\(base)-wd\(wd)") }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }
}
