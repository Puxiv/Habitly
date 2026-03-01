import SwiftData
import SwiftUI
import UserNotifications
import Observation

@MainActor
@Observable
final class RemindersViewModel {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - CRUD

    func addReminder(title: String, emoji: String, note: String,
                     dateTime: Date, repeatOption: ReminderRepeat) {
        let reminder = Reminder(title: title, emoji: emoji, note: note,
                                dateTime: dateTime, repeatOption: repeatOption)
        modelContext.insert(reminder)
        try? modelContext.save()
        scheduleNotification(for: reminder)
    }

    func saveReminder(_ reminder: Reminder, title: String, emoji: String,
                      note: String, dateTime: Date, repeatOption: ReminderRepeat) {
        reminder.title = title
        reminder.emoji = emoji
        reminder.note = note
        reminder.dateTime = dateTime
        reminder.repeatOption = repeatOption
        try? modelContext.save()
        scheduleNotification(for: reminder)
    }

    func markComplete(_ reminder: Reminder) {
        reminder.isCompleted = true
        try? modelContext.save()
        cancelNotification(for: reminder)

        // If repeating, create the next occurrence
        if reminder.repeatOption != .once,
           let nextDate = reminder.repeatOption.nextOccurrence(after: reminder.dateTime) {
            let next = Reminder(title: reminder.title, emoji: reminder.emoji,
                                note: reminder.note, dateTime: nextDate,
                                repeatOption: reminder.repeatOption)
            modelContext.insert(next)
            try? modelContext.save()
            scheduleNotification(for: next)
        }
    }

    func deleteReminder(_ reminder: Reminder) {
        cancelNotification(for: reminder)
        modelContext.delete(reminder)
        try? modelContext.save()
    }

    // MARK: - Notifications

    private func scheduleNotification(for reminder: Reminder) {
        cancelNotification(for: reminder)
        guard !reminder.isCompleted, reminder.dateTime > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "\(reminder.emoji) \(reminder.title)"
        content.body = reminder.note.isEmpty ? "Time for your reminder!" : reminder.note
        content.sound = .default

        let comps = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminder.dateTime
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let id = "habitly-reminder-\(reminder.id.uuidString)"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    private func cancelNotification(for reminder: Reminder) {
        let id = "habitly-reminder-\(reminder.id.uuidString)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    // MARK: - Dashboard Helpers

    func upcomingCount(from reminders: [Reminder]) -> Int {
        reminders.filter { $0.state == .upcoming }.count
    }

    func overdueCount(from reminders: [Reminder]) -> Int {
        reminders.filter { $0.state == .overdue }.count
    }

    func nextUpcoming(from reminders: [Reminder]) -> Reminder? {
        reminders
            .filter { $0.state == .upcoming }
            .sorted { $0.dateTime < $1.dateTime }
            .first
    }
}
